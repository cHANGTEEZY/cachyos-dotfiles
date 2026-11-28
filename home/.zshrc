# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Cursor agent and other user binaries live here.
# Alacritty starts a login zsh, which resets PATH via /etc/profile.
export PATH="$HOME/.local/bin:$PATH"

# Android SDK (Linux path; Cursor Emulator extension uses this too)
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# JDK 17 for Expo / Android Gradle
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export PATH="$JAVA_HOME/bin:$PATH"

# Don't "correct" the expo CLI argument to the local .expo directory
export CORRECT_IGNORE_FILE='.expo'

export EDITOR=nvim
export VISUAL=nvim

# Avante zen mode: Cursor-like agent CLI inside Neovim
alias avante='nvim -c "lua vim.defer_fn(function() require(\"avante.api\").zen_mode() end, 100)"'

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Go toolchain. User tools from `go install` live in ~/go/bin.
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Distro Node, npm, pnpm, tsc, eslint, and prettier are in /usr/bin.
# Cursor's agent directory also ships a `node` binary; keep that directory
# on PATH for the agent, but resolve `node` to the system one.
if [[ "$PATH" == *cursor-agent/versions* && -x /usr/bin/node ]]; then
  _path_front=()
  _path_agent=()
  for _path_entry in ${(s/:/)PATH}; do
    case "$_path_entry" in
      /usr/bin) ;;
      *cursor-agent/versions*) _path_agent+=("$_path_entry") ;;
      *) _path_front+=("$_path_entry") ;;
    esac
  done
  path=($_path_front /usr/bin $_path_agent)
  unset _path_front _path_agent _path_entry
  typeset -U path
fi
