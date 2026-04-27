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
        target: "archtools"
        function hide(): void {
            ThemePkg.Theme.globalCloseShellPopups();
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
