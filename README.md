# GitHub Dev Setup (macOS)

A **beginner-friendly onboarding kit** that gets your Mac ready for coding and GitHub. One script sets up the tools you need and walks you through creating an SSH key and connecting to GitHub.

---

## What This Does

The setup script will:

1. **Xcode Command Line Tools** - Required for building and compiling on macOS (Apple will prompt you to install if needed).
2. **Homebrew** - A package manager so you can install developer tools with simple commands.
3. **Git & GitHub CLI** - Git for version control; `gh` for working with GitHub from the terminal.
4. **SSH key + GitHub** - Creates an SSH key, adds it to your Mac’s key agent, and opens GitHub’s SSH keys page so you can paste it and sign in (including SSO if your org uses it).
5. **Optional: Claude Code CLI** - You can choose to install the official Claude Code CLI during the script.

The script **does not** overwrite any existing GitHub SSH key. It uses a separate “alias” (e.g. `github-work`) so your personal key stays as default for `github.com` if you already use one.

---

## Prerequisites

- **macOS** (this script is for Mac only; a Linux version may be added later).
- **A GitHub account** - [Create one](https://github.com/join) if you don’t have it.
- **About 15–30 minutes** - Some steps need you to confirm or complete something in the browser.

---

## How to Run (First-Time Users)

### 1. Open Terminal

- Press **Cmd + Space**, type **Terminal**, press **Enter**  
  or
- Open **Finder → Applications → Utilities → Terminal**.

### 2. Run the scripts

**Option A - Run from the web (no clone):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mindvalley-ai/dev-bootstrap/main/scripts/macos-setup.sh)"
```

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mindvalley-ai/dev-bootstrap/main/scripts/gcloud-setup.sh)"
```

Replace `YOUR_USERNAME` with the GitHub username that owns this repo (or the fork you’re using).

**Option B - Clone the repo, then run locally:**

```bash
cd ~
git clone https://github.com/mindvalley-ai/dev-bootstrap.git
cd dev-bootstrap
bash scripts/macos-setup.sh
```

### 3. Follow the prompts

The script will ask for:

- An **email** (used as a comment on your SSH key).
- An optional **label** (e.g. `work` or `company`) to name this setup.
- Whether to install **Homebrew** and **Claude Code CLI** if they’re not already there.

When it opens the GitHub SSH keys page, paste your **public** key (the script will show you which one) and save. If your organization uses SSO, click **Enable SSO** for that key.

---

## Project Layout

```
github-setup/
├── README.md                 ← You are here
├── SECRETS.md                ← How to handle secrets in Git (read this early!)
├── scripts/
│   └── macos-setup.sh    ← The main setup script
├── docs/
│   ├── troubleshooting.md    ← Common issues and fixes
│   └── faq.md                ← Frequently asked questions
└── .gitignore
```

- **SECRETS.md** - Explains why commits can be blocked when secrets are detected and how to fix it. Important for new coders.
- **docs/troubleshooting.md** - Problems like “Homebrew not found” or “gh not logged in” and what to do.
- **docs/faq.md** - Short answers to “What is Homebrew?”, “Why SSH?”, “Can I use this on Linux?”, etc.

---

## After Setup

- Use **Git** for your projects: `git clone`, `git add`, `git commit`, `git push`.
- Use **`gh`** to work with GitHub from the terminal: `gh repo clone`, `gh pr create`, etc.
- If you used the script’s SSH alias (e.g. `github-work`), clone with:

  ```bash
  git clone git@github-work:org/repo.git
  ```

  (Replace `github-work` with the alias the script showed you.)

---

## Need Help?

- **Something broke?** → See [docs/troubleshooting.md](docs/troubleshooting.md).
- **Curious about terms or choices?** → See [docs/faq.md](docs/faq.md).
- **Secrets and blocked commits?** → See [SECRETS.md](SECRETS.md).

This repo is meant to be a safe, public-friendly starting point-no company-specific IDs or secrets-so you can share or fork it for your team or community.
