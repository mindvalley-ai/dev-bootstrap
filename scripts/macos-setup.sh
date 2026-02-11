#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# macOS Developer Bootstrap
# ------------------------------------------------------------

# ANSI colors (macOS-safe)
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'
CYAN=$'\033[1;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# ------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------

hr()   { echo "------------------------------------------------------------"; }

msg()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

step() {
  echo ""
  printf "${BOLD}==> %s${NC}\n" "$*"
}

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

print_banner() {
printf "

${CYAN}============================================================${NC}
${BOLD}        macOS Developer Environment Bootstrap${NC}
${CYAN}============================================================${NC}

  * Install core development tools
  * Configure GitHub SSH (non-destructive)
  * Optional Claude CLI setup
  * Enable Git secret scanning

  ${YELLOW}[!] Safe to run - existing GitHub setup is preserved${NC}

"
}

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------

GITHUB_KEYS_URL="https://github.com/settings/keys"
BREW_INSTALL_URL="https://brew.sh"
BREW_INSTALL_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

CLAUDE_INSTALL_CMD='curl -fsSL https://claude.ai/install.sh | bash'
CLAUDE_INFO_URL="https://claude.ai/code"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

have_cmd() { command -v "$1" >/dev/null 2>&1; }

open_url() {
  local url="$1"
  if have_cmd open; then
    open "$url"
  else
    msg "Open manually: $url"
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
  echo "$1" | tr -cd '[:alnum:]_-'
}

pause_until_ready() {
  echo ""
  printf "${YELLOW}------------------------------------------------------------${NC}\n"
  printf "${YELLOW}WAIT: %s${NC}\n" "$1"
  printf "${YELLOW}------------------------------------------------------------${NC}\n"
  read -r -p "Press Enter to continue... " _
}

# ------------------------------------------------------------
# PATH helper
# ------------------------------------------------------------

ensure_local_bin_on_path() {
  local local_bin="$HOME/.local/bin"

  if [[ ":$PATH:" == *":$local_bin:"* ]]; then
    return
  fi

  local shell_name rc_file
  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
    zsh)  rc_file="$HOME/.zshrc" ;;
    bash)
      if [[ -f "$HOME/.bash_profile" ]]; then
        rc_file="$HOME/.bash_profile"
      else
        rc_file="$HOME/.bashrc"
      fi
      ;;
    *) rc_file="$HOME/.profile" ;;
  esac

  if [[ -f "$rc_file" ]] && grep -q 'HOME/.local/bin' "$rc_file"; then
    export PATH="$local_bin:$PATH"
    return
  fi

  {
    echo ""
    echo "# Added by dev bootstrap script"
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$rc_file"

  export PATH="$local_bin:$PATH"

  ok "Added ~/.local/bin to PATH via $(basename "$rc_file")"
}

# ------------------------------------------------------------
# Platform check
# ------------------------------------------------------------

if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "This script is intended for macOS. Detected: $(uname -s)"
fi

# ------------------------------------------------------------
# Intro
# ------------------------------------------------------------

print_banner
hr

# ------------------------------------------------------------
# Inputs
# ------------------------------------------------------------

DEFAULT_EMAIL="your.email@example.com"
EMAIL="$(prompt_default "SSH key email comment" "$DEFAULT_EMAIL")"

DEFAULT_LABEL="work"
LABEL_RAW="$(prompt_default "Setup label (e.g. work, company)" "$DEFAULT_LABEL")"
LABEL="$(sanitize_filename "$LABEL_RAW")"
[[ -z "$LABEL" ]] && LABEL="work"

KEY_NAME_DEFAULT="id_ed25519_${LABEL}"
KEY_NAME_RAW="$(prompt_default "SSH key filename" "$KEY_NAME_DEFAULT")"
KEY_NAME="$(sanitize_filename "$KEY_NAME_RAW")"

KEY_TITLE_DEFAULT="$(hostname)-ssh-${LABEL}"
KEY_TITLE="$(prompt_default "GitHub key title" "$KEY_TITLE_DEFAULT")"

SSH_ALIAS="github-${LABEL}"

# ------------------------------------------------------------
# Step 0: Xcode
# ------------------------------------------------------------

step "Step 0: Xcode Command Line Tools"

if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode tools already installed."
else
  warn "Xcode tools not found."
  xcode-select --install || true
  pause_until_ready "Finish installing Xcode tools."
fi

# ------------------------------------------------------------
# Step 1: Homebrew
# ------------------------------------------------------------

step "Step 1: Homebrew"

if have_cmd brew; then
  ok "Homebrew found."
else
  warn "Homebrew not installed."

  if confirm "Install Homebrew now?"; then
    eval "$BREW_INSTALL_CMD"

    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    err "Homebrew required. Exiting."
    exit 1
  fi
fi

msg "Updating Homebrew..."
brew update >/dev/null 2>&1 || true

# ------------------------------------------------------------
# Step 2: Tools
# ------------------------------------------------------------

step "Step 2: Core Tools"

ensure_brew_pkg() {
  local pkg="$1"
  local name="${2:-$1}"

  if brew list "$pkg" >/dev/null 2>&1; then
    ok "$name already installed."
  else
    msg "Installing $name..."
    brew install "$pkg"
    ok "$name installed."
  fi
}

ensure_brew_pkg git "Git"
ensure_brew_pkg gh "GitHub CLI"
ensure_brew_pkg gitleaks "Gitleaks"

# ------------------------------------------------------------
# Step 3: GitHub Auth
# ------------------------------------------------------------

step "Step 3: GitHub Authentication"

if gh auth status >/dev/null 2>&1; then
  ok "GitHub CLI authenticated."
else
  warn "GitHub CLI not authenticated."

  if confirm "Run gh auth login?"; then
    gh auth login
  fi
fi

# ------------------------------------------------------------
# Step 4: Claude
# ------------------------------------------------------------

step "Step 4: Claude CLI (Optional)"

if have_cmd claude; then
  ok "Claude CLI found."
else
  warn "Claude CLI not found."

  if confirm "Install Claude CLI?"; then
    bash -lc "$CLAUDE_INSTALL_CMD" || true
    ensure_local_bin_on_path
  fi
fi

# ------------------------------------------------------------
# Step 4.5: Gitleaks Hook
# ------------------------------------------------------------

step "Step 4.5: Global Secret Scanning"

GIT_HOOKS_DIR="$HOME/.git-hooks"
PRE_COMMIT_HOOK="$GIT_HOOKS_DIR/pre-commit"

mkdir -p "$GIT_HOOKS_DIR"
git config --global core.hooksPath "$GIT_HOOKS_DIR"

cat > "$PRE_COMMIT_HOOK" <<'EOF'
#!/usr/bin/env bash

DOCS_URL="https://github.com/mindvalley-ai/dev-bootstrap/blob/main/SECRETS.md"

if [ -f .git/MERGE_HEAD ]; then
  exit 0
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  exit 0
fi

gitleaks protect --staged --redact --no-banner
EOF

chmod +x "$PRE_COMMIT_HOOK"

ok "Pre-commit hook installed."

# ------------------------------------------------------------
# Step 5: SSH
# ------------------------------------------------------------

step "Step 5: SSH Setup"

SSH_DIR="$HOME/.ssh"
PRIV_KEY="$SSH_DIR/$KEY_NAME"
PUB_KEY="$PRIV_KEY.pub"
SSH_CONFIG="$SSH_DIR/config"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$PRIV_KEY" ]]; then
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$PRIV_KEY"
  ok "SSH key created."
else
  ok "SSH key exists."
fi

eval "$(ssh-agent -s)" >/dev/null

ssh-add "$PRIV_KEY" >/dev/null 2>&1 || true

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "Host ${SSH_ALIAS}" "$SSH_CONFIG"; then
cat >> "$SSH_CONFIG" <<EOF

Host ${SSH_ALIAS}
  HostName github.com
  User git
  IdentityFile ${PRIV_KEY}
  IdentitiesOnly yes
EOF
fi

ok "SSH alias configured."

if have_cmd pbcopy; then
  pbcopy < "$PUB_KEY"
  ok "Public key copied."
fi

# ------------------------------------------------------------
# Step 6: GitHub Key
# ------------------------------------------------------------

step "Step 6: Register SSH Key"

open_url "$GITHUB_KEYS_URL"

if confirm "Upload via github cli?"; then
  gh ssh-key add "$PUB_KEY" --title "$KEY_TITLE" || true
fi

pause_until_ready "Confirm SSH key added in GitHub."

# ------------------------------------------------------------
# Step 7: Test SSH (non-destructive)
# ------------------------------------------------------------

step "Step 7: Connectivity Test"

TROUBLESHOOTING_URL="https://github.com/mindvalley-ai/dev-bootstrap/blob/main/docs/troubleshooting.md#permission-denied-publickey-when-cloning-or-pushing"
REPO_README_URL="https://github.com/mindvalley-ai/dev-bootstrap#readme"

check_ssh() {
  ssh -T "git@${SSH_ALIAS}" 2>&1 || true
}

# First attempt
SSH_TEST_OUTPUT="$(check_ssh)"

if echo "$SSH_TEST_OUTPUT" | grep -q "successfully authenticated"; then

  ok "SSH authentication successful."

elif echo "$SSH_TEST_OUTPUT" | grep -q "Permission denied"; then

  warn "SSH authentication failed (public key not accepted)."
  msg  "This usually means the SSH key was not added to GitHub."

  msg ""
  msg "Please check:"
  msg "  1) Your public key was pasted correctly"
  msg "  2) The key exists in GitHub settings"
  msg "  3) SSO is enabled (if required)"
  msg ""

  msg "Opening GitHub SSH keys page..."
  open_url "$GITHUB_KEYS_URL"

  pause_until_ready "Fix the SSH key setup, then press Enter to retry."

  # Retry once
  SSH_RETRY_OUTPUT="$(check_ssh)"

  if echo "$SSH_RETRY_OUTPUT" | grep -q "successfully authenticated"; then

    ok "SSH authentication successful after retry."

  else

    err "SSH authentication still failing."
    msg "$SSH_RETRY_OUTPUT"
    msg ""
    msg "Opening troubleshooting guide..."

    open_url "$TROUBLESHOOTING_URL"

    err "Setup incomplete due to SSH authentication failure."
    exit 1
  fi

else

  warn "Unexpected SSH output:"
  msg "$SSH_TEST_OUTPUT"

  err "Unable to verify SSH configuration."
  exit 1

fi


# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

hr
ok "Setup complete."

msg ""
msg "Usage:"
msg "  git clone git@${SSH_ALIAS}:org/repo.git"
msg "  git remote set-url origin git@${SSH_ALIAS}:org/repo.git"
msg ""
msg "Default GitHub access remains unchanged."
hr


# ------------------------------------------------------------
# Open documentation
# ------------------------------------------------------------

msg "Setup complete. Opening documentation and guides..."
open_url "$REPO_README_URL"
