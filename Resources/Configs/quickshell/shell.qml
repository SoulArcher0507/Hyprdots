//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Hyprland
import "modules/bar/"
import "modules/notifications" as Notifications
import Quickshell.Services.Notifications as NS
import "modules/overlays"
import "modules/theme" as ThemePkg
import "modules/cliphist" as QSMod
import "modules/bar/widgets" as BarWidgets

ShellRoot {
    id: root
    property bool hyprshotOpenQueued: false

    readonly property string archtoolsScriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/archtools"
    readonly property string archtoolsRepoScriptsDir: Quickshell.env("HOME") + "/.config/hyprdots/Resources/Configs/hypr/scripts/quickshell/archtools"

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function archtoolsScriptRunCommand(fileName, args) {
        var file = String(fileName || "");
        var runner = file.endsWith(".py") ? "python3" : "bash";
        var deployed = root.archtoolsScriptsDir + "/" + file;
        var repo = root.archtoolsRepoScriptsDir + "/" + file;
        var quotedArgs = (args || []).map(function(arg) {
            return root.shellQuote(arg);
        }).join(" ");
        var suffix = quotedArgs ? " " + quotedArgs : "";

        return "if [ -f " + root.shellQuote(deployed) + " ]; then exec " + runner + " " + root.shellQuote(deployed) + suffix + "; " +
            "elif [ -f " + root.shellQuote(repo) + " ]; then exec " + runner + " " + root.shellQuote(repo) + suffix + "; " +
            "else echo '{}'; exit 1; fi";
    }

    function runDetachedShell(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    function runTerminalScript(command) {
        if (!command || command.trim() === "")
            return;
        ThemePkg.Theme.globalCloseAllPopups();

        var safeCmd = command.replace(/'/g, "'\\''");
        var fallbackCmd = safeCmd + "; echo; echo 'Done. Press Enter to close.'; read";
        var terminalCmd = "(command -v kitty >/dev/null 2>&1 && kitty --hold bash -lc '" + safeCmd + "')" + " || (command -v alacritty >/dev/null 2>&1 && alacritty --hold -e bash -lc '" + safeCmd + "')" + " || (command -v foot >/dev/null 2>&1 && foot -e bash -lc '" + fallbackCmd + "')" + " || (command -v wezterm >/dev/null 2>&1 && wezterm -e bash -lc '" + fallbackCmd + "')" + " || (command -v gnome-terminal >/dev/null 2>&1 && gnome-terminal -- bash -lc '" + fallbackCmd + "')" + " || (command -v xterm >/dev/null 2>&1 && xterm -e bash -lc '" + fallbackCmd + "')";

        root.runDetachedShell(terminalCmd);
    }

    function applyHyprdotsUpdates() {
        root.runTerminalScript(root.archtoolsScriptRunCommand("dotfiles-updates.py", ["--apply"]));
    }

    function hideLauncherProcess() {
        Quickshell.execDetached([
            "qs", "ipc",
            "-p", Quickshell.env("HOME") + "/.config/quickshell/launcher",
            "call", "launcher", "hide"
        ]);
    }

    function hideOverviewProcess() {
        Quickshell.execDetached([
            "qs", "ipc",
            "-p", Quickshell.env("HOME") + "/.config/quickshell/overview",
            "call", "overview", "close"
        ]);
    }

    function hideGameLauncherProcess() {
        Quickshell.execDetached([
            "qs", "ipc",
            "-p", Quickshell.env("HOME") + "/.config/quickshell/gamelauncher",
            "call", "gamelauncher", "hide"
        ]);
    }

    Component.onCompleted: {
        Quickshell.execDetached(["killall", "-q", "kded6"]);
        
        Qt.application.organizationName = "Quickshell";
        Qt.application.organizationDomain = "quickshell.org";
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalApplyHyprdotsUpdates() {
            root.applyHyprdotsUpdates();
        }

        function onGlobalCloseAllPopups() {
            root.hideLauncherProcess();
            root.hideOverviewProcess();
            root.hideGameLauncherProcess();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            ThemePkg.Theme.globalToggleWallpaper();
        }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "wallpaper-toggle"
        description: "Toggle wallpaper picker"
        onPressed: {
            ThemePkg.Theme.globalToggleWallpaper();
        }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            ThemePkg.Theme.globalToggleCalendar();
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            ThemePkg.Theme.globalTogglePower();
        }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "power-toggle"
        description: "Toggle power menu"
        onPressed: {
            ThemePkg.Theme.globalTogglePower();
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            ThemePkg.Theme.globalToggleNotifications();
        }
    }

    IpcHandler {
        target: "network"
        function toggle(): void {
            ThemePkg.Theme.globalToggleNetwork();
        }
    }

    IpcHandler {
        target: "vpn"
        function toggle(): void {
            ThemePkg.Theme.globalToggleVpn();
        }

        function open(): void {
            ThemePkg.Theme.globalOpenVpn();
        }
    }

    IpcHandler {
        target: "volume"
        function toggle(): void {
            ThemePkg.Theme.globalToggleVolume();
        }
    }

    IpcHandler {
        target: "battery"
        function toggle(): void {
            ThemePkg.Theme.globalToggleBattery();
        }
    }

    IpcHandler {
        target: "arch"
        function toggle(): void {
            ThemePkg.Theme.globalToggleArch();
        }

        function auth(passFile: string): void {
            ThemePkg.Theme.globalShowArchAuth(passFile);
        }
    }

    IpcHandler {
        target: "kdeconnect"
        function toggle(): void {
            ThemePkg.Theme.globalToggleKdeConnect();
        }
    }

    IpcHandler {
        target: "archtools"
        function hide(): void {
            ThemePkg.Theme.globalCloseShellPopups();
        }
        function forceHide(): void {
            ThemePkg.Theme.globalForceCloseShellPopups();
        }
    }

    IpcHandler {
        target: "monitor"
        function toggle(): void {
            ThemePkg.Theme.globalToggleMonitor();
        }
    }

    IpcHandler {
        target: "notificationsound"
        function toggle(): void {
            ThemePkg.Theme.globalToggleNotificationSound();
        }
    }

    IpcHandler {
        target: "keybindings"
        function toggle(): void {
            ThemePkg.Theme.globalToggleKeybindings();
        }
    }

    IpcHandler {
        target: "focustime"
        function toggle(): void {
            ThemePkg.Theme.globalToggleFocusTime();
        }
    }

    IpcHandler {
        target: "volumeoverlay"
        function show(): void {
            ThemePkg.Theme.globalShowVolumeOverlay();
        }
    }

    IpcHandler {
        target: "brightnessoverlay"
        function show(): void {
            ThemePkg.Theme.globalShowBrightnessOverlay();
        }
    }

    IpcHandler {
        target: "hyprshot"
        function open(): void {
            root.openHyprshot();
        }
    }

    IpcHandler {
        target: "global"
        function closeShellPopups(): void {
            ThemePkg.Theme.globalCloseShellPopups();
        }
        function forceCloseShellPopups(): void {
            ThemePkg.Theme.globalForceCloseShellPopups();
        }
        function closeAllPopups(): void {
            ThemePkg.Theme.globalCloseAllPopups();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/launcher", "call", "launcher", "toggle"]);
        }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void {
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/overview", "call", "overview", "toggle"]);
        }
        function open(): void {
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/overview", "call", "overview", "open"]);
        }
        function close(): void {
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/overview", "call", "overview", "close"]);
        }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher-toggle"
        description: "Toggle app launcher"
        onPressed: {
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/launcher", "call", "launcher", "toggle"]);
        }
    }

    IpcHandler {
        target: "gamelauncher"
        function toggle(): void {
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/gamelauncher", "call", "gamelauncher", "toggle"]);
        }
    }

    function openHyprshot() {
        ThemePkg.Theme.globalCloseAllPopups();

        if (hyprshotLoader.item) {
            hyprshotLoader.item.open();
            return;
        }

        root.hyprshotOpenQueued = true;
        hyprshotLoader.active = true;
    }

    Loader {
        active: true
        sourceComponent: Bar {}
    }

    BarWidgets.ArchToolsRefresh {}

    Component {
        id: notificationPopupComponent
        Notifications.NotificationPopup {}
    }

    Component {
        id: notificationToastComponent
        Notifications.NotificationToast {}
    }

    Component {
        id: volumeOverlayComponent
        VolumeOverlay {}
    }

    Component {
        id: brightnessOverlayComponent
        BrightnessOverlay {}
    }

    Component {
        id: cliphistPopupComponent
        QSMod.CliphistPopup {
            topMarginPx: 0
        }
    }

    Component {
        id: musicPopupComponent
        BarWidgets.MusicPopup {}
    }

    Component {
        id: keybindingsPopupComponent
        BarWidgets.KeybindingsPopup {}
    }

    Component {
        id: focusTimePopupComponent
        BarWidgets.FocusTimePopup {}
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: notificationPopupComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: notificationToastComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: volumeOverlayComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: brightnessOverlayComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: cliphistPopupComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: musicPopupComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: keybindingsPopupComponent
    }

    Loader {
        active: true
        asynchronous: true
        sourceComponent: focusTimePopupComponent
    }

    Loader {
        id: hyprshotLoader
        active: true
        asynchronous: true

        Component.onCompleted: {
            setSource(Qt.resolvedUrl("hyprshot/shell.qml"), {
                "autoStart": false
            });
        }

        onLoaded: {
            if (!root.hyprshotOpenQueued)
                return;

            root.hyprshotOpenQueued = false;
            item.open();
        }
    }
}
