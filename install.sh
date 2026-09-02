#!/bin/sh
# Bootstrap a fresh Apple Silicon Mac: Xcode CLT -> Homebrew -> chezmoi -> dotfiles.
#
# One command on a fresh machine:
#   curl -fsSL https://raw.githubusercontent.com/bryanberger/dotfiles/main/install.sh | sh
#
# chezmoi clones the repo to its default source dir (~/.local/share/chezmoi).
# Running the script from an existing clone uses that clone instead.
#
# Everything here is idempotent — safe to re-run on a machine that is already
# partly (or fully) set up. Each step checks for what it installs and skips it.
#
# Environment overrides (all optional; chezmoi prompts for anything unset):
#   DOTFILES_REPO   git URL to clone from, when not running from a clone
#   PROFILE         "personal" or "work" — decides which apps and macOS
#                   settings apply. See .chezmoidata/packages.yaml
#   GIT_EMAIL       git identity for this machine. No address is committed to
#                   the repo, so every machine supplies its own; the value is
#                   stored only in this machine's local chezmoi config
#   RUNTIMES        "mise" to have these dotfiles install and activate mise for
#                   node/pnpm/python/bun/go, or "none" to leave runtimes alone.
#                   Use "none" when the company already manages runtimes with
#                   its own tool (fnm, volta, asdf, Nix, an internal toolchain)
#
#   curl -fsSL .../install.sh | PROFILE=work GIT_EMAIL=you@employer.com RUNTIMES=none sh
#   PROFILE=work GIT_EMAIL=you@employer.com RUNTIMES=none sh install.sh   # from a clone

set -eu

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/bryanberger/dotfiles.git}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1" >&2; }

case "$(uname -s)-$(uname -m)" in
	Darwin-arm64) ;;
	*) echo "This bootstrap is for Apple Silicon Macs only." >&2; exit 1 ;;
esac

# --- 1. Xcode Command Line Tools ---------------------------------------------
# Needed for git and for anything that compiles. The installer is a GUI dialog,
# so we trigger it and wait rather than trying to drive it headlessly.
if xcode-select -p >/dev/null 2>&1; then
	log "Xcode Command Line Tools already installed"
else
	log "Installing Xcode Command Line Tools (a dialog will appear)"
	xcode-select --install || true
	printf '    waiting for the install to finish'
	until xcode-select -p >/dev/null 2>&1; do
		printf '.'
		sleep 10
	done
	printf '\n'
fi

# --- 2. sudo ------------------------------------------------------------------
# Homebrew's installer (run non-interactively below) and some cask pkg
# installers need sudo but never prompt for it themselves. Ask once here, then
# keep the ticket alive until this script exits. sudo reads the password from
# the terminal directly, so this works under `curl | sh` too.
log "Asking for your password once; Homebrew and some installers need sudo"
if ! sudo -v; then
	echo "This account needs to be an Administrator to install Homebrew." >&2
	exit 1
fi
( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &

# --- 3. Homebrew --------------------------------------------------------------
BREW=/opt/homebrew/bin/brew
if [ -x "$BREW" ]; then
	log "Homebrew already installed"
else
	log "Installing Homebrew"
	NONINTERACTIVE=1 /bin/bash -c \
		"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$BREW" shellenv)"

# --- 4. chezmoi ---------------------------------------------------------------
if command -v chezmoi >/dev/null 2>&1; then
	log "chezmoi already installed ($(chezmoi --version | head -1))"
else
	log "Installing chezmoi"
	brew install chezmoi
fi

# --- 5. Dotfiles --------------------------------------------------------------
# Three cases, all idempotent:
#   a. chezmoi already initialized on this machine  -> chezmoi apply
#   b. this script is running from inside a clone    -> init with that clone as
#                                                       the source dir (no second
#                                                       clone; sourceDir persists
#                                                       in the generated config)
#   c. neither (curl | sh)                            -> chezmoi clones $DOTFILES_REPO
# --apply then runs the scripts (packages, mise, macOS defaults), which are
# themselves run_onchange_ guarded.

# Any of these left unset means chezmoi prompts for it interactively.
# (Written as `if` blocks, not `[ ... ] && ...` — under `set -e` a false test
# at the end of a line exits the script.)
set --
if [ -n "${PROFILE:-}" ]; then set -- "$@" --promptString "profile=$PROFILE"; fi
if [ -n "${GIT_EMAIL:-}" ]; then set -- "$@" --promptString "email=$GIT_EMAIL"; fi
if [ -n "${RUNTIMES:-}" ]; then set -- "$@" --promptChoice "runtimes=$RUNTIMES"; fi

# Resolve the directory this script lives in, if it lives anywhere (under
# `curl | sh`, $0 is "sh" and there is no clone to point at).
SCRIPT_DIR=""
case "${0:-}" in
	*/*) SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" ;;
esac

# `chezmoi source-path` prints the default path and exits 0 even on a machine
# that was never initialized, so test for the source dir itself.
if [ -f "$(chezmoi source-path 2>/dev/null)/.chezmoi.toml.tmpl" ]; then
	log "chezmoi already initialized; applying"
	chezmoi apply
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]; then
	log "Initializing dotfiles from local clone at $SCRIPT_DIR"
	chezmoi init --source "$SCRIPT_DIR" --apply "$@"
else
	log "Initializing dotfiles from $DOTFILES_REPO"
	if ! chezmoi init --apply "$@" "$DOTFILES_REPO"; then
		warn "chezmoi init failed; see the error above. Fix it and re-run this script."
		warn "If the clone was refused, the repo needs auth: 'gh auth login' or an SSH key."
		exit 1
	fi
fi

log "Done."
echo
echo "Remaining manual steps:"
echo "  - Sign in to 1Password, enable Settings > Developer > CLI integration"
echo "  - Sign in to the App Store; install Xcode if you need it"
echo "  - Log out and back in so all macOS defaults take effect"
echo "  - Non-Homebrew apps are listed at the bottom of .chezmoidata/packages.yaml"
echo "  - Machine-local shell config (employer tooling etc.) goes in ~/.zshrc.local"
