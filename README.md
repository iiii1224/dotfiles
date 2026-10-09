# dotfiles

This is a personal dotfiles repository. `init.sh` links each managed config file into `$HOME` and sets up the required development tools.

If `init.sh` finds an unmanaged file where a symlink should go, it leaves that file alone, lists every skipped path at the end, and exits non-zero. Move or remove the listed paths and run it again.

## Optional OS Packages

Every tool in `.config/mise/global-config.toml` is installed by mise. Some commands used by the fzf preview and Neovim image rendering are not available through mise and must come from the OS package manager instead:

- `file` — detects whether the previewed path is an image
- `chafa` — renders that image in the terminal
- `imagemagick` — converts and scales images for `image.nvim`

The preview degrades gracefully when `file` or `chafa` is missing (`chafa` → `bat` → `head`), but ImageMagick is required by `image.nvim`. On Debian and Ubuntu:

```bash
sudo apt-get install file chafa imagemagick
```

## tmux

This repository uses [Oh my tmux!](https://github.com/gpakosz/.tmux) as a git submodule at `.tmux`.

- `$HOME/.tmux.conf` is linked to `.tmux/.tmux.conf`.
- `$HOME/.tmux.conf.local` is linked to `.tmux.conf.local`.
- Existing `$HOME/.tmux.conf` and `$HOME/.tmux.conf.local` files are moved to `.backup` with timestamped names before replacement.
- If `$HOME/.tmux.conf` is already an Oh my tmux! `.tmux/.tmux.conf` symlink, it is replaced without backup.

After cloning this repository, initialize the submodule before running `init.sh`:

```bash
git submodule update --init --recursive
```

## Rio

The [Rio](https://rioterm.com/) configuration is not linked by `init.sh`, because on WSL Rio runs on the Windows side and cannot follow a symlink into the WSL filesystem. `.config/rio/config.d` holds one complete config per environment; place the matching one by hand.

On a native Linux machine, link it:

```bash
ln -sfn "$PWD/.config/rio/config.d/linux.toml" "$HOME/.config/rio/config.toml"
```

On WSL, copy it to the Windows config path instead:

```bash
cp .config/rio/config.d/wsl.toml \
   "$(wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")/rio/config.toml"
```

The two files differ in exactly two places, and are otherwise identical — keep them in sync when you change a binding.

- `[shell]`, which only the WSL variant sets, so Rio starts `wsl.exe` in the home directory.
- `[fonts]`, where `symbol-map` assigns the Japanese Unicode ranges to a font that ships with the platform: BIZ UDGothic on Windows, Noto Sans Mono CJK JP on Linux. ASCII keeps Rio's bundled Cascadia Code in both. The ranges stop short of U+2000-U+2E7F on purpose: those characters are East Asian Ambiguous width, and rendering them full-width breaks tmux pane borders and the Neovim UI.

## Trying It with Docker

You can test `init.sh` in a fresh environment on Docker. This is useful when you want to verify the setup without modifying your host `$HOME`.

### Prerequisites

- Docker Engine and `docker compose` must be available

### Start the Container

Run the following from the repository root:

```bash
docker compose run --rm ubuntu
```

The first run may take a little time because the container installs required packages with `apt-get`.

### What the Container Does

- Uses `ubuntu:26.04` as the base image
- Mounts the repository at `/repo` as read-only
- Creates a writable working copy at `/workspace/dotfiles`
- Starts the shell in `/workspace/dotfiles`

After startup, you can try:

```bash
git submodule update --init --recursive
./init.sh
source ~/.bashrc
mise doctor
```

If you only want to verify symlink creation, run:

```bash
./init.sh --links-only
```

If you update `.config/mise/global-config.toml` and only want to re-apply the mise configuration, run:

```bash
./sync-mise.sh
```

## Existing Files

All three scripts share one policy, implemented in `script/lib.sh`: a file that is already sitting where a symlink should go is never touched. The path is reported, and the script exits non-zero so the incomplete setup is visible.

Pass `--force` to `init.sh` or `sync-mise.sh` to move those files into `.backup/` with a timestamped name and link over them instead.

```bash
./init.sh --force
```

The one exception is `$HOME/.tmux.conf`: when it already points at some other Oh my tmux! checkout it is a copy of the same upstream file, so it is replaced without a backup.

## Updating

```bash
./update.sh
```

`update.sh` re-syncs the mise config, updates mise itself, upgrades tools, reports unused tool versions, and checks whether the Oh my tmux! submodule has upstream changes.

Because every tool is pinned to an exact version, a plain run cannot move any version. Use the flags for that:

| Flag | Effect |
| --- | --- |
| `--bump` | Upgrade to the latest versions and rewrite the pins in `.config/mise/global-config.toml`, so the change becomes a reviewable diff to commit |
| `--prune` | Delete installed tool versions no config references any more (they are only listed otherwise) |

The submodule is never moved automatically: `.tmux.conf.local` is a fork of the upstream template, so check what changed upstream before running `git submodule update --remote .tmux`.

## Neovim

The repository includes a small Neovim configuration managed by lazy.nvim. It is linked to `$HOME/.config/nvim/init.lua` by `init.sh`, and Neovim is installed by mise.

`image.nvim` renders images in Markdown and other supported buffers through the Kitty graphics protocol. Use Kitty, or a compatible terminal such as Herdr, and keep tmux at version 3.3 or newer. The tmux configuration enables the passthrough settings required for image rendering.

After setup, start it with:

```bash
./init.sh
source ~/.bashrc
nvim
```

The space key is the leader key: `Space w` saves, `Space q` quits, and `Space e` opens the file explorer. Use `i` to insert text and `Esc` to return to normal mode. On WSL, `Ctrl-j` also returns to normal mode even when Windows IME is holding ordinary letters for composition. Use `:Tutor` for the built-in tutorial. `Ctrl-h/j/k/l` moves between split windows in normal mode.

Python, Rust, Markdown, and C/C++ language servers are managed by mise with exact version pins: Pyright, rust-analyzer, Marksman, and clangd. clangd needs a `compile_commands.json` (or `compile_flags.txt`) in the project to resolve include paths; generate it with CMake's `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` or Bear. Running `./init.sh` installs them along with the other tools. Neovim uses blink.cmp for LSP, snippet, buffer, and filesystem path completion. `<Enter>` accepts a completion, `<C-space>` opens the menu, `<C-n>` / `<C-p>` navigate candidates, and `<Tab>` / `<S-Tab>` move through snippet placeholders.

On WSL, `init.sh` also cross-builds a small Windows IME helper from
`script/ime-off` and installs it as `~/.local/bin/ime-off.exe`. Neovim invokes
it asynchronously whenever it enters normal mode, returning Microsoft IME to
direct (half-width alphanumeric) input. The integration is skipped on native
Linux and when the helper is not present.

When an LSP is attached, `gd` jumps to a definition, `K` shows documentation, `Space rn` renames a symbol, and `Space ca` opens code actions. Use `:checkhealth vim.lsp` or `:LspInfo` when diagnosing a server that does not attach.

Run `exit` when you are done. Because the command uses `--rm`, the container is removed automatically after it exits.
