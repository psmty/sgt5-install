# 📦 SGT5 Bootstrap Installer

Welcome!
This is the **official installation wizard** for setting up the SGT5 system on your server or local environment.

This repository is designed to simplify the installation process, even for users without deep technical knowledge.

---

## 📑 Table of Contents

* 🚀 [Installation](#-installation)
* 🛠️ [What You Need](#️-what-you-need)
* 📖 [Remote Setup with VS Code](#remote-setup-with-vs-code)

---

## Installation

To begin, open your terminal and run the following command **in an empty folder**:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)"
```

That’s it! 🎉
The script will:

* Ask for your GitHub token to access the private installation files
* Automatically download and prepare the system
* Start an easy-to-follow setup wizard

> **Important:** The script might require a restart after the first run. After rebooting, simply run the script again to complete the setup.

> ⚠️ **If the installation is interrupted** for any reason (e.g. network failure, manual stop), you can safely re-run the above installation command.
> Alternatively, if the environment is already prepared, you can resume the setup by running:
>
> ```bash
> sgt5 -i
> ```

---

## What You Need

* A valid **GitHub Personal Access Token (PAT)**
* A **Linux environment** (Ubuntu recommended)

---

## Remote Setup with VS Code

> This section explains how to connect to your server using Visual Studio Code’s Remote SSH feature and prepare your environment for SGT5 installation.

### 1. Download Visual Studio Code

Download and install Visual Studio Code from [https://code.visualstudio.com/](https://code.visualstudio.com/).

### 2. Install Remote Extensions

Open the Extensions panel (from the left sidebar), type `remote`, and install:

* **Remote – SSH**
* **Remote Explorer**

![Screenshot](images/extensions.png)

---

### 3. Configure SSH Connection

1. Open the **Remote Explorer** panel on the left.

2. Click the **“+”** icon next to SSH.

    ![Screenshot](images/new-connection.png)

3. Enter your SSH connection string in the following format:

   ```
   username@server-ip
   ```

4. Choose the file to save your SSH settings (by default, select the `.ssh/config` inside your user profile).

    ![Screenshot](images/ssh-settings.png)

---

### 4. Connect to the Server

* A notification will appear at the bottom right. Click **“Connect”**.

    ![Screenshot](images/connect-notification.png)

* If this is your first time connecting, you may see a certificate warning. Click **“Continue”** to trust the certificate and proceed.

    ![Screenshot](images/cert-warning.png)

* Enter your SSH user password when prompted.

    ![Screenshot](images/password-input.png)

### 5. Wait for VS Code Server Installation

* VS Code will install a server application on your remote machine.
* You can monitor the progress in the notifications area at the bottom right.

![Screenshot](images/vscode-server-notification.png)

### 6. Open the Root Folder

1. Once connected, click **Open Folder**.
2. In the dialog, enter `/` and click **OK**.
3. You may be prompted for your password again.

![Screenshot](images/open-folder.png)

### 7. Create the `sgt5` Folder

![Screenshot](images/new-folder.png)

* **Method A:**
  If you have permission, click the **new folder** icon in the left panel and create a folder named `sgt5`.

* **Method B:**
  If you need elevated permissions, open the **Terminal** (from the top menu: `Terminal` → `New Terminal`) and run:

  ```sh
  sudo mkdir /sgt5
  ```

  Enter your password if prompted.

* Make sure the `sgt5` folder appears in the folder list on the left.

### 8. Open the `sgt5` Folder in VS Code

1. Go to the top menu and select **File** → **Open Folder**.

    ![Screenshot](images/open-folder-sgt5.png)

2. Type `/sgt5`, select the `sgt5` folder from the list, and click **OK**.

    ![Screenshot](images/open-folder-sgt5-popup.png)

3. Enter your password again if prompted.

* You should now see the `sgt5` folder open in the left panel.

### 9. Open a Terminal

* If the **Terminal** is not already open, select it from the top menu: `Terminal` → `New Terminal`.

### 10. Run the Installation Command

![Screenshot](images/terminal.png)

Paste the following command into your terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)"
```

* Follow the steps in the installer.
* Depending on your system and installed packages, you might need to restart your server once. The installer will notify you if a reboot is required.

---

**That’s it!**
Your SGT5 environment should now be ready.

> **Note:** To use valid SSL certificates, copy your certificate files (`chain.pem` and `key.pem`) to the `./storage/nginx/ssl-certificates` directory.

# SSH Key Authentication Setup Guide

## Windows Setup (One-time setup)

### 1. Generate SSH Key Pair
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```
- File location: Press Enter (use default)
- Passphrase: Optional (leave empty or set password)

## Linux Server Setup (Per server)

### 2. Copy Public Key to Server
```bash
type C:\Users\$env:USERNAME\.ssh\id_rsa.pub | ssh root@SERVER_IP "mkdir -p ~/.ssh && cat > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 3. Fix Permissions on Server
Connect to server with password:
```bash
ssh root@SERVER_IP
```

Set critical permissions:
```bash
chmod 700 /root
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 4. Check SSH Configuration
```bash
sudo nano /etc/ssh/sshd_config
```

Ensure these lines are correct:
```
PermitRootLogin yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

### 5. Restart SSH Service
```bash
sudo systemctl restart ssh
```

### 6. Test Connection
```bash
exit
ssh root@SERVER_IP
```

## Troubleshooting

### Common Issues:
- **Connection refused**: Check `/root` directory permissions (must be 700)
- **Key not working**: Verify key hash matches between Windows and server
- **Permission denied**: Check SSH config and restart SSH service

### Debug Commands:
```bash
# Check key hash on Windows
ssh-keygen -lf C:\Users\$env:USERNAME\.ssh\id_rsa.pub

# Check key hash on server
ssh-keygen -lf ~/.ssh/authorized_keys

# Debug SSH connection
ssh -v root@SERVER_IP

# Check SSH logs
sudo journalctl -u ssh -n 20
```

## Security Notes

- **Critical**: `/root` directory must have 700 permissions
- Consider disabling password authentication after key setup:
  ```
  PasswordAuthentication no
  ```
- Keep private key (`id_rsa`) secure and never share it
- Public key (`id_rsa.pub`) can be safely shared

## Success
✅ Password-less SSH authentication  
✅ Enhanced security  
✅ No more password typing