#!/usr/bin/env bash
set -e

BACKUP_DIR="/var/opt/gitlab/backups"
REMOTE="gdrive:gitlab-backups"
LOG="/var/log/gitlab_gdrive_backup.log"

echo "==== $(date) Starting GitLab backup ====" >> "$LOG"

# Create GitLab backup
gitlab-backup create >> "$LOG" 2>&1

# Find latest backup file
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*_gitlab_backup.tar | head -n 1)

echo "Latest backup: $LATEST_BACKUP" >> "$LOG"

# Delete all older backups, keep only latest
ls -t "$BACKUP_DIR"/*_gitlab_backup.tar | tail -n +2 | xargs -r rm -f

echo "Uploading latest backup to Google Drive..." >> "$LOG"

# Sync only latest backup
rclone copy "$LATEST_BACKUP" "$REMOTE" >> "$LOG" 2>&1

echo "==== $(date) Backup & upload finished ====" >> "$LOG"
