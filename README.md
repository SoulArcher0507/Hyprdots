# Hyprdots 1.0

Hyprdots is my personal Arch Linux + Hyprland configuration built around Hyprland and Quickshell. 

> Took huge inspiration for some quickshell compontens from [nixos-configuration](https://github.com/ilyamiro/nixos-configuration) by ilyamiro

## Preview
[TODO]

## Features
- Custom Quickshell UI with smooth animations 
- Static wallpapers through awww, animated wallpapers through mpvpaper, and matugen-based dynamic colors
- Dynamic colors applied to Hyprland, Quickshell, Kitty and Qt/KDE
- Quickshell screenshot tool with region, window, screen, OCR, color picker and save-folder actions

## Default Apps
- Terminal: Kitty
- Editor: Neovim
- Shell: Zsh

## Hyprland Device Profiles
Hyprland loads the shared config from `Resources/Configs/hypr` and automatically selects the `desktop` or `laptop` profile at startup.
Set `HYPRDOTS_DEVICE_PROFILE=desktop` or `HYPRDOTS_DEVICE_PROFILE=laptop` to force a profile manually.

## Installation
```bash
git clone https://github.com/SoulArcher0507/Hyprdots.git
cd Hyprdots
chmod +x install.sh
./install.sh
```

## Update
```bash
cd ~/.config/Hyprdots
./update.sh
```

You also need to add an openweather api key for the weather widget to work. This can be done via the button in the Arch Tools popup. 

## Phone Screen Control

To control the screen phone you need to activate wireless debug from developer options and run 
```sh
adb pair PHONE_IP:PAIRING_PORT
adb connect PHONE_IP:ADB_PORT
```

## Upcoming Features
- Mouse icon with dynamic colors
- More battery saving for laptops with tlp