# GitLab CE Local Setup with Google Drive Backup

This project provides scripts to install a **self-hosted GitLab Community Edition (CE)** on a Linux machine and configure **automatic backups** that are pushed to **Google Drive**.

It is designed for developers or small teams who want:
- A local GitLab server for review tracking
- Simple installation on Ubuntu/Debian
- Automatic remote backups with minimal setup
- Easy uninstall and cleanup

---

## 🚀 Features

- 📦 Installs GitLab CE on Linux
- 🌐 Runs GitLab at a user-defined URL (e.g. `http://localhost:8081`)
- 🔐 Guides Google Drive authorization using `rclone`
- 💾 Uses GitLab’s built-in backup mechanism
- ☁️ Pushes backups to Google Drive automatically
- ♻️ Keeps **only the latest backup** (old backups removed)
- ⏱️ Sets up systemd service & timer (runs after boot + daily)
- 🧹 Provides uninstall script to revert changes
- 📜 MIT licensed – free and open source

---

## 🧰 Requirements

- Ubuntu 20.04/22.04 or Debian 11/12
- Root or sudo access
- Minimum:
  - 4 GB RAM (8 GB recommended)
  - 20 GB free disk space
- Internet access
- A Google account with Drive enabled
- SSH access is fine (headless supported)

---

## 📁 Repository Structure

.
├── install_gitlab_ce_with_gdrive_and_backup.sh
├── uninstall_gitlab_ce_with_gdrive.sh
├── gitlab_gdrive_backup.sh
├── gitlab-gdrive-backup.service
├── gitlab-gdrive-backup.timer
├── README.md
└── LICENSE

yaml
Copy code

---

## 📥 What Gets Installed

- GitLab Community Edition
- PostgreSQL, Redis, Nginx (bundled with GitLab)
- `rclone` for Google Drive sync
- Postfix (optional, for email notifications)

GitLab live data:
/var/opt/gitlab

yaml
Copy code

GitLab backups:
/var/opt/gitlab/backups

yaml
Copy code

---

## ⚙️ Installation

Clone this repository:

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
Make installer executable:

bash
Copy code
chmod +x install_gitlab_ce_with_gdrive_and_backup.sh
Run installer:

bash
Copy code
sudo ./install_gitlab_ce_with_gdrive_and_backup.sh
You will be prompted for:

php
Copy code
Enter GitLab URL (example: http://localhost:8081 or http://192.168.1.50:8081):
During installation:

GitLab CE will be installed

You will be guided to run rclone config for Google Drive auth

Backup script and systemd service/timer will be copied and enabled

⚠️ On SSH/headless servers, choose n for auto config and open the URL shown in your local browser to authorize Google.

🌐 Access GitLab
Open in your browser:

php-template
Copy code
<GitLab URL you entered>
Login:

Username: root

Password:

bash
Copy code
sudo cat /etc/gitlab/initial_root_password
(Valid for 6 hours — change it after first login.)

🔄 Backups & Google Drive Sync
Backups are created using:

bash
Copy code
gitlab-backup create
They are stored locally in:

swift
Copy code
/var/opt/gitlab/backups/
Then uploaded to Google Drive folder:

bash
Copy code
My Drive/gitlab-backups/
🔁 Retention Policy
✅ Only the latest backup is kept locally

❌ Older backups are deleted after each new backup

☁️ Google Drive also keeps only the latest backup

⏱️ Backup Schedule
Backups are triggered by a systemd timer:

▶️ 10 minutes after system boot

🔁 Every 6 hours thereafter

🛡️ If the system was off, it runs once after boot

Check timer:

bash
Copy code
systemctl list-timers | grep gitlab-gdrive-backup
Logs:

bash
Copy code
tail -f /var/log/gitlab_gdrive_backup.log
♻️ Restore from Backup
Copy latest backup from Drive:

bash
Copy code
sudo rclone copy gdrive:gitlab-backups /var/opt/gitlab/backups
Restore:

bash
Copy code
sudo gitlab-backup restore BACKUP=<timestamp>
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
🧹 Uninstall
To revert all changes:

bash
Copy code
chmod +x uninstall_gitlab_ce_with_gdrive.sh
sudo ./uninstall_gitlab_ce_with_gdrive.sh
The script will:

Stop & remove backup service/timer

Remove backup script

Optionally uninstall GitLab CE

Optionally remove GitLab data/config

Optionally remove rclone and its config

⚠️ You will be prompted before deleting any data.

🔐 Security Notes
Google Drive access uses OAuth tokens via rclone

No Google password is stored

Tokens are saved at:

swift
Copy code
/root/.config/rclone/rclone.conf
You can revoke access anytime from your Google Account → Security → Third-party access

# 🪟 Running GitLab CE on WSL (Windows Subsystem for Linux)

> GitLab Omnibus CE is designed for full Linux servers. It **can run on WSL2**, but requires additional fixes due to WSL networking, socket handling, and service supervision differences.

This document summarizes **all working changes** required to make GitLab CE functional on WSL2.

---

## ✅ 1. Use WSL2 (not WSL1)
GitLab requires:
- Proper networking
- UNIX socket compatibility
- Runit-based service supervision

Check version:
```bash
wsl -l -v
```
Convert if needed:
```bash
wsl --set-version Ubuntu 2
```

---

## ✅ 2. Fix PostgreSQL peer authentication failure
WSL often runs GitLab services as **root**, causing PostgreSQL to reject peer authentication.

If you see:
```
FATAL: Peer authentication failed for user "gitlab"
```
Edit PostgreSQL auth:
```bash
sudo nano /var/opt/gitlab/postgresql/data/pg_hba.conf
```
Replace:
```text
local   all         all         peer map=gitlab
```
with:
```text
local   all         all         md5
```
OR (WSL‑friendly):
```text
local   all         all         trust
```
Apply:
```bash
sudo gitlab-ctl restart postgresql
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
```

---

## ✅ 3. Fix Puma not responding / NGINX 502 errors
WSL has unstable UNIX socket support. Puma may create the socket file but fail to fully bind.

Fix: **Force Puma to use TCP instead of UNIX socket.**

Edit:
```bash
sudo nano /etc/gitlab/gitlab.rb
```
Add:
```ruby
# WSL-compatible Puma binding
puma['listen'] = '0.0.0.0'
puma['port'] = 8181

# Route Workhorse to Puma
gitlab_workhorse['auth_backend'] = "http://127.0.0.1:8181"
```
Apply:
```bash
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
```
Validate:
```bash
sudo ss -tulpn | grep 8181
curl http://localhost:8181/-/health
```

---

## ✅ 4. Access GitLab from Windows
WSL networking may treat `127.0.0.1` differently.

Use:
```
http://localhost:8080
```
Avoid:
```
http://127.0.0.1:8080
```

---

## ✅ 5. systemd timers & backup jobs on WSL
WSL may not have systemd enabled.

Check:
```bash
systemctl is-system-running
```

### Option A — Enable systemd
Edit:
```
/etc/wsl.conf
```
Add:
```ini
[boot]
systemd=true
```
Restart:
```powershell
wsl --shutdown
```

### Option B — Run backup manually
```bash
sudo ./gitlab_gdrive_backup.sh
```

---

## ✅ 6. Recommended WSL memory settings
Create/edit:
```
%UserProfile%\.wslconfig
```
Add:
```ini
[wsl2]
memory=8GB
processors=4
```
Restart WSL:
```powershell
wsl --shutdown
```

---

🧪 Tested On
Ubuntu 20.04 / 22.04

Debian 11 / 12

📜 License
MIT License. See LICENSE.

🤝 Contributing
Contributions and improvements are welcome!
Feel free to open issues or submit pull requests.