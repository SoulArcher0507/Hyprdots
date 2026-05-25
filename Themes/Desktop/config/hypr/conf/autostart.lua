local function start_once(commands)
    hl.on("hyprland.start", function()
        for _, cmd in ipairs(commands) do
            hl.exec_cmd(cmd)
        end
    end)
end

start_once({
    -- Environment for xdg-desktop-portal-hyprland
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE",

    -- Setup Quickshell
    "QT_NO_XDG_DESKTOP_PORTAL=1 qs -d &",
    "QT_NO_XDG_DESKTOP_PORTAL=1 qs -p ~/.config/quickshell/overview -d &",
    "QT_NO_XDG_DESKTOP_PORTAL=1 qs -p ~/.config/quickshell/launcher -d &",
    "QT_NO_XDG_DESKTOP_PORTAL=1 qs -p ~/.config/quickshell/gamelauncher -d &",
    "~/.config/hypr/scripts/quickshell/tray/trayctl.sh watch &",
    "python3 ~/.config/hypr/scripts/quickshell/archtools/focus_daemon.py",
    "python3 ~/.config/hypr/scripts/quickshell/archtools/arch-news.py --fetch",
    "python3 ~/.config/hypr/scripts/quickshell/archtools/dotfiles-updates.py",
    "~/.config/hypr/scripts/enable-kde-filechooser-runtime.sh 20 &",

    -- Load wallpaper
    "awww-daemon",

    -- Hypridle / Hyprsunset
    "hypridle",
    "hyprsunset",

    -- Clipboard, auth and wallet
    "wl-paste --watch cliphist store",
    "/usr/lib/polkit-kde-authentication-agent-1",
    "~/.config/hypr/scripts/start-kwallet.sh",

    -- AutoRun apps
    "kdeconnect-indicator &",
    "exec solaar --window=hide' &",
    "exec flatpak run com.core447.StreamController -b' &",
    "exec steam --window=hide' &",
    "exec easyeffects --hide-window' &",
    "exec localsend --hidden' &",
    "exec sunshine' &",
    "sh -c 'sleep 6 && exec ~/.config/hypr/scripts/quickshell/tray/trayctl.sh launch 30 discord' &",
    "exec ~/.config/hypr/scripts/soundboard.sh",
})

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'command -v vivaldi >/dev/null 2>&1 && sleep 2 && exec vivaldi'")
end)
