#!/usr/bin/env bash
set -euo pipefail

# Public-safe macOS dev bootstrap (URL-runnable):
# - Xcode Command Line Tools
# - Homebrew (optional install)
# - Git + GitHub CLI (gh)
# - Optional Claude Code CLI install (official installer)
# - SSH key creation + ssh-agent + ~/.ssh/config (NON-DESTRUCTIVE: does NOT override your default github.com key)
# - Opens GitHub SSH keys page for final paste + SSO enable (if applicable)
#
# Run locally (no chmod needed):  bash dev-setup-macos.sh

GITHUB_KEYS_URL="https://github.com/settings/keys"
BREW_INSTALL_URL="https://brew.sh"
BREW_INSTALL_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Claude Code official installer (as requested)
CLAUDE_INSTALL_CMD='curl -fsSL https://claude.ai/install.sh | bash'
CLAUDE_INFO_URL="https://claude.ai/code"

hr() { printf "\n------------------------------------------------------------\n"; }
msg() { printf "%s\n" "$*"; }
warn() { printf "%s\n" "$*"; }
ok() { printf "%s\n" "$*"; }

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

ensure_local_bin_on_path() {
  local local_bin="$HOME/.local/bin"

  # Already in PATH for this session?
  if [[ ":$PATH:" == *":$local_bin:"* ]]; then
    return
  fi

  # Pick the right rc file based on the current login shell
  local shell_name rc_file
  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
    zsh)
      rc_file="$HOME/.zshrc"
      ;;
    bash)
      # macOS bash login shells commonly read .bash_profile
      if [[ -f "$HOME/.bash_profile" ]]; then
        rc_file="$HOME/.bash_profile"
      else
        rc_file="$HOME/.bashrc"
      fi
      ;;
    *)
      rc_file="$HOME/.profile"
      ;;
  esac

  # Avoid duplicates if already present
  if [[ -f "$rc_file" ]] && grep -q 'HOME/.local/bin' "$rc_file"; then
    export PATH="$local_bin:$PATH"
    return
  fi

  {
    echo ""
    echo "# Added by dev bootstrap script (Claude CLI)"
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$rc_file"

  export PATH="$local_bin:$PATH"
  ok "Added ~/.local/bin to PATH via $(basename "$rc_file")"
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
msg ""
msg "Important: This script will NOT override your default GitHub SSH key."
msg "It adds a separate SSH host alias you can use for the new key."
hr

# --------------------
# Inputs (no domains baked in)
# --------------------
DEFAULT_EMAIL="your.email@example.com"
EMAIL="$(prompt_default "Enter the email to use as the SSH key comment" "$DEFAULT_EMAIL")"

DEFAULT_LABEL="work"
LABEL_RAW="$(prompt_default "Optional label for this setup (used to name the SSH alias/key) e.g., work, company" "$DEFAULT_LABEL")"
LABEL="$(sanitize_filename "$LABEL_RAW")"
[[ -z "$LABEL" ]] && LABEL="work"

KEY_NAME_DEFAULT="id_rsa_${LABEL}"
KEY_NAME_RAW="$(prompt_default "SSH key filename under ~/.ssh/ (without .pub)" "$KEY_NAME_DEFAULT")"
KEY_NAME="$(sanitize_filename "$KEY_NAME_RAW")"
[[ -z "$KEY_NAME" ]] && KEY_NAME="$KEY_NAME_DEFAULT"

KEY_TITLE_DEFAULT="$(hostname)-ssh-${LABEL}"
KEY_TITLE="$(prompt_default "Suggested key title (shown in GitHub UI / gh)" "$KEY_TITLE_DEFAULT")"

# Non-destructive SSH alias (keeps github.com using your existing default key)
SSH_ALIAS="github-${LABEL}"

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
ensure_brew_pkg "gitleaks" "Gitleaks (secret scanner)"


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

    # Claude commonly installs to ~/.local/bin; ensure it is on PATH
    ensure_local_bin_on_path

    if have_cmd claude; then
      ok "Claude CLI available: $(claude --version 2>/dev/null || echo installed)"
    else
      warn "Claude CLI still not found on PATH."
      msg "Check if it exists here:"
      msg "  ls -l ~/.local/bin/claude"
      msg "If it exists, open a NEW Terminal (or run: source ~/.zshrc or ~/.bash_profile)."
      msg "More info: $CLAUDE_INFO_URL"
      open_url "$CLAUDE_INFO_URL"
    fi
  else
    warn "Skipping Claude Code installation."
    msg "You can install later with:"
    msg "  $CLAUDE_INSTALL_CMD"
  fi
fi

# --------------------
# Step 4.5: Global Git Pre-Commit Hook (Gitleaks)
# --------------------
hr
msg "Step 4.5) Global Git secret scanning (pre-commit hook)"

GIT_HOOKS_DIR="$HOME/.git-hooks"
PRE_COMMIT_HOOK="$GIT_HOOKS_DIR/pre-commit"

mkdir -p "$GIT_HOOKS_DIR"

# Configure git to use global hooks
git config --global core.hooksPath "$GIT_HOOKS_DIR"

# Create global pre-commit hook
cat > "$PRE_COMMIT_HOOK" <<'EOF'
#!/usr/bin/env bash

# Global pre-commit hook: Gitleaks scan

echo "Running global secret scan (gitleaks)..."

# Skip during merges
if [ -f .git/MERGE_HEAD ]; then
  exit 0
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks not found. Skipping secret scan."
  exit 0
fi

# Scan staged changes
gitleaks protect --staged --verbose --no-banner
STATUS=$?

if [ $STATUS -ne 0 ]; then
  echo ""
  echo "Possible secret detected."
  echo "Please remove secrets before committing."
  echo "Docs: https://github.com/mindvalley-ai/ai-dev-bootstrap/blob/main/SECRETS.md"
  echo ""
  exit 1
fi

echo "Secret scan passed."
exit 0
EOF

chmod +x "$PRE_COMMIT_HOOK"

ok "Global pre-commit hook installed at: $PRE_COMMIT_HOOK"
ok "Git configured to use: $GIT_HOOKS_DIR"


# --------------------
# Step 5: SSH key setup (non-destructive)
# --------------------
hr
msg "Step 5) GitHub SSH key setup (non-destructive)"

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

# Add an alias host entry (DO NOT change existing github.com behavior)
# Example: Host github-work -> uses the new key; github.com remains default.
if ! grep -qE "^\s*Host\s+${SSH_ALIAS}\s*$" "$SSH_CONFIG"; then
  cat >> "$SSH_CONFIG" <<EOF

Host ${SSH_ALIAS}
  HostName github.com
  User git
  IdentityFile ${PRIV_KEY}
  IdentitiesOnly yes
EOF
  ok "Added SSH alias '${SSH_ALIAS}' to ~/.ssh/config (default github.com unchanged)"
else
  msg "ℹ️ ~/.ssh/config already contains Host ${SSH_ALIAS} (not modifying)."
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
# Step 7: Test SSH (tests the NEW key via alias; does not affect your default)
# --------------------
hr
msg "Step 7) Test SSH connectivity to GitHub using the NEW key via alias"
msg "Running: ssh -T git@${SSH_ALIAS}"
ssh -T "git@${SSH_ALIAS}" || true

hr
ok "Done."

msg ""
msg "How to use the new key without changing your default:"
msg "  - Clone with:   git clone git@${SSH_ALIAS}:<owner>/<repo>.git"
msg "  - Or set remote: git remote set-url origin git@${SSH_ALIAS}:<owner>/<repo>.git"
msg ""
msg "Your existing default GitHub setup remains on:"
msg "  - git@github.com:<owner>/<repo>.git"
hr
