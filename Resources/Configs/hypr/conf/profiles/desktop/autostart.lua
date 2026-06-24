local function start_once(commands)
    hl.on("hyprland.start", function()
        for _, cmd in ipairs(commands) do
            hl.exec_cmd(cmd)
        end
    end)
end

start_once({
    -- Environment for xdg-desktop-portal-hyprland
    "sh -c 'dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS && systemctl --user restart flatpak-session-helper.service'",

    -- Setup Quickshell
    "~/.config/hypr/scripts/quickshell/qs-priority.sh -d &",
    "~/.config/hypr/scripts/quickshell/qs-priority.sh -p ~/.config/quickshell/overview -d &",
    "~/.config/hypr/scripts/quickshell/qs-priority.sh -p ~/.config/quickshell/launcher -d &",
    "~/.config/hypr/scripts/quickshell/qs-priority.sh -p ~/.config/quickshell/gamelauncher -d &",
    "sh -c 'systemctl --user start plasma-xembedsniproxy.service >/dev/null 2>&1 || (command -v xembedsniproxy >/dev/null 2>&1 && exec xembedsniproxy)' &",
    "python3 ~/.config/hypr/scripts/quickshell/archtools/focus_daemon.py",
    "python3 ~/.config/hypr/scripts/quickshell/archtools/arch-news.py --fetch",
    "python3 ~/.config/hypr/scripts/quickshell/archtools/updates-daemon.py &",
    "~/.config/hypr/scripts/enable-kde-filechooser-runtime.sh 20 &",

    -- Load wallpaper
    "awww-daemon",
    "sh -c 'for i in 1 2 3 4 5; do awww restore >/dev/null 2>&1 && exit 0; sleep 0.3; done' &",

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
    "sh -c 'sleep 3 && command -v flatpak >/dev/null 2>&1 && exec flatpak run --env=HYPRLAND_INSTANCE_SIGNATURE=\"$HYPRLAND_INSTANCE_SIGNATURE\" com.core447.StreamController -b' &",
    "sh -c 'command -v easyeffects >/dev/null 2>&1 && exec easyeffects --hide-window' &",
    "sh -c 'command -v localsend >/dev/null 2>&1 && exec localsend --hidden' &",
    "sh -c 'command -v sunshine >/dev/null 2>&1 && exec sunshine' &",
    "sh -c 'sleep 3 && exec ~/.config/hypr/scripts/soundboard.sh' &",
    "sh -c 'command -v feishin >/dev/null 2>&1 && sleep 5 && exec feishin' &"
})

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'command -v steam >/dev/null 2>&1 && exec steam &'", { workspace = "4 silent" })
    hl.exec_cmd("sh -c 'command -v feishin >/dev/null 2>&1 && exec feishin &'", { workspace = "4 silent" })
    hl.exec_cmd("sh -c 'command -v discord >/dev/null 2>&1 && exec discord &'", { workspace = "3 silent" })
    hl.exec_cmd("sh -c 'command -v zen-browser >/dev/null 2>&1 && exec zen-browser &'", { workspace = "2 silent" })
end)