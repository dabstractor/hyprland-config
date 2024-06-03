
hyprctl keyword windowrule "workspace special silent, alacritty"
hyprctl dispatch exec alacritty

sleep 3
hyprctl keyword windowrule "workspace unset, alacritty"

# Set the wallpaper image
swaybg -i ~/Pictures/wallpapers/pexels-rejilal-ravi-118052-2575955.jpg -m fill &
