hyprctl keyword windowrule "workspace special silent, alacritty"
hyprctl dispatch exec alacritty

sleep 3
hyprctl keyword windowrule "workspace unset, alacritty"

hyprctl dispatch movetoworkspace special alacritty
