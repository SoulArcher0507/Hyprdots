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
    property string pendingMusicPopupAction: ""
    property string pendingKeybindingsPopupAction: ""
    property string pendingFocusTimePopupAction: ""
    property string pendingCliphistPopupAction: ""
    property int pendingCliphistTopMargin: 0
    property var lazyPopupGuard: null

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

    function unloadClosedLazyPopup(loader) {
        if (!loader || !loader.active || !loader.item)
            return;
        if (!loader.item.popupMounted && !loader.item.popupTargetVisible)
            loader.active = false;
    }

    function closeLazyPopup(loader) {
        if (!loader || root.lazyPopupGuard === loader)
            return;
        if (!loader.item) {
            loader.active = false;
            return;
        }
        if (!loader.item.popupMounted && !loader.item.popupTargetVisible) {
            loader.active = false;
            return;
        }
        if (typeof loader.item.hidePopup === "function")
            loader.item.hidePopup();
        else if (typeof loader.item._hidePopup === "function")
            loader.item._hidePopup();
        else if (typeof loader.item._hideMusicPopup === "function")
            loader.item._hideMusicPopup();
        else
            loader.active = false;
    }

    function withLazyPopupGuard(loader, callback) {
        root.lazyPopupGuard = loader;
        callback();
        root.lazyPopupGuard = null;
    }

    function dispatchMusicPopupAction(action) {
        var item = musicPopupLoader.item;
        if (!item || action === "")
            return;

        if (action === "hide") {
            item.hidePopup();
            return;
        }

        if (action === "show" || (action === "toggle" && !item.popupTargetVisible)) {
            root.withLazyPopupGuard(musicPopupLoader, function() {
                ThemePkg.Theme.globalCloseAllPopups();
            });
            item.showPopup();
            return;
        }

        if (action === "toggle")
            item.hidePopup();
    }

    function runMusicPopup(action) {
        if (action === "hide" && !musicPopupLoader.active)
            return;
        root.pendingMusicPopupAction = action;
        musicPopupLoader.active = true;
        if (musicPopupLoader.item) {
            var pending = root.pendingMusicPopupAction;
            root.pendingMusicPopupAction = "";
            root.dispatchMusicPopupAction(pending);
        }
    }

    function dispatchKeybindingsPopupAction(action) {
        var item = keybindingsPopupLoader.item;
        if (!item || action === "")
            return;

        if (action === "hide") {
            item.hidePopup();
            return;
        }

        if (action === "show" || (action === "toggle" && !item.popupTargetVisible)) {
            root.withLazyPopupGuard(keybindingsPopupLoader, function() {
                item.preparePopupOpen();
            });
            return;
        }

        if (action === "toggle")
            item.hidePopup();
    }

    function runKeybindingsPopup(action) {
        if (action === "hide" && !keybindingsPopupLoader.active)
            return;
        root.pendingKeybindingsPopupAction = action;
        keybindingsPopupLoader.active = true;
        if (keybindingsPopupLoader.item) {
            var pending = root.pendingKeybindingsPopupAction;
            root.pendingKeybindingsPopupAction = "";
            root.dispatchKeybindingsPopupAction(pending);
        }
    }

    function dispatchFocusTimePopupAction(action) {
        var item = focusTimePopupLoader.item;
        if (!item || action === "")
            return;

        if (action === "hide") {
            item.hidePopup();
            return;
        }

        if (action === "show" || (action === "toggle" && !item.popupTargetVisible)) {
            root.withLazyPopupGuard(focusTimePopupLoader, function() {
                item.preparePopupOpen();
            });
            return;
        }

        if (action === "toggle")
            item.hidePopup();
    }

    function runFocusTimePopup(action) {
        if (action === "hide" && !focusTimePopupLoader.active)
            return;
        root.pendingFocusTimePopupAction = action;
        focusTimePopupLoader.active = true;
        if (focusTimePopupLoader.item) {
            var pending = root.pendingFocusTimePopupAction;
            root.pendingFocusTimePopupAction = "";
            root.dispatchFocusTimePopupAction(pending);
        }
    }

    function dispatchCliphistPopupAction(action) {
        var item = cliphistPopupLoader.item;
        if (!item || action === "")
            return;

        if (action === "hide") {
            item.hidePopup();
            return;
        }

        if (action === "show" || action === "showAt" || (action === "toggle" && !item.popupTargetVisible)) {
            root.withLazyPopupGuard(cliphistPopupLoader, function() {
                if (action === "showAt")
                    item.showAt(root.pendingCliphistTopMargin);
                else
                    item.showPopup();
            });
            return;
        }

        if (action === "toggle")
            item.hidePopup();
    }

    function runCliphistPopup(action, topMargin) {
        if (action === "hide" && !cliphistPopupLoader.active)
            return;
        root.pendingCliphistPopupAction = action;
        root.pendingCliphistTopMargin = topMargin || 0;
        cliphistPopupLoader.active = true;
        if (cliphistPopupLoader.item) {
            var pending = root.pendingCliphistPopupAction;
            root.pendingCliphistPopupAction = "";
            root.dispatchCliphistPopupAction(pending);
        }
    }

    Component.onCompleted: {
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
            root.closeLazyPopup(musicPopupLoader);
            root.closeLazyPopup(keybindingsPopupLoader);
            root.closeLazyPopup(focusTimePopupLoader);
            root.closeLazyPopup(cliphistPopupLoader);
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
            root.runKeybindingsPopup("toggle");
        }
        function show(): void {
            root.runKeybindingsPopup("show");
        }
        function hide(): void {
            root.runKeybindingsPopup("hide");
        }
    }

    IpcHandler {
        target: "focustime"
        function toggle(): void {
            root.runFocusTimePopup("toggle");
        }
        function show(): void {
            root.runFocusTimePopup("show");
        }
        function hide(): void {
            root.runFocusTimePopup("hide");
        }
    }

    IpcHandler {
        target: "music"
        function toggle(): void {
            root.runMusicPopup("toggle");
        }
        function show(): void {
            root.runMusicPopup("show");
        }
        function hide(): void {
            root.runMusicPopup("hide");
        }
    }

    IpcHandler {
        target: "cliphist"
        function show(): void {
            root.runCliphistPopup("show", 0);
        }
        function showAt(px: int): void {
            root.runCliphistPopup("showAt", px);
        }
        function toggle(): void {
            root.runCliphistPopup("toggle", 0);
        }
        function hide(): void {
            root.runCliphistPopup("hide", 0);
        }
        function opened(): bool {
            return !!(cliphistPopupLoader.item && cliphistPopupLoader.item.popupTargetVisible);
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
        id: cliphistPopupLoader
        active: false
        asynchronous: true
        sourceComponent: cliphistPopupComponent

        onLoaded: {
            var pending = root.pendingCliphistPopupAction;
            root.pendingCliphistPopupAction = "";
            root.dispatchCliphistPopupAction(pending);
        }

        Connections {
            target: cliphistPopupLoader.item
            function onPopupMountedChanged() {
                root.unloadClosedLazyPopup(cliphistPopupLoader);
            }
            function onPopupTargetVisibleChanged() {
                root.unloadClosedLazyPopup(cliphistPopupLoader);
            }
        }
    }

    Loader {
        id: musicPopupLoader
        active: false
        asynchronous: true
        sourceComponent: musicPopupComponent

        onLoaded: {
            var pending = root.pendingMusicPopupAction;
            root.pendingMusicPopupAction = "";
            root.dispatchMusicPopupAction(pending);
        }

        Connections {
            target: musicPopupLoader.item
            function onPopupMountedChanged() {
                root.unloadClosedLazyPopup(musicPopupLoader);
            }
            function onPopupTargetVisibleChanged() {
                root.unloadClosedLazyPopup(musicPopupLoader);
            }
        }
    }

    Loader {
        id: keybindingsPopupLoader
        active: false
        asynchronous: true
        sourceComponent: keybindingsPopupComponent

        onLoaded: {
            var pending = root.pendingKeybindingsPopupAction;
            root.pendingKeybindingsPopupAction = "";
            root.dispatchKeybindingsPopupAction(pending);
        }

        Connections {
            target: keybindingsPopupLoader.item
            function onPopupMountedChanged() {
                root.unloadClosedLazyPopup(keybindingsPopupLoader);
            }
            function onPopupTargetVisibleChanged() {
                root.unloadClosedLazyPopup(keybindingsPopupLoader);
            }
        }
    }

    Loader {
        id: focusTimePopupLoader
        active: false
        asynchronous: true
        sourceComponent: focusTimePopupComponent

        onLoaded: {
            var pending = root.pendingFocusTimePopupAction;
            root.pendingFocusTimePopupAction = "";
            root.dispatchFocusTimePopupAction(pending);
        }

        Connections {
            target: focusTimePopupLoader.item
            function onPopupMountedChanged() {
                root.unloadClosedLazyPopup(focusTimePopupLoader);
            }
            function onPopupTargetVisibleChanged() {
                root.unloadClosedLazyPopup(focusTimePopupLoader);
            }
        }
    }

    Loader {
        id: hyprshotLoader
        active: false
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

        Connections {
            target: hyprshotLoader.item
            function onSessionFinished() {
                hyprshotLoader.active = false;
            }
        }
    }
}
