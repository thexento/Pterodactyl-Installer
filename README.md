# Pterodactyl Installer — by XENTO

<div align="center">

```
  ██╗  ██╗███████╗███╗   ██╗████████╗ ██████╗
  ╚██╗██╔╝██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗
   ╚███╔╝ █████╗  ██╔██╗ ██║   ██║   ██║   ██║
   ██╔██╗ ██╔══╝  ██║╚██╗██║   ██║   ██║   ██║
  ██╔╝ ██╗███████╗██║ ╚████║   ██║   ╚██████╔╝
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝
```

**A fully automated, single-command Pterodactyl Panel & Wings installer.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/badge/version-v1.0.0-cyan.svg)](https://github.com/thexento/Pterodactyl-Installer/releases)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian-orange.svg)](#supported-operating-systems)

**[pterodactyl-installer.xento.xyz](https://pterodactyl-installer.xento.xyz)**

</div>

---

## ⚡ Quick Install

Run as **root** on your VPS:

```bash
bash <(curl -fsSL https://pterodactyl-installer.xento.xyz/install.sh)
```

---

## ✨ Features

- **One command** — paste, answer questions, walk away
- **All inputs upfront** — every question asked before installation starts, no mid-install surprises
- **Single admin user** — your credentials become the first and only admin account
- **Panel, Wings, or both** — install separately or together on the same machine
- **phpMyAdmin** — optional database GUI installer included
- **Auto SSL** — Let's Encrypt via Certbot, optional
- **PHP 8.3** with all required extensions
- **MariaDB + Redis + NGINX** — fully configured automatically
- **Systemd services** — Wings and Queue Worker enabled on boot
- **Architecture aware** — supports both `amd64` and `arm64`
- **Full log** — every action logged to `/var/log/pterodactyl-xento.log`

---

## 🖥️ Supported Operating Systems

| OS | Versions |
|---|---|
| Ubuntu | 20.04, 22.04, 24.04 |
| Debian | 11, 12 |
| Rocky Linux | 8, 9 |
| AlmaLinux | 8, 9 |

---

## 📋 Menu Options

| Option | Description |
|---|---|
| `1` | Install Panel |
| `2` | Install Wings |
| `3` | Install Panel + Wings (same machine) |
| `4` | Install phpMyAdmin |
| `5` | Uninstall Panel / Wings |

---

## 📦 What Gets Installed

### Panel
| Component | Details |
|---|---|
| Pterodactyl Panel | Latest stable release |
| PHP | 8.3 with all required extensions |
| Composer | Latest |
| MariaDB | Latest stable |
| Redis | Latest stable |
| NGINX | Latest stable |
| Certbot | If SSL is selected |

### Wings
| Component | Details |
|---|---|
| Pterodactyl Wings | Latest stable (amd64 / arm64) |
| Docker | Latest stable (via official repo) |
| MariaDB | Optional (for database host feature) |

---

## 🗂️ Repository Structure

```
Pterodactyl-Installer/
├── install.sh          ← Main entrypoint (run this)
├── scripts/
│   ├── panel.sh        ← Panel installer
│   ├── wings.sh        ← Wings installer
│   ├── uninstall.sh    ← Uninstaller
│   └── phpmyadmin.sh   ← phpMyAdmin installer
├── index.html          ← Website (pterodactyl-installer.xento.xyz)
└── README.md
```

---

## 🔧 Post-Install: Panel + Wings on Same Machine

After installing both on the same machine, connect Wings to the Panel:

1. Log in to your Panel
2. Go to **Admin → Nodes → Create Node** and fill in the details
3. Open the **Configuration** tab on the new node
4. Copy the YAML and paste it into your server:
   ```bash
   nano /etc/pterodactyl/config.yml
   ```
5. Start Wings:
   ```bash
   systemctl start wings
   ```

---

## 📁 Important Paths

| Path | Description |
|---|---|
| `/var/www/pterodactyl` | Panel files |
| `/etc/pterodactyl/config.yml` | Wings configuration |
| `/var/lib/pterodactyl/volumes` | Server data volumes (Wings) |
| `/etc/nginx/sites-available/pterodactyl.conf` | NGINX config (Ubuntu/Debian) |
| `/var/log/pterodactyl-xento.log` | Installer log file |

---

## 🛠️ Services

```bash
systemctl status wings       # Wings daemon
systemctl status pteroq      # Panel queue worker
systemctl status nginx       # Web server
systemctl status mariadb     # Database
systemctl status redis-server # Cache (Ubuntu/Debian)
```

---

## ⚠️ Requirements

- Fresh VPS running a supported OS
- Root access
- Ports open: **80**, **443**, **8080** (Wings API), **2022** (SFTP)
- A domain pointed at your server (if using SSL)

---

## 🐛 Troubleshooting

```bash
# View full installer log
cat /var/log/pterodactyl-xento.log

# Test NGINX config
nginx -t

# Panel Laravel log
tail -n 50 /var/www/pterodactyl/storage/logs/laravel.log

# Wings log
journalctl -u wings -n 50 --no-pager

# Queue worker log
journalctl -u pteroq -n 50 --no-pager
```

---

## 📜 License

Licensed under the [GNU General Public License v3.0](LICENSE).

This installer is **not affiliated** with the official [Pterodactyl Project](https://pterodactyl.io).

---

<div align="center">

Made by **[XENTO](https://github.com/thexento)**

[pterodactyl-installer.xento.xyz](https://pterodactyl-installer.xento.xyz) · [GitHub](https://github.com/thexento/Pterodactyl-Installer)

</div>