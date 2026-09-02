# dotfiles

My macOS bootstrap and dotfiles. Managed with [chezmoi](https://www.chezmoi.io/).

## Install

One command on a fresh Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/bryanberger/dotfiles/main/install.sh | sh
```

It installs Xcode Command Line Tools, Homebrew and chezmoi, then runs `chezmoi init --apply`, which clones this repo to `~/.local/share/chezmoi` and applies it. Three prompts:

| Prompt | Values | Effect |
|---|---|---|
| `profile` | `personal` / `work` | Which packages install and whether personal-only macOS defaults apply |
| `email` | any | Git identity for this machine. Never committed |
| `runtimes` | `mise` / `none` | `mise` installs node, pnpm, python, bun, go. `none` leaves runtimes alone: pick it when the company already manages them with its own tool (fnm, volta, asdf, Nix, an internal toolchain) so the two don't fight over PATH |

To skip the prompts, set `PROFILE`, `GIT_EMAIL` and `RUNTIMES` as environment variables on that same command. install.sh passes them to `chezmoi init`; anything left unset is prompted for.

```sh
curl -fsSL https://raw.githubusercontent.com/bryanberger/dotfiles/main/install.sh | PROFILE=work GIT_EMAIL=you@employer.com RUNTIMES=none sh
```

To keep the repo somewhere visible instead of `~/.local/share/chezmoi`, clone it first and run `sh <clone>/install.sh`; that clone becomes the source dir. The script is idempotent, so re-run it any time.

Afterwards, by hand: sign in to 1Password and enable Settings → Developer → CLI integration, sign in to the App Store, log out and back in for the macOS defaults. Apps not on Homebrew are listed at the bottom of `packages.yaml`.

## What's where

| Path | What |
|---|---|
| `.chezmoidata/packages.yaml` | Homebrew formulae and casks, split into `common`, `personal`, `work` |
| `.chezmoiscripts/` | Bootstrap scripts: `10` brew bundle, `20` mise, `30` macOS defaults. Each re-runs only when its rendered content changes |
| `.chezmoi.toml.tmpl` | The three prompts. Answers land in `~/.config/chezmoi/chezmoi.toml` |
| `.chezmoitemplates/` | Guards that abort `apply` if `profile`, `email` or `runtimes` is missing or misspelled |
| `dot_zshrc.tmpl`, `dot_zprofile`, `dot_gitconfig.tmpl`, `dot_gitignore` | Shell and git. `.tmpl` files branch on the prompt answers |
| `dot_config/ghostty/`, `dot_config/starship.toml` | Terminal and prompt |
| `dot_config/nvim/` | Neovim. [kickstart-modular](https://github.com/dam9000/kickstart-modular.nvim) base with the tutorial scaffolding removed; my additions live in `lua/custom/plugins/`, one file each |
| `dot_config/mise/config.toml` | Global runtime versions. Only deployed when `runtimes = mise` |
| `install.sh` | Fresh-Mac entry point |
| `scripts/check.sh` | Renders every profile × runtimes combination into a temp dir and checks the guards. CI runs it |

Naming: `dot_foo` → `~/.foo`, `.tmpl` → rendered as a Go template, `.chezmoiignore` keeps repo-only files out of `~`.

## Daily use

```sh
chezmoi edit ~/.zshrc     # edit the source copy
chezmoi diff              # what apply would change
chezmoi apply             # source → ~
chezmoi add ~/.config/x   # start managing a file
chezmoi re-add            # pull a file I edited in ~ back into the repo
chezmoi update            # on another machine: git pull + apply
chezmoi cd                # shell in the source dir
```

Commit and push with plain git. Run `sh scripts/check.sh` before pushing.

## Changing things

- **Software:** add a line to `packages.yaml` under `common`, `personal` or `work`, then `chezmoi apply`. Removing a line does not uninstall; use `brew uninstall`.
- **Runtimes:** `mise use -g node@22` edits `~/.config/mise/config.toml`; `chezmoi re-add` brings it into the repo. On a machine with `runtimes = none` nothing here applies; use whatever the company provides.
- **macOS defaults:** change it in System Settings, find the key with `defaults read <domain>`, add the line to `30-macos-defaults`. Some domains silently no-op on recent macOS; verify with `defaults read` after applying.
- **A prompt answer:** edit `~/.config/chezmoi/chezmoi.toml`, or re-run `chezmoi init` (each prompt defaults to the current value), then `chezmoi apply`.
- **Machine-specific config:** `~/.zshrc.local` is sourced at the end of `.zshrc`, and `~/.gitconfig.local` is included at the end of `.gitconfig`, if they exist. Never committed. On a work Mac, move anything company tooling writes into `.gitconfig` or `.zshrc` there before running `chezmoi apply`, or apply will remove it.

## Rules

- **The shell config is a baseline, not a mirror of any machine.** It only references tools `packages.yaml` installs.
- **Nothing personal is committed.** No email, no secrets. `check.sh` greps for an email address.
- **Work laptops never get personal software or settings.** A missing or misspelled `profile` aborts rather than falling back to a default.
- **Company-managed apps stay out of `packages.yaml`.** If Munki (Managed Software Center) installs Slack, Docker or Zoom, Homebrew must not also manage them. The `work` section is only for tools the company doesn't provide.
- **Removed files linger.** chezmoi stops managing a deleted file but does not remove it from `~`. Clean up by hand on existing machines.

## Work machines

- Munki (Managed Software Center) owns Slack, Docker, Zoom and the like. They stay out of `packages.yaml`. Check `/Library/Managed Installs/ManagedInstallReport.plist` to see what it manages before adding anything to the `work` section.
- Company tooling that writes to `.gitconfig` or `.zshrc` gets wiped by the next `chezmoi apply`. Move those lines to `~/.gitconfig.local` or `~/.zshrc.local` once; chezmoi never touches those. `chezmoi diff` shows what apply would remove.
- If a company tool keeps rewriting `~/.gitconfig` on a schedule, stop managing it there: move the template to `dot_config/git/config` (git reads `~/.config/git/config` first, then `~/.gitconfig`, so the company file still wins where they overlap).

## Ejecting

chezmoi is a build step, not a runtime. Deployed files are plain copies, not symlinks. To detach a machine, stop running `chezmoi apply`; nothing else changes. To remove it fully, `chezmoi purge` deletes its config, state and source dir and leaves `~` untouched, then `brew uninstall chezmoi`. Homebrew packages, macOS defaults and mise stay; they are not chezmoi.

## Testing

`scripts/check.sh` renders everything without touching the machine. For a real end-to-end run use a throwaway macOS VM; never test the bootstrap on a machine you care about.

## Backlog

**1Password secrets.** Items named `<Service> API Key` in the `Private` vault, a `private_dot_config/zsh/private_env.zsh.tmpl` rendering `export` lines via `onepasswordRead`, guarded with `lookPath "op"`, sourced from `.zshrc`.
