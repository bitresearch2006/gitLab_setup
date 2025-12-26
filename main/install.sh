#!/usr/bin/env bash
set -e

echo "========================================"
echo " GitLab CE + Google Drive Backup Installer"
echo "========================================"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

read -rp "Enter GitLab URL (example: http://localhost:8081 or http://192.168.1.50:8081): " GITLAB_URL

if [ -z "$GITLAB_URL" ]; then
  echo "❌ GitLab URL cannot be empty."
  exit 1
fi

BACKUP_SCRIPT_SRC="./gitlab_gdrive_backup.sh"
SERVICE_SRC="./gitlab-gdrive-backup.service"
TIMER_SRC="./gitlab-gdrive-backup.timer"

BACKUP_SCRIPT_DST="/usr/local/sbin/gitlab_gdrive_backup.sh"
SERVICE_DST="/etc/systemd/system/gitlab-gdrive-backup.service"
TIMER_DST="/etc/systemd/system/gitlab-gdrive-backup.timer"

echo "➡️ GitLab URL: $GITLAB_URL"
echo

echo "📦 Updating system..."
apt update -y
apt upgrade -y

echo "📦 Installing prerequisites..."
apt install -y curl ca-certificates tzdata openssh-server perl rclone

if ! dpkg -l | grep -q postfix; then
  echo "📧 Installing postfix (non-interactive safe config)..."
  echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
  echo "postfix postfix/mailname string localhost" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt install -y postfix
fi

echo "➕ Adding GitLab repository..."
curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

echo "📥 Installing GitLab CE..."
EXTERNAL_URL="$GITLAB_URL" apt install -y gitlab-ce

echo "⚙️ Configuring GitLab..."
gitlab-ctl reconfigure

echo
echo "========================================"
echo "🔐 Google Drive Authorization (rclone)"
echo "========================================"
echo "Run as root. For SSH/headless:"
echo " - New remote → name: gdrive"
echo " - Storage: drive"
echo " - Auto config? → n"
echo " - Open URL in your browser and paste code."
echo
read -rp "👉 Press ENTER to start rclone config..."

rclone config

echo "🧪 Testing Google Drive access..."
rclone lsd gdrive: || {
  echo "❌ Google Drive access failed. Re-run: sudo rclone config"
  exit 1
}

echo
echo "========================================"
echo "📝 Installing backup script and services"
echo "========================================"

for f in "$BACKUP_SCRIPT_SRC" "$SERVICE_SRC" "$TIMER_SRC"; do
  if [ ! -f "$f" ]; then
    echo "❌ Required file not found: $f"
    exit 1
  fi
done

echo "➡️ Copying backup script..."
cp "$BACKUP_SCRIPT_SRC" "$BACKUP_SCRIPT_DST"
chmod +x "$BACKUP_SCRIPT_DST"

echo "➡️ Copying systemd service and timer..."
cp "$SERVICE_SRC" "$SERVICE_DST"
cp "$TIMER_SRC" "$TIMER_DST"

echo "🔄 Reloading systemd and enabling timer..."
systemctl daemon-reload
systemctl enable --now gitlab-gdrive-backup.timer

echo
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo
echo "🌐 GitLab URL: $GITLAB_URL"
echo "👤 Username: root"
echo "🔑 Initial password:"
echo "   sudo cat /etc/gitlab/initial_root_password"
echo
echo "💾 Backups:"
echo "  Local : /var/opt/gitlab/backups/"
echo "  Drive : My Drive/gitlab-backups/"
echo
echo "⏱️ Timer status:"
systemctl list-timers | grep gitlab-gdrive-backup || true
echo
echo "📄 Logs: /var/log/gitlab_gdrive_backup.log"
