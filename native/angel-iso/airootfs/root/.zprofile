# Angel OS live : démarre le bureau Angel sur le premier écran (tty1)
# (au cas où le shell de connexion serait zsh)
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  angel-session
fi
