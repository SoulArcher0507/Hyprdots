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
    "python3 ~/.config/hypr/scripts/quickshell/archtools/updates-daemon.py &",
    "~/.config/hypr/scripts/enable-kde-filechooser-runtime.sh 20 &",

    -- Load wallpaper
    "awww-daemon",

    -- Hypridle / Hyprsunset
    "~/.config/hypr/scripts/start-hypridle.sh",
    "hyprsunset",

    -- Clipboard, auth and wallet
    "wl-paste --watch cliphist store",
    "/usr/lib/polkit-kde-authentication-agent-1",
    "~/.config/hypr/scripts/start-kwallet.sh",

    -- AutoRun apps
    "kdeconnect-indicator &",
    "sh -c 'command -v solaar >/dev/null 2>&1 && exec solaar --window=hide' &",
    "sh -c 'command -v flatpak >/dev/null 2>&1 && exec flatpak run com.core447.StreamController -b' &",
    "sh -c 'command -v steam >/dev/null 2>&1 && exec steam --window=hide' &",
    "sh -c 'command -v easyeffects >/dev/null 2>&1 && exec easyeffects --hide-window' &",
    "sh -c 'command -v localsend >/dev/null 2>&1 && exec localsend --hidden' &",
    "sh -c 'command -v sunshine >/dev/null 2>&1 && exec sunshine' &",
    "sh -c 'sleep 6 && exec ~/.config/hypr/scripts/quickshell/tray/trayctl.sh launch 30 discord' &",
    "sh -c 'sleep 3 && exec ~/.config/hypr/scripts/soundboard.sh' &",
})

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'command -v zen-browser >/dev/null 2>&1 && sleep 2 && exec zen-browser' &")
end)
