# Troubleshooting

Common issues when running the dev setup script and how to fix them.

---

## "xcode-select: command not found" or Xcode popup never appears

- You must be on **macOS**. The script uses Apple’s Xcode Command Line Tools.
- If the install popup doesn’t appear:
  1. Open **System Settings → General → Software Update** and install any pending updates.
  2. Run in Terminal: `xcode-select --install` and accept the dialog.
- After installing, **close and reopen Terminal**, then run the setup script again.

---

## "brew: command not found" after installing Homebrew

Homebrew is often installed to a path that your current Terminal session doesn’t use yet.

- **Quit Terminal completely** (Cmd+Q), open it again, and run:
  ```bash
  brew --version
  ```
- If it still fails:
  - **Apple Silicon (M1/M2/M3):** run `eval "$(/opt/homebrew/bin/brew shellenv)"` and try again.
  - **Intel:** run `eval "$(/usr/local/bin/brew shellenv)"` and try again.
- Then run the setup script again; it will detect Homebrew and continue.

---

## "gh auth login" fails or browser doesn’t open

- Make sure you have a working internet connection.
- Try running manually:
  ```bash
  gh auth login
  ```
  Choose **GitHub.com**, **HTTPS** or **SSH** (SSH is what the script sets up), and follow the prompts.
- If your organization uses **SSO**, after adding your SSH key on GitHub, open the key and click **Enable SSO** for the right organization.

---

## "Permission denied (publickey)" when cloning or pushing

This usually means GitHub doesn’t recognize your SSH key yet.

1. **Did you paste the _public_ key on GitHub?**  
   The script shows a path like `~/.ssh/id_rsa_work.pub`. You must copy the _contents_ of that file (e.g. `cat ~/.ssh/id_rsa_work.pub`) and add it at [GitHub → Settings → SSH and GPG keys](https://github.com/settings/keys).
2. **Using the script’s alias?**  
   If the script created a host like `github-work`, clone with:
   ```bash
   git clone git@github-work:org/repo-name.git
   ```
   not `git@github.com:org/repo-name.git` (unless you want to use your _default_ SSH key).
3. **Test the key:**
   ```bash
   ssh -T git@github.com
   ```
   Or, for the alias: `ssh -T git@github-work` (replace with your alias). You should see a success message from GitHub.

---

## Script says "This script is intended for macOS"

The script is written for **macOS** only. On Linux, paths and package managers differ. A `dev-setup-linux.sh` may be added in the future; until then, you’ll need to install Git, GitHub CLI, and SSH keys manually or use your distro’s docs.

---

## Gitleaks or secret scanner blocks my commit

See **[SECRETS.md](../SECRETS.md)** in the repo root. It explains why commits are blocked and how to remove or move secrets safely.

---

## Still stuck?

- Re-read the script’s on-screen messages; it often tells you to “open a new Terminal” or “press Enter when ready.”
- Check [docs/faq.md](faq.md) for concepts like Homebrew, SSH, and `gh`.
- If this repo is used at work, ask in your engineering teams
