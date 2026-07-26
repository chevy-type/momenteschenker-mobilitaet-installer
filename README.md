# Momenteschenker Mobilität Installer

Öffentlicher Proxmox-LXC-Installer für **Momenteschenker Mobilität**.

Die Anwendung selbst liegt in einem privaten Repository. Der Installer erstellt einen unprivilegierten Debian-13-LXC mit DHCP, installiert Docker und lädt den Anwendungscode mit einem temporär eingegebenen, read-only GitHub-Token.

## Geplante Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chevy-type/momenteschenker-mobilitaet-installer/main/momenteschenker-mobilitaet.sh)"
```

## Standardwerte

- Container-ID: automatisch
- Hostname: `mobilitaet`
- Netzwerk: DHCP über `vmbr0`
- CPU: 2 Kerne
- RAM: 2 GB
- Swap: 512 MB
- Speicher: 10 GB
- Anwendung: Port 8000

## Befehle im LXC

```bash
momenteschenker-mobilitaet-status
momenteschenker-mobilitaet-logs
momenteschenker-mobilitaet-backup
update-momenteschenker-mobilitaet
restore-momenteschenker-mobilitaet
```

## GitHub-Token

Benötigt wird ein Fine-grained Personal Access Token für ausschließlich das private Repository `chevy-type/momenteschenker-mobilitaet` mit `Contents: read-only`. Das Token wird verdeckt abgefragt, nur für den Download verwendet und nicht dauerhaft gespeichert.

> Status: Alpha. Vor der Nutzung auf einem produktiven Proxmox-Host muss der Installer kontrolliert getestet werden.
