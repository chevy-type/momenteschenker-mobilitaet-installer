# Momenteschenker Mobilität Installer

Öffentlicher Proxmox-LXC-Installer für **Momenteschenker Mobilität**.

Der Installer erstellt einen unprivilegierten Debian-13-LXC mit automatisch vergebener DHCP-Adresse, installiert Docker und PostgreSQL und lädt die Anwendung aus dem privaten Repository.

## Installation

Auf dem Proxmox-Host als `root` ausführen:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chevy-type/momenteschenker-mobilitaet-installer/main/momenteschenker-mobilitaet.sh)"
```

Während der Installation wird ein Fine-grained GitHub-Token verdeckt abgefragt. Nach erfolgreicher Installation zeigt das Skript die Container-ID, die automatisch vergebene IP-Adresse und ein zufällig erzeugtes temporäres Admin-Passwort an.

## Standardwerte

- Container-ID: automatisch
- Hostname: `mobilitaet`
- System: Debian 13
- Netzwerk: DHCP über `vmbr0`
- CPU: 2 Kerne
- RAM: 2 GB
- Swap: 512 MB
- Speicher: 10 GB
- Anwendung: Port 8000
- lokaler Erstzugang: Benutzer `admin`

Das Admin-Passwort wird zusätzlich im LXC gespeichert:

```text
/root/momenteschenker-mobilitaet-admin-password
```

Nach dem ersten Login sollte das Passwort geändert werden.

## GitHub-Token

Benötigt wird ein **Fine-grained Personal Access Token** mit folgenden Einstellungen:

- Repository access: `Only select repositories`
- Repository: `chevy-type/momenteschenker-mobilitaet`
- Permission: `Contents: Read-only`

Der Token wird vor der LXC-Erstellung geprüft, verdeckt eingelesen, nur für den Download verwendet und nicht dauerhaft gespeichert.

## Befehle im LXC

```bash
momenteschenker-mobilitaet-status
momenteschenker-mobilitaet-logs
momenteschenker-mobilitaet-backup
update-momenteschenker-mobilitaet
restore-momenteschenker-mobilitaet
```

## Bestehende Installation aktualisieren

Bei Installationen ohne `.git`-Verzeichnis wird nicht mit `git pull`, sondern mit dem Update-Skript aktualisiert. Das Skript sichert vor jedem Update die PostgreSQL-Datenbank und die `.env`, lädt anschließend den aktuellen Stand aus dem privaten GitHub-Repository, führt Migrationen und `collectstatic` aus und erstellt die Container neu.

Einmalig den aktuellen Updater laden:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/chevy-type/momenteschenker-mobilitaet-installer/main/scripts/update-momenteschenker-mobilitaet \
  -o /usr/local/sbin/update-momenteschenker-mobilitaet
chmod 0755 /usr/local/sbin/update-momenteschenker-mobilitaet
```

Danach aktualisieren:

```bash
update-momenteschenker-mobilitaet
```

Dabei wird der Fine-grained GitHub-Token erneut verdeckt abgefragt und nicht gespeichert.

## Nach der Installation

1. Die angezeigte IP in der Fritzbox dauerhaft diesem Gerät zuweisen.
2. Traefik für `mobil.momenteschenker.de` auf `http://<LXC-IP>:8000` konfigurieren.
3. `https://mobil.momenteschenker.de/admin/` öffnen und mit `admin` anmelden.
4. Das lokale Admin-Passwort ändern und das erste Fahrzeug anlegen.
5. Anschließend Authentik-OIDC in `/opt/momenteschenker-mobilitaet/.env` aktivieren.

## Authentik

Die Anwendung erwartet bei aktivierter OIDC-Konfiguration:

```env
OIDC_ENABLED=true
OIDC_CLIENT_ID=<client-id>
OIDC_CLIENT_SECRET=<client-secret>
OIDC_ISSUER=https://anmeldung.momenteschenker.de/application/o/mobilitaet/
```

Danach im LXC neu starten:

```bash
cd /opt/momenteschenker-mobilitaet
docker compose up -d
```

## Hinweis

Dies ist die erste installierbare Alpha-Version. Ein Proxmox-Backup des LXC sollte vor Updates weiterhin aktiviert sein.
