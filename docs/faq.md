# FAQ

Short answers to questions new coders often have about this setup.

---

## What is Homebrew?

**Homebrew** is a _package manager_ for macOS. It lets you install developer tools (like Git and GitHub CLI) by typing commands like `brew install git` instead of downloading installers by hand. The script offers to install it if you don’t have it; we recommend saying yes.

---

## What is the GitHub CLI (`gh`)?

**GitHub CLI** is a tool that talks to GitHub from the terminal. After you run `gh auth login`, you can do things like:

- `gh repo clone owner/repo` - clone a repo
- `gh pr create` - open a pull request
- `gh issue list` - list issues

The setup script installs it with Homebrew and then runs `gh auth login` so you’re signed in.

---

## Why SSH keys instead of passwords?

GitHub no longer accepts account passwords for Git over HTTPS for normal use. You either use:

- **SSH keys** - the script creates one and you add the _public_ key to GitHub. No password to type for every push.
- **Personal Access Token (PAT)** - you’d use this with HTTPS. Many teams prefer SSH because one key can be used for many repos and, with SSO, you can enable it per organization.

The script uses SSH so you get a single key and can turn on SSO if your org requires it.

---

## What is the “alias” (e.g. `github-work`) for?

The script creates a _separate_ SSH key and an alias (like `github-work`) so it **does not replace** your existing default key for `github.com`. So:

- `git@github.com:user/repo.git` → uses your **default** key (e.g. personal).
- `git@github-work:org/repo.git` → uses the **new** key you added (e.g. work).

That way personal and work repos can use different keys on the same Mac.

---

## Do I have to install Claude Code CLI?

No. The script asks optionally. You can skip it and install it later from [claude.ai/code](https://claude.ai/code) if you want.

---

## Can I use this on Linux or Windows?

- **macOS:** Yes - this script is for you.
- **Linux:** Not yet. The script checks for macOS. A `dev-setup-linux.sh` may be added later; until then use your distro’s package manager and GitHub’s docs for SSH/gh.
- **Windows:** No. Use [Git for Windows](https://git-scm.com/download/win), [GitHub’s SSH guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh), and optionally [gh for Windows](https://cli.github.com/).

---

## Is it safe to run a script from the internet?

You should only run scripts from sources you trust. This repo is designed to be:

- **Public and readable** - you can read `scripts/macos-setup.sh` before running.
- **No company/org secrets** - no hardcoded domains or credentials.
- **Non-destructive** - it doesn’t overwrite your default GitHub SSH key; it adds a new key and alias.

If you’re unsure, clone the repo and read the script, then run it locally with `bash scripts/macos-setup.sh`.

---

## Where do I put secrets (API keys, passwords)?

Never put them in code or in files that get committed. See **[SECRETS.md](../SECRETS.md)** for where to store them (e.g. GitHub Secrets, `.env` with `.gitignore`, secret managers) and what to do if a commit is blocked.
