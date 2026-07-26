# Momenteschenker Mobilität Installer

Öffentlicher Proxmox-LXC-Installer für **Momenteschenker Mobilität**.

Die Anwendung selbst liegt im privaten Repository `chevy-type/momenteschenker-mobilitaet`. Der Installer erstellt einen unprivilegierten Debian-13-LXC, bezieht die IP automatisch per DHCP, installiert Docker und lädt den App-Code mit einem nur lesenden GitHub-Token.

## Geplante Standardwerte

- Debian 13
- unprivilegierter LXC
- 2 CPU-Kerne
- 2 GB RAM
- 10 GB Speicher
- `vmbr0` und DHCP
- Anwendung auf Port 8000
- Hostname `mobilitaet`

## Testinstallation

> **Alpha:** Noch nicht auf einem produktiven Proxmox-Host ausführen. Der Installer muss zunächst kontrolliert getestet werden.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chevy-type/momenteschenker-mobilitaet-installer/main/momenteschenker-mobilitaet.sh)"
```

Solange der Pull Request noch nicht nach `main` übernommen wurde, muss zum Testen die entsprechende Branch-URL verwendet werden.

## GitHub-Token

Benötigt wird ein Fine-grained Personal Access Token mit ausschließlich:

- Repository: `chevy-type/momenteschenker-mobilitaet`
- Berechtigung: **Contents – Read-only**

Das Token wird verdeckt abgefragt, nur für den Download verwendet und danach gelöscht.

## Nach der Installation

Im LXC stehen zunächst folgende Befehle bereit:

```bash
momenteschenker-mobilitaet-status
momenteschenker-mobilitaet-logs
momenteschenker-mobilitaet-backup
```

Die über DHCP vergebene IP sollte anschließend in der Fritzbox dauerhaft diesem Container zugeordnet werden. Traefik leitet `mobil.momenteschenker.de` auf diese IP und Port 8000 weiter.
