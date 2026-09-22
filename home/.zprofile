# Login shells (including Alacritty's `zsh -l`) source /etc/profile first,
# which replaces PATH and drops ~/.local/bin. Put it back.
export PATH="$HOME/.local/bin:$PATH"

# Android + JDK must be set here too: login shells can run Gradle before ~/.zshrc.
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
