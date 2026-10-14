# shellcheck shell=bash
#
# Machine-specific bashrc for WSL. Link it by hand:
#   ln -sfn "$PWD/.bashrc.local.d/wsl.bash" "$HOME/.bashrc.local"

# Open URLs from the shell in the Windows default browser.
if command -v wslview >/dev/null 2>&1; then
  export BROWSER="wslview"
fi

alias clip='/mnt/c/Windows/System32/clip.exe'
