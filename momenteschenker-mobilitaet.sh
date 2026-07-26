#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="Momenteschenker Mobilität"
HOSTNAME="mobilitaet"
APP_REPO="chevy-type/momenteschenker-mobilitaet"
APP_REF="main"
APP_PORT="8000"
MEMORY="2048"
SWAP="512"
CORES="2"
DISK="10"
BRIDGE="vmbr0"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
green(){ printf '\033[32m%s\033[0m\n' "$*"; }
info(){ printf '\033[36m==> %s\033[0m\n' "$*"; }
die(){ red "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Bitte als root auf dem Proxmox-Host ausführen."
command -v pct >/dev/null || die "Dieses Skript muss auf einem Proxmox-VE-Host laufen."

printf '\n%s\n' "$APP_NAME – LXC Installer"
printf '%s\n\n' "Debian 13 · Docker · PostgreSQL · DHCP"
read -r -p "Installation starten? [J/n] " answer
[[ ${answer:-J} =~ ^[JjYy]$ ]] || exit 0

read -r -s -p "GitHub Fine-grained Token (Contents: read für ${APP_REPO}): " GH_TOKEN
printf '\n'
[[ -n "$GH_TOKEN" ]] || die "Ein Token wird benötigt, solange das App-Repository privat ist."

CTID="$(pvesh get /cluster/nextid)"
STORAGE="$(pvesm status -content rootdir | awk 'NR==2{print $1}')"
[[ -n "$STORAGE" ]] || die "Kein Storage mit rootdir-Unterstützung gefunden."

info "Suche Debian-13-Template"
pveam update >/dev/null
TEMPLATE="$(pveam available --section system | awk '/debian-13-standard/{print $2; exit}')"
[[ -n "$TEMPLATE" ]] || die "Kein Debian-13-Template gefunden."
TEMPLATE_STORAGE="local"
if ! pvesm status | awk 'NR>1{print $1}' | grep -qx "$TEMPLATE_STORAGE"; then
  TEMPLATE_STORAGE="$(pvesm status -content vztmpl | awk 'NR==2{print $1}')"
fi
[[ -n "$TEMPLATE_STORAGE" ]] || die "Kein Template-Storage gefunden."
TEMPLATE_FILE="/var/lib/vz/template/cache/${TEMPLATE##*/}"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  info "Lade ${TEMPLATE##*/}"
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

info "Erstelle LXC ${CTID} mit DHCP"
pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE##*/}" \
  --hostname "$HOSTNAME" \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap "$SWAP" \
  --rootfs "${STORAGE}:${DISK}" \
  --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp,type=veth" \
  --onboot 1 \
  --start 1

info "Warte auf Netzwerk"
IP=""
for _ in {1..60}; do
  IP="$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}' || true)"
  [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
  sleep 2
done
[[ -n "$IP" ]] || die "Der Container hat keine IPv4-Adresse per DHCP erhalten."

info "Installiere Docker und Anwendung"
printf '%s' "$GH_TOKEN" | pct push "$CTID" /dev/stdin /run/mobilitaet-github-token --perms 0600
unset GH_TOKEN

pct exec "$CTID" -- bash -s -- "$APP_REPO" "$APP_REF" <<'IN_CONTAINER'
set -Eeuo pipefail
APP_REPO="$1"
APP_REF="$2"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git openssl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

install -d -m 0750 /opt/momenteschenker-mobilitaet
TOKEN="$(cat /run/mobilitaet-github-token)"
curl -fsSL \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${APP_REPO}/tarball/${APP_REF}" \
  | tar -xz --strip-components=1 -C /opt/momenteschenker-mobilitaet
rm -f /run/mobilitaet-github-token
unset TOKEN

cd /opt/momenteschenker-mobilitaet
cp .env.example .env
SECRET="$(openssl rand -hex 32)"
DBPASS="$(openssl rand -hex 24)"
sed -i "s/^DJANGO_SECRET_KEY=.*/DJANGO_SECRET_KEY=${SECRET}/" .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${DBPASS}/" .env
sed -i "s#^DATABASE_URL=.*#DATABASE_URL=postgresql://mobilitaet:${DBPASS}@db:5432/mobilitaet#" .env
chmod 0600 .env
docker compose up -d --build

cat >/usr/local/sbin/momenteschenker-mobilitaet-status <<'EOF'
#!/usr/bin/env bash
cd /opt/momenteschenker-mobilitaet && docker compose ps
EOF
cat >/usr/local/sbin/momenteschenker-mobilitaet-logs <<'EOF'
#!/usr/bin/env bash
cd /opt/momenteschenker-mobilitaet && docker compose logs -f --tail=200
EOF
cat >/usr/local/sbin/momenteschenker-mobilitaet-backup <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/momenteschenker-mobilitaet
mkdir -p backups
stamp=$(date +%Y%m%d-%H%M%S)
docker compose exec -T db pg_dump -U mobilitaet -Fc mobilitaet > "backups/mobilitaet-${stamp}.dump"
tar -czf "backups/config-${stamp}.tar.gz" .env compose.yaml
printf 'Backup erstellt: %s\n' "$stamp"
EOF
chmod +x /usr/local/sbin/momenteschenker-mobilitaet-*
IN_CONTAINER

info "Prüfe Anwendung"
for _ in {1..30}; do
  if curl -fsS "http://${IP}:${APP_PORT}/health/" >/dev/null 2>&1; then
    green "$APP_NAME wurde installiert."
    printf '\nContainer: %s\nIP: %s\nInterner Aufruf: http://%s:%s\n\n' "$CTID" "$IP" "$IP" "$APP_PORT"
    printf 'Nächster Schritt: Traefik für mobil.momenteschenker.de auf %s:%s konfigurieren.\n' "$IP" "$APP_PORT"
    exit 0
  fi
  sleep 3
done

die "Die Installation lief durch, aber der Healthcheck ist noch nicht erreichbar. Prüfe: pct exec ${CTID} -- momenteschenker-mobilitaet-logs"
