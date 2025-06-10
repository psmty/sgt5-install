
# 📦 SGT5 Bootstrap Installer

Welcome!  
This is the **official installation wizard** for setting up the SGT5 system on your server or local environment.

This repository is designed to simplify the installation process, even for users without deep technical knowledge.

---

## 🚀 Installation

To begin, open your terminal and run the following command **in an empty folder**:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)"
```

That’s it! 🎉  
The script will:

- Ask for your GitHub token to access the private installation files  
- Automatically download and prepare the system  
- Start an easy-to-follow setup wizard

> **Important:** The script might require a restart after the first run. After rebooting, simply run the script again to complete the setup.

> ⚠️ **If the installation is interrupted** for any reason (e.g. network failure, manual stop), you can safely re-run the same command.  
> Alternatively, if the environment is already prepared, you can resume the setup by running:
>
> ```bash
> sgt5 -i
> ```
> or
> ```bash
> ./start.sh -i
> ```

---

## 🛠️ What You Need

- A GitHub account with access to the private SGT5 repository  
- A valid **GitHub Personal Access Token (PAT)**  
- A **Linux environment** (Ubuntu recommended)  
- An **empty folder** to begin installation

---

## 📁 What Will Happen?

After you run the install command:

1. The script will **verify the folder is empty**
2. You’ll be prompted to **enter your GitHub token**
3. The necessary files will be **downloaded securely**
4. A setup wizard will guide you through configuration (timezone, database, etc.)

---

## 🖥️ Connecting via VS Code

For easier server management, we recommend using **VS Code**. It allows you to connect directly to your Linux server and manage the installation process effortlessly.

### Recommended Extensions:

- **Remote Explorer**:  
  Use [this extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.remote-explorer) to easily explore and manage your remote server.

- **Docker**:  
  With [this extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker), you can manage your Docker containers with a graphical interface directly from VS Code.

---

## 📬 Questions or Help?

If you experience any problems during installation, please contact your system administrator or the SGT5 development team.

---
