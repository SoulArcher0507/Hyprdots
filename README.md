# Hyprdots 1.0

Hyprdots is my personal Arch Linux + Hyprland configuration built around Hyprland and Quickshell. 

> Took huge inspiration for some quickshell compontens from [nixos-configuration](https://github.com/ilyamiro/nixos-configuration) by ilyamiro

## Preview
[TODO]

## Features
- Custom Quickshell UI with smooth animations 
- Static wallpapers through awww, animated wallpapers through mpvpaper, and pywal-based dynamic colors
- Dynamic colors applied to Hyprland, Quickshell, Kitty and Qt/KDE
- Quickshell screenshot tool with region, window, screen, OCR, color picker and save-folder actions

## Default Apps
- Terminal: Kitty
- Editor: Neovim
- Shell: Zsh

## Installation
```bash
git clone https://github.com/SoulArcher0507/Hyprdots.git
cd Hyprdots
chmod +x install.sh
./install.sh
```

You also need to add an openweather api key for the weather widget to work. This can be done via the button in the Arch Tools popup. 

## Upcoming Features
- Mouse icon with dynamic colors
- More battery saving for laptops with tlp
- Better nvim esthetic
