hyprctl keyword windowrule "workspace special silent, chat"
hyprctl dispatch exec alacritty

hyprctl keyword windowrule "workspace unset, chat"

hyprctl dispatch movetoworkspace special chat
hyprctl dispatch fullscreen
hyprctl dispatch togglespecialworkspace # hide it by default

