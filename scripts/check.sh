#!/bin/sh
# Render every template for every profile/runtimes combination against a
# throwaway destination, without touching this machine. Catches a broken
# template, a missing guard, or a bad packages.yaml edit before it reaches a
# real `chezmoi apply`. Run locally with `sh scripts/check.sh`; CI runs the same.
#
# Requires chezmoi. Uses shellcheck if present.
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0

for profile in personal work; do
	for runtimes in mise none; do
		home="$TMP/$profile-$runtimes/home"
		cfg="$TMP/$profile-$runtimes/chezmoi.toml"
		mkdir -p "$home"
		printf '==> profile=%s runtimes=%s\n' "$profile" "$runtimes"

		chezmoi init --source "$REPO" --config "$cfg" --destination "$home" \
			--promptString "profile=$profile" \
			--promptString "email=check@example.invalid" \
			--promptChoice "runtimes=$runtimes"

		# --dry-run renders everything (scripts included) and runs nothing.
		out="$TMP/$profile-$runtimes/apply.diff"
		chezmoi apply --source "$REPO" --config "$cfg" --destination "$home" \
			--dry-run --verbose >"$out"

		# The guards must have resolved: nothing rendered may still carry a
		# placeholder, and the profile must be the one we asked for.
		if ! grep -q "profile: $profile" "$out"; then
			echo "   FAIL: brew script did not render for profile=$profile" >&2; fail=1
		fi
		if [ "$runtimes" = mise ] && ! grep -q 'mise activate zsh' "$out"; then
			echo "   FAIL: .zshrc does not activate mise" >&2; fail=1
		fi
		if [ "$runtimes" = none ] && grep -q 'mise activate zsh' "$out"; then
			echo "   FAIL: .zshrc activates mise with runtimes=none" >&2; fail=1
		fi
		if [ "$runtimes" = none ] && grep -q '\.config/mise' "$out"; then
			echo "   FAIL: ~/.config/mise deployed with runtimes=none" >&2; fail=1
		fi
		if grep -q 'email = check@example.invalid' "$out"; then
			echo "   ok: gitconfig email rendered from prompt"
		else
			echo "   FAIL: gitconfig email not rendered" >&2; fail=1
		fi
		if [ "$profile" = work ] && grep -q 'Screenshots' "$out"; then
			echo "   FAIL: personal-only macOS defaults rendered for work" >&2; fail=1
		fi

		# A misspelled profile must abort, not fall through to a default.
		if chezmoi init --source "$REPO" --config "$TMP/bad.toml" --destination "$home" \
			--promptString profile=wrok --promptString email=x@example.invalid \
			--promptChoice "runtimes=$runtimes" 2>/dev/null; then
			echo "   FAIL: profile=wrok was accepted" >&2; fail=1
		else
			echo "   ok: bad profile rejected"
		fi
	done
done

# Rendered shell scripts must not contain a committed address.
if grep -rn --exclude-dir=.git --exclude-dir=nvim -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' "$REPO" \
	| grep -vE 'example\.(com|invalid)|employer\.com|you@|op-kitt|git@github|chezmoi\.io|@\{|\$\{' ; then
	echo "FAIL: an email-looking string is committed (see above)" >&2; fail=1
fi

if command -v shellcheck >/dev/null 2>&1; then
	echo "==> shellcheck"
	shellcheck -s sh "$REPO/install.sh" "$REPO/scripts/check.sh"
	for combo in personal-mise work-none; do
		# Rendered scripts live in the dry-run diff; extract and lint them.
		awk '/^\+\+\+ b\/\.chezmoiscripts\//{f=1;next} f&&/^\+/{print substr($0,2)} f&&/^diff --git/{f=0}' \
			"$TMP/$combo/apply.diff" > "$TMP/$combo.rendered.sh"
		shellcheck -s bash "$TMP/$combo.rendered.sh" || fail=1
	done
else
	echo "==> shellcheck not installed; skipping (brew install shellcheck)"
fi

if [ "$fail" -ne 0 ]; then
	echo "FAILED" >&2
	exit 1
fi
echo "==> all checks passed"
