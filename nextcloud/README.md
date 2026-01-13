# LLHome Nextcloud Management Scripts

Modular management system for Nextcloud running in Podman containers.

## Quick Start

```bash
# Copy entire folder to server
scp -r nextcloud/ user@192.168.1.138:~/

# On server, run the main menu
cd ~/nextcloud
sudo ./nc.sh
```

## Structure

```
nextcloud/
├── nc.sh                     # Main entry point
├── lib/
│   └── common.sh             # Shared config & functions
├── modules/
│   ├── diagnose.sh           # System diagnostics
│   ├── cron-fix.sh           # Cron/background job fixes
│   ├── quick-fixes.sh        # Common issue fixes
│   ├── warnings-fix.sh       # Admin panel warning fixes
│   ├── users.sh              # User management
│   └── backup.sh             # Backup & restore
└── docs/
    └── TROUBLESHOOTING.md    # Troubleshooting guide
```

## Usage

### Interactive Menu
```bash
sudo ./nc.sh
```

### Command Line
```bash
sudo ./nc.sh status           # Quick status
sudo ./nc.sh diagnose         # Full diagnostics
sudo ./nc.sh cron fix         # Fix cron issues
sudo ./nc.sh warnings all     # Fix all warnings
sudo ./nc.sh logs 100         # View last 100 log lines
```

### Run Modules Directly
```bash
sudo ./modules/cron-fix.sh status
sudo ./modules/cron-fix.sh fix

sudo ./modules/warnings-fix.sh check
sudo ./modules/warnings-fix.sh all

sudo ./modules/quick-fixes.sh all

sudo ./modules/diagnose.sh full
sudo ./modules/diagnose.sh logs nextcloud 50
```

## Configuration

Edit `lib/common.sh` to change:
- Server IP address
- Domain name
- Container names
- Database credentials
- File paths

## Modules

### diagnose.sh
- Quick status check
- Full system diagnostics
- Connectivity tests
- Log viewing

### cron-fix.sh
- Diagnose cron issues
- Create/update systemd timer
- Run cron manually
- Troubleshooting guide

### warnings-fix.sh
- Check current status
- Fix background jobs
- Fix trusted proxies
- Fix HTTPS config
- Fix maintenance window
- Fix database indexes
- Fix Redis caching
- Fix HSTS header

### quick-fixes.sh
- Permissions
- Database connection
- Pod networking
- Port 8080
- Container startup
- Redis

### users.sh
- List users
- Create/delete users
- Reset passwords
- Scan user files

### backup.sh
- Create full backups
- List existing backups
- Restore from backup
- Cleanup old backups

## Troubleshooting

See `docs/TROUBLESHOOTING.md` for detailed help with common issues.

Quick reference:
```bash
# Check if cron is working
sudo ./modules/cron-fix.sh status

# View Nextcloud logs
podman logs nextcloud | tail -50

# Check systemd timer
systemctl status nextcloud-cron.timer

# Manual cron run
podman exec -u www-data nextcloud php -f /var/www/html/cron.php
```
