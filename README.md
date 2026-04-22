# Hyprdots 1.0

Hyprdots is my personal Arch Linux + Hyprland configuration built around Hyprland and Quickshell.

## Preview
[TODO]

## Features
- Dynamic colors generated from wallpapers with pywal
- Custom Quickshell UI with smooth animations

## Default Apps
- Terminal: Kitty
- Editor: Neovim
- Zsh

## Installation
```bash
git clone https://gitea.corradoenea.com/CorradoEnea/Hyprdots.git
cd Hyprdots
./install.sh
```

You also need to add an openweather api key for the weather widget to work in ~/.config/hypr/scripts/quickshell/weather/.env with the openweather city id like this:
```bash
OPENWEATHER_API_KEY="<your-api-key>"
OPENWEATHER_CITY_ID="1234567"
```

## Upcoming Feature
- Animated wallpapers support with mpvpaper, using a different script with the wallpaper picker
- Mouse icon with dynamic colors
- More battery saving for laptops with tlp
- File picker with dynamic colors
- Better nvim esthetic

