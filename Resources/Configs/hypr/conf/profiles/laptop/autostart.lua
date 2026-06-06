hl.on("hyprland.start", function()
    local commands = {
        -- Environment for xdg-desktop-portal-hyprland
        "sh -c 'dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS && systemctl --user restart flatpak-session-helper.service'",

        -- Setup Quickshell
        "~/.config/hypr/scripts/quickshell/qs-priority.sh -d &",
        "~/.config/hypr/scripts/quickshell/qs-priority.sh -c ~/.config/quickshell/overview -d &",
        "~/.config/hypr/scripts/quickshell/qs-priority.sh -c ~/.config/quickshell/launcher -d &",
        "~/.config/hypr/scripts/quickshell/qs-priority.sh -c ~/.config/quickshell/gamelauncher -d &",
        "~/.config/hypr/scripts/quickshell/tray/trayctl.sh watch &",
        "python3 ~/.config/hypr/scripts/quickshell/archtools/focus_daemon.py",
        "python3 ~/.config/hypr/scripts/quickshell/archtools/arch-news.py --fetch",
        "python3 ~/.config/hypr/scripts/quickshell/archtools/updates-daemon.py &",

        -- Wallpaper, idle, sunset and clipboard
        "awww-daemon &",
        "~/.config/hypr/scripts/start-hypridle.sh",
        "hyprsunset",
        "wl-paste --watch cliphist store &",

        -- Auth, wallet and laptop power automation
        "/usr/lib/polkit-kde-authentication-agent-1 &",
        "~/.config/hypr/scripts/start-kwallet.sh",
        "bash ~/.config/hypr/scripts/laptop_charge_boost.sh &",

        -- AutoRun apps
        "kdeconnect-indicator &",
        "sh -c 'command -v localsend >/dev/null 2>&1 && exec localsend --hidden' &",
    }

    for _, cmd in ipairs(commands) do
        hl.exec_cmd(cmd)
    end
end)
