# Nextcloud Troubleshooting Guide

## Quick Commands

```bash
# Check status
sudo ./nc.sh status

# Full diagnostics
sudo ./nc.sh diagnose

# Fix cron issues
sudo ./nc.sh cron fix

# View logs
sudo ./nc.sh logs 100
```

## Module-Specific Commands

Each module can be run directly with command-line arguments:

```bash
# Cron module
sudo ./modules/cron-fix.sh status    # Check cron status
sudo ./modules/cron-fix.sh fix       # Fix all cron issues
sudo ./modules/cron-fix.sh run       # Run cron manually

# Diagnostics module
sudo ./modules/diagnose.sh quick     # Quick status
sudo ./modules/diagnose.sh full      # Full diagnostics
sudo ./modules/diagnose.sh test      # Test connectivity
sudo ./modules/diagnose.sh logs nextcloud 100  # View logs

# Quick fixes module
sudo ./modules/quick-fixes.sh permissions  # Fix permissions
sudo ./modules/quick-fixes.sh database     # Fix database
sudo ./modules/quick-fixes.sh redis        # Fix Redis
sudo ./modules/quick-fixes.sh all          # Fix everything
```

---

## Common Issues

### 1. Cron Not Running

**Symptoms:**
- Admin warning: "Background jobs haven't run in XX minutes"
- Notifications not being sent
- File scanning not working

**Diagnosis:**
```bash
sudo ./modules/cron-fix.sh status
```

**Quick Fix:**
```bash
sudo ./modules/cron-fix.sh fix
```

**Manual Debug:**
```bash
# Check timer status
systemctl status nextcloud-cron.timer

# Check service status
systemctl status nextcloud-cron.service

# View recent runs
journalctl -u nextcloud-cron.service -n 20

# Run cron manually
podman exec -u www-data nextcloud php -f /var/www/html/cron.php

# Check last cron time in Nextcloud
podman exec -u www-data nextcloud php occ config:app:get core lastcron
```

---

### 2. Database Connection Failed

**Symptoms:**
- "Error establishing database connection"
- Nextcloud shows blank page
- 500 errors

**Diagnosis:**
```bash
# Check if MariaDB is running
podman ps | grep mariadb

# Test connection
podman exec nextcloud-db mysql -ugeoffcloud -p'2Bv$rWt$o94g!%4xBYiQ8C8' -e "SELECT 1"
```

**Quick Fix:**
```bash
sudo ./modules/quick-fixes.sh database
```

**Manual Fix:**
```bash
# Start MariaDB
podman start nextcloud-db

# Check logs
podman logs nextcloud-db
```

---

### 3. Port 8080 Not Listening

**Symptoms:**
- Cannot access Nextcloud at http://192.168.1.138:8080
- curl returns "Connection refused"

**Diagnosis:**
```bash
ss -tlnp | grep 8080
podman ps
```

**Quick Fix:**
```bash
sudo ./modules/quick-fixes.sh port
```

**Manual Fix:**
```bash
# Restart the pod
podman pod restart nextcloud-pod

# Check if Nextcloud container started
podman ps
podman logs nextcloud
```

---

### 4. Permission Denied Errors

**Symptoms:**
- Cannot upload files
- "Permission denied" in logs
- Data directory not writable

**Diagnosis:**
```bash
ls -la /mnt/cloud/data
podman exec nextcloud ls -la /var/www/html/data
```

**Quick Fix:**
```bash
sudo ./modules/quick-fixes.sh permissions
```

**Manual Fix:**
```bash
# Fix ownership (www-data = 33:33)
sudo chown -R 33:33 /mnt/cloud/data
sudo chmod 750 /mnt/cloud/data
```

---

### 5. Redis Not Working

**Symptoms:**
- Slow performance
- Admin warning about caching
- File locking errors

**Diagnosis:**
```bash
podman ps | grep redis
podman exec nextcloud-redis redis-cli ping
```

**Quick Fix:**
```bash
sudo ./modules/quick-fixes.sh redis
```

**Manual Fix:**
```bash
# Start Redis
podman start nextcloud-redis

# Configure in Nextcloud
podman exec -u www-data nextcloud php occ config:system:set redis host --value="127.0.0.1"
podman exec -u www-data nextcloud php occ config:system:set redis port --value=6379 --type=integer
podman exec -u www-data nextcloud php occ config:system:set memcache.local --value='\OC\Memcache\Redis'
podman exec -u www-data nextcloud php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
```

---

### 6. SSL Certificate Issues

**Symptoms:**
- Browser shows "Not Secure"
- Certificate expired warnings
- iOS/Android app won't connect

**Check Certificate:**
```bash
openssl x509 -in /etc/ssl/certs/nextcloud.crt -noout -dates
```

**Regenerate:**
```bash
# Use the SSL module (or manually):
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nextcloud.key \
  -out /etc/ssl/certs/nextcloud.crt \
  -subj "/C=US/ST=Home/L=Network/O=LLHome/CN=llcloud" \
  -addext "subjectAltName=DNS:llcloud,IP:192.168.1.138"

sudo systemctl reload nginx
```

---

### 7. Domain Name Not Resolving

**Symptoms:**
- `ping llcloud` fails
- Works with IP but not domain name

**Check:**
```bash
# On server
cat /etc/hosts | grep llcloud

# On Mac
cat /etc/hosts | grep llcloud
```

**Fix (Server):**
```bash
echo "192.168.1.138    llcloud" | sudo tee -a /etc/hosts
```

**Fix (Mac):**
```bash
sudo nano /etc/hosts
# Add: 192.168.1.138    llcloud
```

**Fix (Router):**
- See Router DNS guide in main menu (option 14)

---

## Log Locations

| Log | Location |
|-----|----------|
| Nextcloud container | `podman logs nextcloud` |
| MariaDB container | `podman logs nextcloud-db` |
| Redis container | `podman logs nextcloud-redis` |
| Nextcloud app | `/mnt/cloud/data/nextcloud.log` |
| Nginx access | `/var/log/nginx/nextcloud.access.log` |
| Nginx error | `/var/log/nginx/nextcloud.error.log` |
| Systemd cron | `journalctl -u nextcloud-cron.service` |

---

## Useful OCC Commands

```bash
# Wrapper function (defined in lib/common.sh)
occ() { podman exec -u www-data nextcloud php occ "$@"; }

# Common commands:
occ status                          # Nextcloud status
occ user:list                       # List users
occ files:scan --all                # Rescan all files
occ maintenance:mode --on/--off     # Maintenance mode
occ config:list                     # Show all config
occ background:cron                 # Set cron mode
occ db:add-missing-indices          # Fix database indexes
occ upgrade                         # Run upgrades
```

---

## Emergency Recovery

### Container Won't Start
```bash
# Remove and recreate container (data preserved)
podman stop nextcloud
podman rm nextcloud

# Recreate (adjust as needed)
podman run -d \
  --name nextcloud \
  --pod nextcloud-pod \
  -v /mnt/cloud/data:/var/www/html/data:Z \
  -e MYSQL_HOST=nextcloud-db \
  -e MYSQL_DATABASE=llcloud \
  -e MYSQL_USER=geoffcloud \
  -e MYSQL_PASSWORD='2Bv$rWt$o94g!%4xBYiQ8C8' \
  --restart=always \
  docker.io/library/nextcloud:latest
```

### Complete Pod Restart
```bash
podman pod restart nextcloud-pod
```

### Database Backup
```bash
podman exec nextcloud-db mysqldump -ugeoffcloud -p'2Bv$rWt$o94g!%4xBYiQ8C8' llcloud > backup.sql
```

### Database Restore
```bash
podman exec -i nextcloud-db mysql -ugeoffcloud -p'2Bv$rWt$o94g!%4xBYiQ8C8' llcloud < backup.sql
```
