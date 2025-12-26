#!/usr/bin/env bash
set -e

echo "========================================"
echo " Uninstall GitLab CE + Google Drive Backup"
echo "========================================"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

SERVICE="gitlab-gdrive-backup.service"
TIMER="gitlab-gdrive-backup.timer"
BACKUP_SCRIPT="/usr/local/sbin/gitlab_gdrive_backup.sh"

echo
echo "➡️ Stopping and disabling backup timer/service..."

systemctl stop "$TIMER" 2>/dev/null || true
systemctl disable "$TIMER" 2>/dev/null || true
systemctl stop "$SERVICE" 2>/dev/null || true
systemctl disable "$SERVICE" 2>/dev/null || true

echo "➡️ Removing systemd unit files..."
rm -f "/etc/systemd/system/$SERVICE"
rm -f "/etc/systemd/system/$TIMER"

echo "➡️ Reloading systemd..."
systemctl daemon-reload

echo
echo "➡️ Removing backup script..."
rm -f "$BACKUP_SCRIPT"

echo
read -rp "❓ Do you want to uninstall GitLab CE package? [y/N]: " REMOVE_GITLAB
if [[ "$REMOVE_GITLAB" =~ ^[Yy]$ ]]; then
  echo "➡️ Uninstalling GitLab CE..."
  apt purge -y gitlab-ce
  apt autoremove -y
else
  echo "ℹ️ Skipping GitLab package removal."
fi

echo
read -rp "❓ Do you want to remove GitLab DATA (/var/opt/gitlab)? This deletes all repos & issues! [y/N]: " REMOVE_DATA
if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
  echo "⚠️ Deleting /var/opt/gitlab ..."
  rm -rf /var/opt/gitlab
else
  echo "ℹ️ Keeping GitLab data."
fi

echo
read -rp "❓ Do you want to remove GitLab config (/etc/gitlab)? [y/N]: " REMOVE_CONFIG
if [[ "$REMOVE_CONFIG" =~ ^[Yy]$ ]]; then
  echo "➡️ Deleting /etc/gitlab ..."
  rm -rf /etc/gitlab
else
  echo "ℹ️ Keeping GitLab config."
fi

echo
read -rp "❓ Do you want to uninstall rclone (Google Drive tool)? [y/N]: " REMOVE_RCLONE
if [[ "$REMOVE_RCLONE" =~ ^[Yy]$ ]]; then
  echo "➡️ Uninstalling rclone..."
  apt purge -y rclone
  apt autoremove -y
else
  echo "ℹ️ Keeping rclone."
fi

echo
read -rp "❓ Do you want to remove rclone config for root (/root/.config/rclone)? [y/N]: " REMOVE_RCLONE_CFG
if [[ "$REMOVE_RCLONE_CFG" =~ ^[Yy]$ ]]; then
  echo "➡️ Removing rclone config..."
  rm -rf /root/.config/rclone
else
  echo "ℹ️ Keeping rclone config."
fi

echo
echo "========================================"
echo "✅ Uninstall completed."
echo "========================================"
echo
echo "ℹ️ Summary:"
echo " - Backup service/timer removed"
echo " - Backup script removed"
echo " - GitLab, data, and rclone removed based on your choices"
echo
echo "If you plan to reinstall later, you can rerun the install script."
