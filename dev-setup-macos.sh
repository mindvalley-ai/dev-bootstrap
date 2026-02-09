#!/usr/bin/env bash
set -euo pipefail

# Public-safe macOS dev bootstrap (URL-runnable):
# - Xcode Command Line Tools
# - Homebrew (optional install)
# - Git + GitHub CLI (gh)
# - Optional Claude Code CLI install (official installer)
# - SSH key creation + ssh-agent + ~/.ssh/config
# - Opens GitHub SSH keys page for final paste + SSO enable (if applicable)
#
# Run locally (no chmod needed):  bash dev-setup-macos.sh
# Run from URL:                  bash <(curl -fsSL https://raw.githubusercontent.com/<ORG>/<REPO>/main/dev-setup-macos.sh)

GITHUB_KEYS_URL="https://github.com/settings/keys"
BREW_INSTALL_URL="https://brew.sh"
BREW_INSTALL_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Claude Code official installer (as requested)
CLAUDE_INSTALL_CMD='curl -fsSL https://claude.ai/install.sh | bash'
CLAUDE_INFO_URL="https://claude.ai/code"

hr() { printf "\n------------------------------------------------------------\n"; }
msg() { printf "%s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }
ok() { printf "✅ %s\n" "$*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

open_url() {
  local url="$1"
  if have_cmd open; then
    open "$url"
  else
    msg "Open this URL manually: $url"
  fi
}

confirm() {
  local prompt="${1:-Continue?}"
  read -r -p "$prompt [y/N]: " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

prompt_default() {
  local prompt="$1"
  local def="$2"
  local out
  read -r -p "$prompt [$def]: " out
  echo "${out:-$def}"
}

sanitize_filename() {
  # Keep only alnum, dash, underscore
  echo "$1" | tr -cd '[:alnum:]_-'
}

pause_until_ready() {
  msg ""
  msg "------------------------------------------------------------"
  msg "PAUSE: $1"
  msg "------------------------------------------------------------"
  read -r -p "Press Enter when you're ready to continue... " _
}

# Safety: this script is intended for macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "This script is intended for macOS (Darwin). Detected: $(uname -s)"
  msg "It may still work partially on Linux, but Homebrew paths and clipboard may differ."
fi

hr
msg "macOS Dev Setup (public-safe)"
msg "This script does NOT include any company/org-specific identifiers."
msg "It can install: Xcode CLT, Homebrew, git, gh, optional Claude CLI, and set up a GitHub SSH key."
hr

# --------------------
# Inputs (no domains baked in)
# --------------------
DEFAULT_EMAIL="your.email@example.com"
EMAIL="$(prompt_default "Enter the email to use as the SSH key comment" "$DEFAULT_EMAIL")"

DEFAULT_LABEL="work"
LABEL_RAW="$(prompt_default "Optional label for the SSH key filename (e.g., work, company, github)" "$DEFAULT_LABEL")"
LABEL="$(sanitize_filename "$LABEL_RAW")"
[[ -z "$LABEL" ]] && LABEL="work"

KEY_NAME_DEFAULT="id_rsa_${LABEL}"
KEY_NAME_RAW="$(prompt_default "SSH key filename under ~/.ssh/ (without .pub)" "$KEY_NAME_DEFAULT")"
KEY_NAME="$(sanitize_filename "$KEY_NAME_RAW")"
[[ -z "$KEY_NAME" ]] && KEY_NAME="$KEY_NAME_DEFAULT"

KEY_TITLE_DEFAULT="$(hostname)-ssh-${LABEL}"
KEY_TITLE="$(prompt_default "Suggested key title (shown in GitHub UI / gh)" "$KEY_TITLE_DEFAULT")"

hr

# --------------------
# Step 0: Xcode Command Line Tools
# --------------------
msg "Step 0) Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode Command Line Tools already installed."
else
  warn "Xcode Command Line Tools not found."
  msg "macOS will prompt you to install them now..."
  xcode-select --install || true
  pause_until_ready "Finish installing Xcode Command Line Tools. Then re-run this script if needed."
fi

# --------------------
# Step 1: Homebrew
# --------------------
hr
msg "Step 1) Homebrew"

if have_cmd brew; then
  ok "Homebrew found: $(brew --version | head -n 1)"
else
  warn "Homebrew is not installed."
  msg "Homebrew is used to install GitHub CLI and other tools."
  msg "Homebrew: $BREW_INSTALL_URL"
  msg "Official install command:"
  msg "  $BREW_INSTALL_CMD"
  msg ""
  if confirm "Install Homebrew now?"; then
    eval "$BREW_INSTALL_CMD"

    # Ensure brew is on PATH (Apple Silicon / Intel)
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    if have_cmd brew; then
      ok "Homebrew installed."
    else
      warn "Homebrew install attempted but 'brew' still not found."
      msg "Open a NEW Terminal and run this script again."
      exit 1
    fi
  else
    warn "Skipping Homebrew install. Exiting because dependencies can't be installed."
    exit 1
  fi
fi

msg "Updating Homebrew..."
brew update >/dev/null 2>&1 || true

# --------------------
# Step 2: Install git + gh
# --------------------
hr
msg "Step 2) Install core tools"

ensure_brew_pkg() {
  local pkg="$1"
  local display="${2:-$1}"
  if brew list "$pkg" >/dev/null 2>&1; then
    ok "$display already installed."
  else
    msg "Installing $display..."
    brew install "$pkg"
    ok "$display installed."
  fi
}

ensure_brew_pkg "git" "Git"
ensure_brew_pkg "gh" "GitHub CLI (gh)"

# --------------------
# Step 3: gh auth
# --------------------
hr
msg "Step 3) GitHub CLI authentication"

if gh auth status >/dev/null 2>&1; then
  ok "gh is already authenticated."
else
  warn "gh is not authenticated."
  msg "You'll be guided through login (browser/device flow)."
  if confirm "Run 'gh auth login' now?"; then
    gh auth login
  else
    warn "Skipping gh login. You can run later: gh auth login"
  fi
fi

# --------------------
# Step 4: Claude Code CLI (optional install)
# --------------------
hr
msg "Step 4) Claude Code CLI (optional)"

if have_cmd claude; then
  ok "Found 'claude' command."
else
  warn "No 'claude' command found."
  msg "Claude Code info: $CLAUDE_INFO_URL"
  msg "Official installer command:"
  msg "  $CLAUDE_INSTALL_CMD"
  msg ""
  if confirm "Install Claude Code CLI now?"; then
    # Transparent: run exactly what we printed
    bash -lc "$CLAUDE_INSTALL_CMD" || warn "Claude installer returned non-zero exit code."
    if have_cmd claude; then
      ok "Claude CLI installed: $(claude --version 2>/dev/null || echo 'version unknown')"
    else
      warn "Claude CLI still not found. You may need to restart Terminal or follow instructions at:"
      msg "  $CLAUDE_INFO_URL"
      open_url "$CLAUDE_INFO_URL"
    fi
  else
    warn "Skipping Claude Code installation."
    msg "You can install later with:"
    msg "  $CLAUDE_INSTALL_CMD"
  fi
fi

# --------------------
# Step 5: SSH key setup
# --------------------
hr
msg "Step 5) GitHub SSH key setup"

SSH_DIR="$HOME/.ssh"
PRIV_KEY="$SSH_DIR/$KEY_NAME"
PUB_KEY="$PRIV_KEY.pub"
SSH_CONFIG="$SSH_DIR/config"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$PRIV_KEY" || -f "$PUB_KEY" ]]; then
  ok "SSH key already exists: $PRIV_KEY"
else
  msg "Generating SSH key at:"
  msg "  $PRIV_KEY"
  msg "Comment:"
  msg "  $EMAIL"
  msg ""
  msg "You may be prompted for a passphrase (recommended)."
  ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$PRIV_KEY"
  ok "SSH key generated."
fi

chmod 600 "$PRIV_KEY" || true
chmod 644 "$PUB_KEY" || true

msg "Starting ssh-agent and adding the key..."
eval "$(ssh-agent -s)" >/dev/null

if ssh-add --help 2>&1 | grep -q -- "--apple-use-keychain"; then
  ssh-add --apple-use-keychain "$PRIV_KEY"
else
  ssh-add "$PRIV_KEY"
fi
ok "Key added to ssh-agent."

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Add a generic github.com host entry if missing (no org names)
if ! grep -qE '^\s*Host\s+github\.com\s*$' "$SSH_CONFIG"; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $PRIV_KEY
  IdentitiesOnly yes
EOF
  ok "Added github.com entry to ~/.ssh/config"
else
  msg "ℹ️ ~/.ssh/config already contains a github.com entry (not modifying)."
fi

# Copy pubkey to clipboard
msg "Copying public key to clipboard..."
if have_cmd pbcopy; then
  pbcopy < "$PUB_KEY"
  ok "Public key copied. (Ready to paste in GitHub.)"
else
  warn "pbcopy not found. Public key is at: $PUB_KEY"
fi

# --------------------
# Step 6: Add key to GitHub (UI + optional gh) + PAUSE if not uploaded
# --------------------
hr
msg "Step 6) Add the key to GitHub"
msg "Opening: $GITHUB_KEYS_URL"
open_url "$GITHUB_KEYS_URL"

msg ""
msg "In the browser:"
msg "1) Click 'New SSH key'"
msg "2) Title: $KEY_TITLE"
msg "3) Paste the key (already copied) -> Add SSH key"
msg "4) If you see 'Enable SSO', click it and authorize (if applicable)."
msg ""

KEY_ADDED_VIA_GH="no"

if gh auth status >/dev/null 2>&1; then
  if confirm "Optional: upload the key automatically via 'gh' now?"; then
    if gh ssh-key add "$PUB_KEY" --title "$KEY_TITLE"; then
      ok "Key uploaded via gh."
      KEY_ADDED_VIA_GH="yes"
      msg "If SSO is required, you may still need to click 'Enable SSO' on the keys page."
    else
      warn "Could not upload via gh (maybe already exists). You'll confirm in the browser."
      KEY_ADDED_VIA_GH="no"
    fi
  fi
else
  msg "ℹ️ gh is not authenticated; you'll add the key in the browser."
fi

if [[ "$KEY_ADDED_VIA_GH" != "yes" ]]; then
  pause_until_ready "Finish adding the SSH key in the browser and enable SSO if shown."
fi

# --------------------
# Step 7: Test SSH
# --------------------
hr
msg "Step 7) Test SSH connectivity to GitHub"
msg "Running: ssh -T git@github.com"
ssh -T git@github.com || true

hr
ok "Done."
msg "Tip: If a repo was cloned via HTTPS, you can switch it to SSH:"
msg "  git remote set-url origin git@github.com:<owner>/<repo>.git"
hr
