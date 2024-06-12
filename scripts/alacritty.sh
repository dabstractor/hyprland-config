hyprctl keyword windowrule "workspace special silent, alacritty"
hyprctl dispatch exec alacritty
sleep 1
hyprctl keyword windowrule "workspace unset, alacritty"

hyprctl dispatch movetoworkspace special alacritty

hyprctl dispatch togglespecialworkspace # hide it by default

hyprctl dispatch fullscreen
