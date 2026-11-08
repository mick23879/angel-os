# Angel OS live : démarre le bureau Hyprland sur le premier écran
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  export XDG_RUNTIME_DIR="/run/user/0"
  mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
  export XDG_SESSION_TYPE=wayland
  export LIBVA_DRIVER_NAME=iHD
  exec Hyprland
fi
