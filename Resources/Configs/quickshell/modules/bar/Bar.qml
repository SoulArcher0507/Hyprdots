import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import "widgets/"
import org.kde.layershell 1.0
import Quickshell.Io
import "../theme" as ThemePkg
import "widgets/dnd" as DndMod
import "widgets/archtools_state" as ArchState
import Quickshell.Services.UPower
import QtQuick.Layouts 1.15
import Quickshell.Io as Io
import QtQuick.Controls as QQC2

Variants {
    id: bar
    model: Quickshell.screens

    readonly property string notificationBarIcon: DndMod.DndState.dnd ? "󰂛" : (DndMod.DndState.soundEnabled ? "󰂚" : "󰪑")
    readonly property bool showNotificationBadge: !DndMod.DndState.dnd && DndMod.DndState.notificationCount > 0
    readonly property string notificationBadgeText: DndMod.DndState.notificationCount > 99 ? "99+" : String(DndMod.DndState.notificationCount)

    readonly property int archToolsBadgeCount: ArchState.ArchToolsState.unreadNews + ArchState.ArchToolsState.unreadDotfiles
    readonly property bool showArchToolsBadge: archToolsBadgeCount > 0
    readonly property string archToolsBadgeText: archToolsBadgeCount > 99 ? "99+" : String(archToolsBadgeCount)

    function toggleDnd() {
        DndMod.DndState.dnd = !DndMod.DndState.dnd;
    }

    function focusWorkspace(workspaceId) {
        var id = Number(workspaceId);
        if (!Number.isFinite(id) || id <= 0)
            return;

        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }

    readonly property color moduleColor: ThemePkg.Theme.surface(0.10)
    readonly property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color moduleFontColor: ThemePkg.Theme.accent

    readonly property color workspaceActiveColor: ThemePkg.Theme.c7
    readonly property color workspaceInactiveColor: moduleColor
    readonly property color workspaceActiveFontColor: ThemePkg.Theme.accent
    readonly property color workspaceInactiveFontColor: moduleFontColor

    delegate: Component {
        Item {
            id: delegateRoot

            required property var modelData

            PanelWindow {
                id: overlayWindow
                focusable: true
                screen: delegateRoot.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                color: "transparent"
                visible: (switcher.shownOverlay !== "") || (switcher.pendingIndex !== -1)
                onVisibleChanged: if (visible)
                    switcher.forceActiveFocus()

                Shortcut {
                    sequence: "Escape"
                    context: Qt.ApplicationShortcut
                    enabled: overlayWindow.visible
                    onActivated: {
                        var loader = switcher.currentLoader();
                        if (loader && loader.item && typeof loader.item.handleEscape === "function") {
                            if (loader.item.handleEscape()) {
                                return;
                            }
                        }
                        switcher.close();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: switcher.close()
                }

                Item {
                    id: switcher
                    anchors.fill: parent
                    z: 1
                    focus: overlayWindow.visible

                    property int updPacman: panel.updPacman
                    property int updAur: panel.updAur
                    property int updFlatpak: panel.updFlatpak
                    property int updTotal: panel.updTotal
                    property string updLastTs: panel.updLastTs
                    property var _updLastMs: panel._updLastMs              
                    property int updatesMinIntervalMs: panel.updatesMinIntervalMs
                    property var archUpdateState: ({
                        running: false,
                        provider: "",
                        stage: "",
                        status: "",
                        detail: "",
                        hadError: false,
                        errorText: "",
                        countPacman: 0,
                        countAur: 0,
                        countFlatpak: 0,
                        countTotal: 0,
                        finishedTimestamp: 0,
                        stagePacman: "",
                        stageAur: "",
                        stageFlatpak: ""
                    })
                    // Scalar mirrors of archUpdateState for reliable QML bindings
                    property bool archUpdRunning: false
                    property string archUpdProvider: ""
                    property string archUpdStage: ""
                    property string archUpdStatus: ""
                    property string archUpdDetail: ""
                    property bool archUpdHadError: false
                    property string archUpdErrorText: ""
                    property int archUpdCountPacman: 0
                    property int archUpdCountAur: 0
                    property int archUpdCountFlatpak: 0
                    property int archUpdCountTotal: 0
                    property real archUpdFinishedTs: 0
                    property string archUpdStagePacman: ""
                    property string archUpdStageAur: ""
                    property string archUpdStageFlatpak: ""


                    function syncArchScalars() {
                        var s = archUpdateState || ({});
                        archUpdRunning = !!s.running;
                        archUpdProvider = s.provider || "";
                        archUpdStage = s.stage || "";
                        archUpdStatus = s.status || "";
                        archUpdDetail = s.detail || "";
                        archUpdHadError = !!s.hadError;
                        archUpdErrorText = s.errorText || "";
                        archUpdCountPacman = Number(s.countPacman || 0);
                        archUpdCountAur = Number(s.countAur || 0);
                        archUpdCountFlatpak = Number(s.countFlatpak || 0);
                        archUpdCountTotal = Number(s.countTotal || 0);
                        archUpdFinishedTs = Number(s.finishedTimestamp || 0);
                        archUpdStagePacman = s.stagePacman || "";
                        archUpdStageAur = s.stageAur || "";
                        archUpdStageFlatpak = s.stageFlatpak || "";
                    }

                    function updateArchState(overrides) {
                        var s = archUpdateState || ({});
                        var o = overrides || ({});
                        archUpdateState = {
                            running: o.running !== undefined ? !!o.running : !!s.running,
                            provider: o.provider !== undefined ? String(o.provider || "") : (s.provider || ""),
                            stage: o.stage !== undefined ? String(o.stage || "") : (s.stage || ""),
                            status: o.status !== undefined ? String(o.status || "") : (s.status || ""),
                            detail: o.detail !== undefined ? String(o.detail || "") : (s.detail || ""),
                            hadError: o.hadError !== undefined ? !!o.hadError : !!s.hadError,
                            errorText: o.errorText !== undefined ? String(o.errorText || "") : (s.errorText || ""),
                            countPacman: o.countPacman !== undefined ? Number(o.countPacman || 0) : Number(s.countPacman || 0),
                            countAur: o.countAur !== undefined ? Number(o.countAur || 0) : Number(s.countAur || 0),
                            countFlatpak: o.countFlatpak !== undefined ? Number(o.countFlatpak || 0) : Number(s.countFlatpak || 0),
                            countTotal: o.countTotal !== undefined ? Number(o.countTotal || 0) : Number(s.countTotal || 0),
                            finishedTimestamp: o.finishedTimestamp !== undefined ? Number(o.finishedTimestamp || 0) : Number(s.finishedTimestamp || 0),
                            stagePacman: o.stagePacman !== undefined ? String(o.stagePacman || "") : (s.stagePacman || ""),
                            stageAur: o.stageAur !== undefined ? String(o.stageAur || "") : (s.stageAur || ""),
                            stageFlatpak: o.stageFlatpak !== undefined ? String(o.stageFlatpak || "") : (s.stageFlatpak || "")
                        };
                        syncArchScalars();
                    }

                    function clearArchUpdateState() {
                        archUpdateState = {
                            running: false,
                            provider: "",
                            stage: "",
                            status: "",
                            detail: "",
                            hadError: false,
                            errorText: "",
                            countPacman: 0,
                            countAur: 0,
                            countFlatpak: 0,
                            countTotal: 0,
                            finishedTimestamp: 0,
                            stagePacman: "",
                            stageAur: "",
                            stageFlatpak: ""
                        };
                        syncArchScalars();
                    }

                    property string shownOverlay: ""
                    property int dur: 140
                    property int activeDur: dur
                    property real scaleIn: 0.98
                    property real scaleOut: 1.02

                    property int pendingIndex: -1
                    property string pendingShownOverlay: ""

                    Timer {
                        id: finalizeClose
                        interval: switcher.activeDur
                        repeat: false
                        onTriggered: {
                            var L = (switcher.pendingIndex === 0 ? loaderA : loaderB);
                            L.sourceComponent = null;
                            switcher.shownOverlay = "";
                            switcher.pendingIndex = -1;
                            switcher.activeDur = switcher.dur;
                        }
                    }
                    Timer {
                        id: finalizeSwap
                        interval: switcher.activeDur
                        repeat: false
                        onTriggered: {
                            var outL = (switcher.pendingIndex === 0 ? loaderA : loaderB);
                            outL.sourceComponent = null;
                            switcher.activeIndex = (switcher.pendingIndex === 0 ? 1 : 0);
                            switcher.shownOverlay = switcher.pendingShownOverlay;
                            switcher.pendingIndex = -1;
                            switcher.activeDur = switcher.dur;
                        }
                    }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Escape) {
                            var loader = switcher.currentLoader();
                            if (loader && loader.item && typeof loader.item.handleEscape === "function") {
                                if (loader.item.handleEscape()) {
                                    event.accepted = true;
                                    return;
                                }
                            }
                            switcher.close();
                            event.accepted = true;
                        }
                    }

                    function compFor(which) {
                        return which === "battery" ? batteryComp : which === "connection" ? connectionComp : which === "vpn" ? vpnComp : which === "power" ? powerComp : which === "arch" ? archComp : which === "monitor" ? monitorComp : which === "wallpaper" ? wallpaperComp : which === "calendar" ? calendarComp : which === "volume" ? volumeComp : which === "notificationSound" ? notificationSoundComp : null;
                    }

                    Loader {
                        id: loaderA
                        anchors.fill: parent
                        asynchronous: false
                        visible: item ? true : false
                        opacity: 1.0
                        scale: 1.0
                        z: 1
                        Behavior on opacity {
                            NumberAnimation {
                                duration: switcher.activeDur
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: switcher.activeDur
                                easing.type: Easing.OutCubic
                            }
                        }
                        layer.enabled: opacity > 0 && opacity < 1
                        layer.smooth: true
                    }
                    Loader {
                        id: loaderB
                        anchors.fill: parent
                        asynchronous: false
                        visible: item ? true : false
                        opacity: 0.0
                        scale: 1.0
                        z: 2
                        Behavior on opacity {
                            NumberAnimation {
                                duration: switcher.activeDur
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: switcher.activeDur
                                easing.type: Easing.OutCubic
                            }
                        }
                        layer.enabled: opacity > 0 && opacity < 1
                        layer.smooth: true
                    }

                    property int activeIndex: 0
                    function currentLoader() {
                        return activeIndex === 0 ? loaderA : loaderB;
                    }
                    function otherLoader() {
                        return activeIndex === 0 ? loaderB : loaderA;
                    }
                    function overlayEnterDurationFor(loader) {
                        var item = loader ? loader.item : null;
                        if (item && item.overlayEnterDuration !== undefined) {
                            var value = Number(item.overlayEnterDuration);
                            if (isFinite(value) && value > 0)
                                return Math.max(dur, Math.round(value));
                        }
                        return dur;
                    }
                    function overlayOwnsCloseAnimation(loader) {
                        var item = loader ? loader.item : null;
                        return !!(item && item.overlayOwnsCloseAnimation);
                    }
                    function requestOverlayCloseAnimation(loader) {
                        var item = loader ? loader.item : null;
                        if (!item || item.beginOverlayClose === undefined)
                            return false;
                        item.beginOverlayClose();
                        return true;
                    }
                    function overlayExitDurationFor(loader) {
                        var item = loader ? loader.item : null;
                        if (item && item.overlayExitDuration !== undefined) {
                            var value = Number(item.overlayExitDuration);
                            if (isFinite(value) && value > 0)
                                return Math.max(dur, Math.round(value));
                        }
                        return dur;
                    }

                    function open(which) {
                        if (!which)
                            return;
                        ThemePkg.Theme.globalCloseAllPopups();
                        var L = currentLoader();
                        L.sourceComponent = compFor(which);
                        activeDur = overlayEnterDurationFor(L);
                        L.opacity = 0.0;
                        L.scale = scaleIn;
                        L.opacity = 1.0;
                        L.scale = 1.0;
                        shownOverlay = which;
                    }

                    function close() {
                        if (shownOverlay === "" && pendingIndex === -1)
                            return;
                        var L = currentLoader();
                        activeDur = overlayExitDurationFor(L);
                        if (overlayOwnsCloseAnimation(L)) {
                            requestOverlayCloseAnimation(L);
                            L.opacity = 1.0;
                            L.scale = 1.0;
                        } else {
                            L.opacity = 0.0;
                            L.scale = scaleOut;
                        }
                        pendingIndex = activeIndex;
                        finalizeClose.start();
                    }

                    function swap(which) {
                        if (!which || which === shownOverlay)
                            return;
                        var outL = currentLoader();
                        var inL = otherLoader();

                        inL.sourceComponent = compFor(which);
                        activeDur = Math.max(overlayExitDurationFor(outL), overlayEnterDurationFor(inL));
                        inL.opacity = 0.0;
                        inL.scale = scaleIn;

                        if (overlayOwnsCloseAnimation(outL)) {
                            requestOverlayCloseAnimation(outL);
                            outL.opacity = 1.0;
                            outL.scale = 1.0;
                        } else {
                            outL.opacity = 0.0;
                            outL.scale = scaleOut;
                        }
                        inL.opacity = 1.0;
                        inL.scale = 1.0;

                        pendingIndex = activeIndex;
                        pendingShownOverlay = which;
                        finalizeSwap.start();
                    }

                    function toggle(which) {
                        if (!which)
                            return;
                        if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                            switcher.open(which);
                        } else if (switcher.shownOverlay === which && switcher.pendingIndex === -1) {
                            switcher.close();
                        } else if (switcher.shownOverlay === which && switcher.pendingIndex !== -1) {
                            finalizeClose.stop();
                            switcher.pendingIndex = -1;
                            var L = currentLoader();
                            if (L.item && typeof L.item.cancelOverlayClose === "function") {
                                L.item.cancelOverlayClose();
                            }
                            L.opacity = 1.0;
                            L.scale = 1.0;
                        } else {
                            switcher.swap(which);
                        }
                    }

                    Connections {
                        target: ThemePkg.Theme
                        function onGlobalTogglePower() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("power");
                        }
                        function onGlobalToggleWallpaper() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("wallpaper");
                        }
                        function onGlobalToggleCalendar() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("calendar");
                        }
                        function onGlobalToggleNetwork() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("connection");
                        }
                        function onGlobalToggleVpn() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("vpn");
                        }
                        function onGlobalOpenVpn() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (!activeMon || !myMon || activeMon.id !== myMon.id)
                                return;
                            if (switcher.shownOverlay === "vpn" && switcher.pendingIndex === -1)
                                return;
                            if (switcher.shownOverlay === "" && switcher.pendingIndex === -1)
                                switcher.open("vpn");
                            else
                                switcher.swap("vpn");
                        }
                        function onGlobalToggleVolume() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("volume");
                        }
                        function onGlobalToggleBattery() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("battery");
                        }
                        function onGlobalToggleArch() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("arch");
                        }
                        function onGlobalShowArchAuth(passFile) {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (!(activeMon && myMon && activeMon.id === myMon.id))
                                return;

                            if (switcher.shownOverlay === "arch" && switcher.pendingIndex === -1) {
                                var existing = switcher.currentLoader();
                                if (existing.item && typeof existing.item.cancelOverlayClose === "function")
                                    existing.item.cancelOverlayClose();
                            } else {
                                switcher.open("arch");
                            }

                            Qt.callLater(function() {
                                var L = switcher.currentLoader();
                                if (L.item && typeof L.item.showAuthPopup === "function")
                                    L.item.showAuthPopup(passFile);
                            });
                        }
                        function onGlobalToggleMonitor() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("monitor");
                        }
                        function onGlobalToggleNotificationSound() {
                            var activeMon = Hyprland.focusedMonitor;
                            var myMon = Hyprland.monitorFor(overlayWindow.screen);
                            if (activeMon && myMon && activeMon.id === myMon.id)
                                switcher.toggle("notificationSound");
                        }
                        function onGlobalCloseShellPopups() {
                            switcher.close();
                        }
                        function onGlobalCloseAllPopups() {
                            switcher.close();
                        }
                    }
                }
            }

            Component {
                id: connectionComp
                NetworkPopup {
                    anchors.fill: parent
                    overlaySwitcher: switcher
                }
            }

            Component {
                id: vpnComp
                VpnPopup {
                    anchors.fill: parent
                    overlaySwitcher: switcher
                }
            }


            Component {
                id: powerComp
                PowerMenu {
                    anchors.fill: parent
                    moduleColor: bar.moduleColor
                    moduleBorderColor: bar.moduleBorderColor
                    moduleFontColor: bar.moduleFontColor
                }
            }

            Component {
                id: calendarComp
                CalendarPopup {
                    anchors.fill: parent
                    timeButton: timeButton
                    overlayWindow: overlayWindow
                }
            }

            Component {
                id: archComp
                ArchTools {
                    anchors.fill: parent
                    switcher: switcher
                    moduleColor: bar.moduleColor
                    moduleBorderColor: bar.moduleBorderColor
                    moduleFontColor: bar.moduleFontColor
                }
            }

            Component {
                id: monitorComp
                MonitorPopup {
                    anchors.fill: parent
                }
            }

            Component {
                id: notificationSoundComp
                NotificationSoundPopup {
                    anchors.fill: parent
                    overlayScreen: delegateRoot.modelData
                }
            }

            Component {
                id: wallpaperComp
                WallpaperPicker {
                    anchors.fill: parent
                    workspaceInactiveColor: bar.workspaceInactiveColor
                    moduleBorderColor: bar.moduleBorderColor
                    moduleFontColor: bar.moduleFontColor
                    switcher: switcher
                }
            }

            Component {
                id: batteryComp
                BatteryPopup {
                    batteryButton: batteryButton
                    overlayWindow: overlayWindow
                }
            }

            Component {
                id: volumeComp
                VolumePopup {
                    anchors.fill: parent
                    overlaySwitcher: switcher
                }
            }

            PanelWindow {
                id: panel
                color: "transparent"
                screen: delegateRoot.modelData

                property var panelMonitor: null
                Timer {
                    interval: 100
                    running: panel.panelMonitor === null
                    repeat: true
                    onTriggered: {
                        var m = Hyprland.monitorFor(panel.screen);
                        if (m) {
                            panel.panelMonitor = m;
                            running = false;
                        }
                    }
                }

                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: 47
                readonly property real scaleFactor: implicitHeight / 45
                margins {
                    top: 0
                    left: 0
                    right: 0
                }

                property int updPacman: 0
                property int updAur: 0
                property int updFlatpak: 0
                property int updTotal: 0
                property string updLastTs: ""
                property var _updLastMs: 0
                property int updatesMinIntervalMs: 5 * 60 * 1000   

                property string _updatesCheckCmdBoot: "$HOME/.config/hypr/scripts/quickshell/archtools/updates-check.sh"
                property string _updatesCacheFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_cache.json"

                function applyUpdateCounts(obj) {
                    var pc = Number(obj.pacman !== undefined ? obj.pacman : (obj.updPacman || 0));
                    var aur = Number(obj.aur !== undefined ? obj.aur : (obj.updAur || 0));
                    var fl = Number(obj.flatpak !== undefined ? obj.flatpak : (obj.updFlatpak || 0));
                    var tot = Number(obj.total !== undefined ? obj.total : (obj.updTotal !== undefined ? obj.updTotal : (pc + aur + fl)));

                    panel.updPacman = isNaN(pc) ? 0 : pc;
                    panel.updAur = isNaN(aur) ? 0 : aur;
                    panel.updFlatpak = isNaN(fl) ? 0 : fl;
                    panel.updTotal = isNaN(tot) ? 0 : tot;
                    panel.updLastTs = Qt.formatDateTime(new Date(), "HH:mm");
                    panel._updLastMs = Date.now();
                }

                Process {
                    id: updatesCacheLoadProc
                    command: ["bash", "-lc", "cat " + "'" + panel._updatesCacheFile.replace(/'/g, "'\\''") + "'" + " 2>/dev/null || echo '{}'"]
                    stdout: StdioCollector {
                        id: updatesCacheLoadOut
                        waitForEnd: true
                    }
                    running: true

                    onExited: function (exitCode, exitStatus) {
                        try {
                            var obj = JSON.parse((updatesCacheLoadOut.text || "{}").trim());
                            panel.applyUpdateCounts(obj);
                            // Seed ArchTools badge counts from cache
                            if (obj.unreadNews !== undefined)
                                ArchState.ArchToolsState.unreadNews = Number(obj.unreadNews || 0);
                            if (obj.unreadDotfiles !== undefined)
                                ArchState.ArchToolsState.unreadDotfiles = Number(obj.unreadDotfiles || 0);
                        } catch (e) {}
                    }
                }

                Timer {
                    id: delayedUpdatesCheckTimer
                    interval: 12000
                    repeat: false
                    running: true
                    onTriggered: {
                        if (!updatesCheckProcBootGlobal.running)
                            updatesCheckProcBootGlobal.running = true;
                    }
                }

                Process {
                    id: updatesCheckProcBootGlobal
                    command: ["bash", "-lc", panel._updatesCheckCmdBoot]
                    stdout: StdioCollector {
                        id: updatesCheckOutBootGlobal
                        waitForEnd: true
                    }
                    running: false

                    onExited: function (exitCode, exitStatus) {
                        var raw = (updatesCheckOutBootGlobal.text || "").trim();
                        var start = raw.lastIndexOf("{");
                        var end = raw.lastIndexOf("}");
                        var json = (start !== -1 && end !== -1 && end > start) ? raw.slice(start, end + 1) : raw;

                        try {
                            var obj = JSON.parse(json);
                            panel.applyUpdateCounts(obj);
                        } catch (e) {
                            return;
                        }
                    }
                }

                Rectangle {
                    id: barBg
                    anchors.fill: parent
                    color: "transparent"
                    radius: 0
                    border.color: moduleBorderColor
                    border.width: 0

                    property real barPadding: 16 * panel.scaleFactor

                    Row {
                        id: workspacesRow
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 16 * panel.scaleFactor
                        }
                        spacing: 8 * panel.scaleFactor

                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                visible: (modelData.id > 0) && (modelData.monitor && panel.panelMonitor ? modelData.monitor.id === panel.panelMonitor.id : false)
                                width: 30 * panel.scaleFactor
                                height: 30 * panel.scaleFactor
                                radius: 10 * panel.scaleFactor
                                color: (panel.panelMonitor && panel.panelMonitor.activeWorkspace && panel.panelMonitor.activeWorkspace.id === modelData.id) ? workspaceActiveColor : workspaceInactiveColor
                                border.color: wsMa.containsMouse ? moduleFontColor : moduleBorderColor
                                border.width: 1 * panel.scaleFactor

                                AnimatedBorder {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    borderWidth: parent.border.width
                                    accentColor: (panel.panelMonitor && panel.panelMonitor.activeWorkspace && panel.panelMonitor.activeWorkspace.id === modelData.id) ? workspaceActiveFontColor : workspaceInactiveFontColor
                                }

                                scale: wsMa.pressed ? 0.95 : (wsMa.containsMouse ? 1.05 : 1.0)
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutQuart
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }

                                MouseArea {
                                    id: wsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bar.focusWorkspace(modelData.id)
                                }

                                Text {
                                    text: modelData.id
                                    anchors.centerIn: parent
                                    color: (panel.panelMonitor && panel.panelMonitor.activeWorkspace && panel.panelMonitor.activeWorkspace.id === modelData.id) ? workspaceActiveFontColor : workspaceInactiveFontColor
                                    font.pixelSize: 13 * panel.scaleFactor
                                    font.family: "Fira Sans Semibold"
                                }
                            }
                        }

                        Text {
                            visible: Hyprland.workspaces.length === 0
                            text: "No workspaces"
                            color: workspaceActiveFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                        }
                    }

                    Rectangle {
                        id: mediaPanel
                        readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/music"
                        property var mediaData: ({
                            active: false,
                            title: "",
                            artist: "",
                            status: "Stopped",
                            source: "",
                            playerName: ""
                        })
                        readonly property bool hasMedia: !!mediaData.active || mediaData.status === "Playing" || mediaData.status === "Paused"
                        readonly property bool showOnMonitor: panel.screen && panel.screen.width >= panel.screen.height
                        property real hpad: 12 * panel.scaleFactor

                        visible: showOnMonitor
                        width: mediaContent.implicitWidth + hpad * 2
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors.centerIn: parent

                        function refresh() {
                            if (!mediaPoller.running)
                                mediaPoller.running = true;
                        }

                        function playerCommand(action) {
                            if (!mediaPanel.mediaData.playerName)
                                return;

                            Quickshell.execDetached([
                                "bash",
                                mediaPanel.scriptsDir + "/player_control.sh",
                                action,
                                mediaPanel.mediaData.playerName
                            ]);
                            mediaRefreshTimer.restart();
                        }

                        function togglePlayback() {
                            var nextData = Object.assign({}, mediaPanel.mediaData);
                            nextData.status = nextData.status === "Playing" ? "Paused" : "Playing";
                            mediaPanel.mediaData = nextData;
                            mediaPanel.playerCommand("play-pause");
                        }

                        function toggleMusicPopup() {
                            Quickshell.execDetached(["qs", "ipc", "call", "music", "toggle"]);
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                        }

                        Process {
                            id: mediaPoller
                            command: [
                                "bash",
                                "-c",
                                "if [ -x \"$1/bar_media_info.sh\" ]; then exec \"$1/bar_media_info.sh\"; else exec \"$1/music_info.sh\"; fi",
                                "bar-media-poller",
                                mediaPanel.scriptsDir
                            ]
                            running: true
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    try {
                                        mediaPanel.mediaData = JSON.parse(this.text.trim());
                                    } catch (e) {}
                                }
                            }
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: mediaPanel.refresh()
                        }

                        Timer {
                            id: mediaRefreshTimer
                            interval: 150
                            repeat: false
                            onTriggered: mediaPanel.refresh()
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mediaPanel.toggleMusicPopup()
                        }

                        Row {
                            id: mediaContent
                            z: 1
                            anchors.centerIn: parent
                            spacing: 8 * panel.scaleFactor

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰎆"
                                color: moduleFontColor
                                font.pixelSize: 15 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }

                            Item {
                                width: Math.min(250 * panel.scaleFactor, Math.max(100 * panel.scaleFactor, mediaLabel.implicitWidth))
                                height: mediaPanel.height

                                Text {
                                    id: mediaLabel
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: mediaPanel.hasMedia
                                        ? mediaPanel.mediaData.title + (mediaPanel.mediaData.artist ? " - " + mediaPanel.mediaData.artist : "")
                                        : "Nessun media"
                                    color: moduleFontColor
                                    elide: Text.ElideRight
                                    font.pixelSize: 13 * panel.scaleFactor
                                    font.family: "Fira Sans Semibold"
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1 * panel.scaleFactor
                                height: 16 * panel.scaleFactor
                                color: moduleBorderColor
                            }

                            MouseArea {
                                id: mediaPrevious
                                width: 18 * panel.scaleFactor
                                height: mediaPanel.height
                                enabled: mediaPanel.hasMedia
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: mediaPanel.playerCommand("prev")

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: mediaPrevious.containsMouse ? ThemePkg.Theme.foreground : moduleFontColor
                                    font.pixelSize: 16 * panel.scaleFactor
                                    font.family: "CaskaydiaMono Nerd Font"
                                    scale: mediaPrevious.pressed ? 0.85 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: mediaPlayPause
                                width: 18 * panel.scaleFactor
                                height: mediaPanel.height
                                enabled: mediaPanel.hasMedia
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: mediaPanel.togglePlayback()

                                Text {
                                    anchors.centerIn: parent
                                    text: mediaPanel.mediaData.status === "Playing" ? "󰏤" : "󰐊"
                                    color: mediaPlayPause.containsMouse ? ThemePkg.Theme.foreground : moduleFontColor
                                    font.pixelSize: 16 * panel.scaleFactor
                                    font.family: "CaskaydiaMono Nerd Font"
                                    scale: mediaPlayPause.pressed ? 0.85 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: mediaNext
                                width: 18 * panel.scaleFactor
                                height: mediaPanel.height
                                enabled: mediaPanel.hasMedia
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: mediaPanel.playerCommand("next")

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: mediaNext.containsMouse ? ThemePkg.Theme.foreground : moduleFontColor
                                    font.pixelSize: 16 * panel.scaleFactor
                                    font.family: "CaskaydiaMono Nerd Font"
                                    scale: mediaNext.pressed ? 0.85 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: trayButton
                        width: systemTrayWidget.width
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: moduleColor
                        border.color: moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: notifyButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                            visualZ: 1
                        }

                        SystemTray {
                            id: systemTrayWidget
                            bar: panel
                            scaleFactor: panel.scaleFactor
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        id: notifyButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: maNotify.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maNotify.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: rightsidebarButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                            visualZ: 0
                        }

                        scale: maNotify.pressed ? 0.95 : (maNotify.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        MouseArea {
                            id: maNotify
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    ThemePkg.Theme.globalToggleNotifications();
                                } else if (mouse.button === Qt.RightButton) {
                                    bar.toggleDnd();
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: bar.notificationBarIcon
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "CaskaydiaMono Nerd Font"
                        }

                        Rectangle {
                            visible: bar.showNotificationBadge
                            id: notificationBadge
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            readonly property real badgeDiameter: Math.round(18 * panel.scaleFactor)
                            readonly property real arcInset: notifyButton.radius * (1 - Math.SQRT1_2)
                            anchors.rightMargin: Math.round(arcInset - (width / 2))
                            anchors.bottomMargin: Math.round(arcInset - (height / 2))
                            width: Math.max(badgeDiameter, badgeText.implicitWidth + 9 * panel.scaleFactor)
                            height: badgeDiameter
                            radius: height / 2
                            color: ThemePkg.Theme.c1
                            border.color: moduleColor
                            border.width: 1 * panel.scaleFactor
                            z: 3

                            Text {
                                id: badgeText
                                anchors.fill: parent
                                text: bar.notificationBadgeText
                                color: ThemePkg.Theme.c15
                                z: 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                renderType: Text.NativeRendering
                                font.pixelSize: Math.round(parent.height * 0.5)
                                font.family: "Fira Sans"
                                font.weight: Font.Black
                            }
                        }
                    }

                    Rectangle {
                        id: rightsidebarButton
                        property real hpad: 14 * panel.scaleFactor
                        width: rsbContent.implicitWidth + hpad * 2
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: maRsb.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maRsb.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: volumeButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                        }

                        property var ethData: null
                        property string wifiPower: "off"
                        property var wifiConnected: null

                        property string btPower: "off"
                        property var btConnected: []

                        property string networkIcon: {
                            if (ethData)
                                return "󰈀";
                            if (wifiPower === "off")
                                return "󰖪";
                            if (wifiConnected)
                                return wifiConnected.icon || "󰤨";
                            return "󰤯"; 
                        }

                        property string bluetoothIcon: {
                            if (btPower === "off")
                                return "󰂲";
                            if (btConnected && btConnected.length > 0)
                                return "󰂱";
                            return "󰂯";
                        }

                        Process {
                            id: wifiPoller
                            command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/network/wifi_panel_logic.sh"]
                            running: true
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    try {
                                        var d = JSON.parse(this.text.trim());
                                        rightsidebarButton.wifiPower = d.power || "off";
                                        rightsidebarButton.ethData = d.ethernet || null;
                                        rightsidebarButton.wifiConnected = d.connected || null;
                                    } catch (e) {}
                                }
                            }
                        }
                        Timer {
                            interval: 3000
                            running: true
                            repeat: true
                            onTriggered: wifiPoller.running = true
                        }

                        Process {
                            id: btPoller
                            command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/network/bluetooth_panel_logic.sh", "--status"]
                            running: true
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    try {
                                        var d = JSON.parse(this.text.trim());
                                        rightsidebarButton.btPower = d.power || "off";
                                        rightsidebarButton.btConnected = d.connected || [];
                                    } catch (e) {}
                                }
                            }
                        }
                        Timer {
                            interval: 3000
                            running: true
                            repeat: true
                            onTriggered: btPoller.running = true
                        }

                        Row {
                            id: rsbContent
                            anchors.centerIn: parent
                            spacing: 12 * panel.scaleFactor

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rightsidebarButton.networkIcon
                                color: moduleFontColor
                                font.pixelSize: 15 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rightsidebarButton.bluetoothIcon
                                color: moduleFontColor
                                font.pixelSize: 15 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }
                        }

                        scale: maRsb.pressed ? 0.95 : (maRsb.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        MouseArea {
                            id: maRsb
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            property real tipRectX: 0
                            property real tipRectY: 0
                            property bool tipVisible: false

                            Timer {
                                id: rsbTipShow
                                interval: 250
                                repeat: false
                                onTriggered: {
                                    if (maRsb.containsMouse) {
                                        const host = panel.contentItem;
                                        const p = rightsidebarButton.mapToItem(host, 0, 0);
                                        maRsb.tipRectX = p.x;
                                        maRsb.tipRectY = p.y;
                                        maRsb.tipVisible = true;
                                    }
                                }
                            }

                            onEntered: rsbTipShow.start()
                            onExited: {
                                rsbTipShow.stop();
                                maRsb.tipVisible = false;
                            }

                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("connection");
                                } else if (switcher.shownOverlay === "connection") {
                                    switcher.close();
                                } else {
                                    switcher.swap("connection");
                                }
                            }
                        }

                        PopupWindow {
                            id: rsbHoverTip
                            color: "transparent"
                            visible: maRsb.tipVisible
                            anchor.window: panel
                            property int gap: Math.round(5 * panel.scaleFactor)
                            anchor.rect.x: maRsb.tipRectX
                            anchor.rect.y: maRsb.tipRectY + rightsidebarButton.height + gap
                            anchor.rect.width: rightsidebarButton.width
                            anchor.rect.height: 1
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom

                            property int hpad: Math.round(8 * panel.scaleFactor)
                            property int vpad: Math.round(6 * panel.scaleFactor)
                            implicitWidth: rsbTipText.implicitWidth + 2 * hpad
                            implicitHeight: rsbTipText.implicitHeight + 2 * vpad

                            Rectangle {
                                anchors.fill: parent
                                radius: 10 * panel.scaleFactor
                                color: moduleColor
                                border.width: 1 * panel.scaleFactor
                                border.color: moduleBorderColor
                                opacity: 1.0

                                Text {
                                    id: rsbTipText
                                    anchors.centerIn: parent
                                    text: {
                                        var parts = [];
                                        if (rightsidebarButton.ethData) {
                                            parts.push("Wired connection");
                                        } else if (rightsidebarButton.wifiConnected && rightsidebarButton.wifiConnected.ssid) {
                                            parts.push(rightsidebarButton.wifiConnected.ssid);
                                        } else if (rightsidebarButton.wifiPower !== "off") {
                                            parts.push("Disconnected");
                                        }

                                        if (rightsidebarButton.btConnected && rightsidebarButton.btConnected.length > 0) {
                                            var btNames = [];
                                            for (var i = 0; i < rightsidebarButton.btConnected.length; i++) {
                                                btNames.push(rightsidebarButton.btConnected[i].name || rightsidebarButton.btConnected[i].mac || "Unknown");
                                            }
                                            parts.push(btNames.join(", "));
                                        }
                                        
                                        return parts.length > 0 ? parts.join(" | ") : "Network";
                                    }
                                    color: moduleFontColor
                                    font.pixelSize: Math.round(13 * panel.scaleFactor)
                                    font.family: "Fira Sans Semibold"
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: volumeButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/volume"
                        color: maVolume.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maVolume.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: batteryButton.visible ? batteryButton.left : logoutButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                        }

                        PwObjectTracker {
                            objects: [Pipewire.defaultAudioSink]
                        }
                        readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                        property int currentVolume: 0
                        property bool currentMute: false
                        property string currentName: ""

                        function syncLiveAudioState() {
                            const audio = volumeButton.sinkAudio;
                            if (!audio) {
                                volumeButton.currentVolume = 0;
                                return;
                            }

                            volumeButton.currentVolume = Math.max(0, Math.round((audio.volume || 0) * 100));
                        }

                        function refreshAudioName() {
                            if (!barVolPoller.running)
                                barVolPoller.running = true;
                        }

                        function refreshMuteState() {
                            if (!barMutePoller.running)
                                barMutePoller.running = true;
                        }

                        function scheduleAudioStateResync() {
                            audioStateResync.restart();
                        }

                        Component.onCompleted: {
                            volumeButton.syncLiveAudioState();
                            volumeButton.refreshMuteState();
                            volumeButton.refreshAudioName();
                        }

                        onSinkAudioChanged: {
                            volumeButton.syncLiveAudioState();
                            volumeButton.refreshMuteState();
                            volumeButton.refreshAudioName();
                        }

                        Connections {
                            target: volumeButton.sinkAudio
                            function onVolumeChanged() {
                                volumeButton.syncLiveAudioState();
                            }
                            function onMuteChanged() {
                                volumeButton.refreshMuteState();
                            }
                            ignoreUnknownSignals: true
                        }

                        Process {
                            id: barMutePoller
                            command: ["bash", "-lc", "pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print tolower($2)}'"]
                            running: false
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    var state = (this.text || "").trim().toLowerCase();
                                    if (state === "yes" || state === "true" || state === "1")
                                        volumeButton.currentMute = true;
                                    else if (state === "no" || state === "false" || state === "0")
                                        volumeButton.currentMute = false;
                                }
                            }
                        }
                        Timer {
                            interval: 350
                            running: true
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: volumeButton.refreshMuteState()
                        }

                        Process {
                            id: barVolPoller
                            command: ["python3", volumeButton.scriptsDir + "/get_audio_state.py"]
                            running: false
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    try {
                                        var data = JSON.parse(this.text.trim());
                                        var outputs = data.outputs || [];
                                        for (var i = 0; i < outputs.length; i++) {
                                            if (outputs[i].is_default) {
                                                if (!volumeButton.sinkAudio) {
                                                    volumeButton.currentVolume = outputs[i].volume;
                                                }
                                                volumeButton.currentMute = !!outputs[i].mute;
                                                volumeButton.currentName = outputs[i].description || outputs[i].name || "";
                                                break;
                                            }
                                        }
                                    } catch(e) {}
                                }
                            }
                        }
                        Timer {
                            interval: 15000
                            running: true
                            repeat: true
                            triggeredOnStart: false
                            onTriggered: volumeButton.refreshAudioName()
                        }
                        Timer {
                            id: audioStateResync
                            interval: 90
                            repeat: false
                            onTriggered: {
                                volumeButton.syncLiveAudioState();
                                volumeButton.refreshMuteState();
                                volumeButton.refreshAudioName();
                            }
                        }

                        property string volumeIcon: {
                            if (currentMute || currentVolume === 0)
                                return "󰖁";
                            if (currentVolume > 50)
                                return "󰕾";
                            return "󰖀";
                        }

                        scale: maVolume.pressed ? 0.95 : (maVolume.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        MouseArea {
                            id: maVolume
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            property real tipRectX: 0
                            property real tipRectY: 0
                            property bool tipVisible: false

                            Timer {
                                id: volTipShow
                                interval: 250
                                repeat: false
                                onTriggered: {
                                    if (maVolume.containsMouse) {
                                        const host = panel.contentItem;
                                        const p = volumeButton.mapToItem(host, 0, 0);
                                        maVolume.tipRectX = p.x;
                                        maVolume.tipRectY = p.y;
                                        maVolume.tipVisible = true;
                                    }
                                }
                            }

                            onEntered: {
                                volumeButton.refreshAudioName();
                                volTipShow.start();
                            }
                            onExited: {
                                volTipShow.stop();
                                maVolume.tipVisible = false;
                            }

                            onClicked: function (mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                        switcher.open("volume");
                                    } else if (switcher.shownOverlay === "volume") {
                                        switcher.close();
                                    } else {
                                        switcher.swap("volume");
                                    }
                                } else if (mouse.button === Qt.RightButton) {
                                    volumeButton.currentMute = !volumeButton.currentMute;
                                    Quickshell.execDetached(["bash", volumeButton.scriptsDir + "/audio_control.sh", "toggle-mute", "sink", "@DEFAULT_SINK@"]);
                                    volumeButton.scheduleAudioStateResync();
                                }
                            }
                        }

                        PopupWindow {
                            id: volHoverTip
                            color: "transparent"
                            visible: maVolume.tipVisible
                            anchor.window: panel
                            property int gap: Math.round(5 * panel.scaleFactor)
                            anchor.rect.x: maVolume.tipRectX
                            anchor.rect.y: maVolume.tipRectY + volumeButton.height + gap
                            anchor.rect.width: volumeButton.width
                            anchor.rect.height: 1
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom

                            property int hpad: Math.round(8 * panel.scaleFactor)
                            property int vpad: Math.round(6 * panel.scaleFactor)
                            implicitWidth: volTipText.implicitWidth + 2 * hpad
                            implicitHeight: volTipText.implicitHeight + 2 * vpad

                            Rectangle {
                                anchors.fill: parent
                                radius: 10 * panel.scaleFactor
                                color: moduleColor
                                border.width: 1 * panel.scaleFactor
                                border.color: moduleBorderColor
                                opacity: 1.0

                                Text {
                                    id: volTipText
                                    anchors.centerIn: parent
                                    text: {
                                        let volStr = volumeButton.currentMute ? "Muted" : (volumeButton.currentVolume + "%");
                                        let nameStr = volumeButton.currentName;
                                        return nameStr ? (volStr + " - " + nameStr) : volStr;
                                    }
                                    color: moduleFontColor
                                    font.pixelSize: Math.round(13 * panel.scaleFactor)
                                    font.family: "Fira Sans Semibold"
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: volumeButton.volumeIcon
                            color: moduleFontColor
                            font.pixelSize: 16 * panel.scaleFactor
                            font.family: "CaskaydiaMono Nerd Font"
                        }
                    }

                    Rectangle {
                        id: batteryButton
                        property real hpad: 10 * panel.scaleFactor
                        implicitWidth: contentRow.implicitWidth + hpad * 2
                        width: visible ? implicitWidth : 0

                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: maBatt.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maBatt.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: visible ? 1 * panel.scaleFactor : 0
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        anchors {
                            right: logoutButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: contentRow.low ? ThemePkg.Theme.danger : moduleFontColor
                        }

                        visible: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent

                        property var dev: UPower.displayDevice
                        property int pctOverride: -1       
                        property int tteOverride: -1       
                        property int ttfOverride: -1       

                         property bool _tipVisible: false

                        property int shownPct: {
                            if (batteryButton.pctOverride >= 0)
                                return batteryButton.pctOverride;
                            var p = Number(batteryButton.dev.percentage);
                            return (!isNaN(p) && p >= 0 && p <= 100) ? Math.round(p) : 0;
                        }

                        property int tte: (dev.timeToEmpty && dev.timeToEmpty > 0) ? dev.timeToEmpty : (tteOverride >= 0 ? tteOverride : 0)
                        property int ttf: (dev.timeToFull && dev.timeToFull > 0) ? dev.timeToFull : (ttfOverride >= 0 ? ttfOverride : 0)

                        property bool charging: dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge
                        property bool discharging: dev.state === UPowerDeviceState.Discharging || dev.state === UPowerDeviceState.PendingDischarge

                        function glyphFor(p, charging) {
                            if (charging) {
                                if (p >= 95) return "󰂅";
                                if (p >= 85) return "󰂋";
                                if (p >= 75) return "󰂊";
                                if (p >= 65) return "󰢞";
                                if (p >= 55) return "󰂉";
                                if (p >= 45) return "󰢝";
                                if (p >= 35) return "󰂈";
                                if (p >= 25) return "󰂇";
                                if (p >= 15) return "󰂆";
                                if (p >= 5)  return "󰢜";
                                return "󰢟";
                            } else {
                                if (p >= 95) return "󰁹";
                                if (p >= 85) return "󰂂";
                                if (p >= 75) return "󰂁";
                                if (p >= 65) return "󰂀";
                                if (p >= 55) return "󰁿";
                                if (p >= 45) return "󰁾";
                                if (p >= 35) return "󰁽";
                                if (p >= 25) return "󰁼";
                                if (p >= 15) return "󰁻";
                                if (p >= 5)  return "󰁺";
                                return "󰂎";
                            }
                        }
                        function fmtTime(sec) {
                            if (!sec || sec <= 0)
                                return "";
                            var h = Math.floor(sec / 3600);
                            var m = Math.floor((sec % 3600) / 60);
                            return h + " h " + (m < 10 ? "0" + m : m) + " min";
                        }

                        Row {
                            id: contentRow
                            anchors.centerIn: parent
                            spacing: 6 * panel.scaleFactor
                            property bool low: (!batteryButton.charging && batteryButton.shownPct <= 15)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryButton.glyphFor(batteryButton.shownPct, batteryButton.charging)
                                color: contentRow.low ? ThemePkg.Theme.danger : moduleFontColor
                                font.pixelSize: 16 * panel.scaleFactor
                                font.family: "CaskaydiaMono Nerd Font"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryButton.shownPct + "%"
                                color: contentRow.low ? ThemePkg.Theme.danger : moduleFontColor
                                font.pixelSize: 14 * panel.scaleFactor
                                font.family: "Fira Sans Semibold"
                            }
                        }

                        scale: maBatt.pressed ? 0.95 : (maBatt.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }

                        MouseArea {
                            id: maBatt
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            property real tipRectX: 0
                            property real tipRectY: 0

                            Timer {
                                id: battTipShow
                                interval: 250
                                repeat: false
                                onTriggered: {
                                    if (maBatt.containsMouse) {
                                        const host = panel.contentItem;
                                        const p = batteryButton.mapToItem(host, 0, 0);
                                        maBatt.tipRectX = p.x;
                                        maBatt.tipRectY = p.y;
                                        batteryButton._tipVisible = true;
                                    }
                                }
                            }

                            onClicked: switcher.toggle("battery")
                            onEntered: battTipShow.start()
                            onExited: {
                                battTipShow.stop();
                                batteryButton._tipVisible = false;
                            }
                        }

                        PopupWindow {
                            id: battHoverTip
                            color: "transparent"
                            visible: batteryButton._tipVisible
                            anchor.window: panel
                            property int gap: Math.round(5 * panel.scaleFactor)
                            anchor.rect.x: maBatt.tipRectX
                            anchor.rect.y: maBatt.tipRectY + batteryButton.height + gap
                            anchor.rect.width: batteryButton.width
                            anchor.rect.height: 1
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom

                            property int hpad: Math.round(8 * panel.scaleFactor)
                            property int vpad: Math.round(6 * panel.scaleFactor)
                            implicitWidth: battTipText.implicitWidth + 2 * hpad
                            implicitHeight: battTipText.implicitHeight + 2 * vpad

                            Rectangle {
                                anchors.fill: parent
                                radius: 10 * panel.scaleFactor
                                color: moduleColor
                                border.width: 1 * panel.scaleFactor
                                border.color: moduleBorderColor
                                opacity: 1.0

                                Text {
                                    id: battTipText
                                    anchors.centerIn: parent
                                    text: {
                                        const t = batteryButton.charging ? batteryButton.ttf : batteryButton.tte;
                                        const tStr = batteryButton.fmtTime(t);
                                        if (batteryButton.charging) {
                                            return tStr ? ("Carica completa tra " + tStr + " (" + batteryButton.shownPct + "%)") : ("In carica (" + batteryButton.shownPct + "%)");
                                        } else if (batteryButton.discharging) {
                                            return tStr ? (tStr + " rimanenti (" + batteryButton.shownPct + "%)") : ("Batteria " + batteryButton.shownPct + "%");
                                        } else {
                                            return "Batteria " + batteryButton.shownPct + "%";
                                        }
                                    }
                                    color: moduleFontColor
                                    font.pixelSize: Math.round(13 * panel.scaleFactor)
                                    font.family: "Fira Sans Semibold"
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }

                        property string _pctCmd: "for d in /sys/class/power_supply/*; do " + "  [ -f \"$d/type\" ] || continue; " + "  if grep -qi battery \"$d/type\"; then " + "    if [ -r \"$d/capacity\" ]; then cat \"$d/capacity\"; exit 0; fi; " + "    if [ -r \"$d/charge_now\" ] && [ -r \"$d/charge_full\" ]; then " + "      awk 'BEGIN{now=$(<\"" + "\\$d" + "/charge_now\"); full=$(<\"" + "\\$d" + "/charge_full\"); if (full>0) printf \"%d\\n\", (now*100)/full}'; exit 0; fi; " + "    if [ -r \"$d/energy_now\" ] && [ -r \"$d/energy_full\" ]; then " + "      awk 'BEGIN{now=$(<\"" + "\\$d" + "/energy_now\"); full=$(<\"" + "\\$d" + "/energy_full\"); if (full>0) printf \"%d\\n\", (now*100)/full}'; exit 0; fi; " + "  fi; " + "done; " + "dev=$(upower -e | grep -m1 battery || true); " + "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/percentage/ {gsub(/%/,\"\",$2); gsub(/^ +/,\"\",$2); print int($2)}'"

                        property string _tteCmd: "dev=$(upower -e | grep -m1 battery || true); " + "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/time to empty/ {gsub(/^ +/,\"\",$2); v=$2; split(v,a,\" \"); x=a[1]; gsub(/,/,\".\",x); if (v ~ /hour/) print int(x*3600); else if (v ~ /minute/) print int(x*60); }'"

                        property string _ttfCmd: "dev=$(upower -e | grep -m1 battery || true); " + "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/time to full/ {gsub(/^ +/,\"\",$2); v=$2; split(v,a,\" \"); x=a[1]; gsub(/,/,\".\",x); if (v ~ /hour/) print int(x*3600); else if (v ~ /minute/) print int(x*60); }'"

                        Process {
                            id: batPctProc
                            command: ["bash", "-lc", batteryButton._pctCmd]
                            stdout: StdioCollector {
                                id: batPctOut
                                waitForEnd: true
                            }
                            onExited: {
                                var s = (batPctOut.text || "").trim();
                                var n = parseInt(s);
                                if (!isNaN(n) && n >= 0 && n <= 100)
                                    batteryButton.pctOverride = n;
                            }
                        }
                        Process {
                            id: batTteProc
                            command: ["bash", "-lc", batteryButton._tteCmd]
                            stdout: StdioCollector {
                                id: batTteOut
                                waitForEnd: true
                            }
                            onExited: {
                                var s = (batTteOut.text || "").trim();
                                var n = parseInt(s);
                                if (!isNaN(n) && n > 0)
                                    batteryButton.tteOverride = n;
                            }
                        }
                        Process {
                            id: batTtfProc
                            command: ["bash", "-lc", batteryButton._ttfCmd]
                            stdout: StdioCollector {
                                id: batTtfOut
                                waitForEnd: true
                            }
                            onExited: {
                                var s = (batTtfOut.text || "").trim();
                                var n = parseInt(s);
                                if (!isNaN(n) && n > 0)
                                    batteryButton.ttfOverride = n;
                            }
                        }

                        Timer {
                            interval: 20000
                            running: true
                            repeat: true
                            onTriggered: batPctProc.exec(["bash", "-lc", batteryButton._pctCmd])
                        }
                        Timer {
                            interval: 60000
                            running: true
                            repeat: true
                            onTriggered: {
                                batTteProc.exec(["bash", "-lc", batteryButton._tteCmd]);
                                batTtfProc.exec(["bash", "-lc", batteryButton._ttfCmd]);
                            }
                        }

                        Component.onCompleted: {
                            batPctProc.exec(["bash", "-lc", batteryButton._pctCmd]);
                            batTteProc.exec(["bash", "-lc", batteryButton._tteCmd]);
                            batTtfProc.exec(["bash", "-lc", batteryButton._ttfCmd]);
                        }
                    }

                    Rectangle {
                        id: logoutButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: maLogout.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maLogout.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: archButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                        }

                        scale: maLogout.pressed ? 0.95 : (maLogout.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        MouseArea {
                            id: maLogout
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("power");
                                } else if (switcher.shownOverlay === "power") {
                                    switcher.close();
                                } else {
                                    switcher.swap("power");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 15 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"
                        }
                    }

                    Rectangle {
                        id: archButton
                        width: 35 * panel.scaleFactor
                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: maArch.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maArch.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: timeButton.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: 8 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                            visualZ: 0
                        }

                        scale: maArch.pressed ? 0.95 : (maArch.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        MouseArea {
                            id: maArch
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if ((switcher.shownOverlay === "") && (switcher.pendingIndex === -1)) {
                                    switcher.open("arch");
                                } else if (switcher.shownOverlay === "arch") {
                                    switcher.close();
                                } else {
                                    switcher.swap("arch");
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: moduleFontColor
                            font.pixelSize: 16 * panel.scaleFactor
                            font.family: "CaskaydiaMono Nerd Font"
                        }

                        Rectangle {
                            visible: bar.showArchToolsBadge
                            id: archToolsBadge
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            readonly property real badgeDiameter: Math.round(18 * panel.scaleFactor)
                            readonly property real arcInset: archButton.radius * (1 - Math.SQRT1_2)
                            anchors.rightMargin: Math.round(arcInset - (width / 2))
                            anchors.bottomMargin: Math.round(arcInset - (height / 2))
                            width: Math.max(badgeDiameter, archBadgeText.implicitWidth + 9 * panel.scaleFactor)
                            height: badgeDiameter
                            radius: height / 2
                            color: ThemePkg.Theme.c1
                            border.color: moduleColor
                            border.width: 1 * panel.scaleFactor
                            z: 3

                            Text {
                                id: archBadgeText
                                anchors.fill: parent
                                text: bar.archToolsBadgeText
                                color: ThemePkg.Theme.c15
                                z: 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                renderType: Text.NativeRendering
                                font.pixelSize: Math.round(parent.height * 0.5)
                                font.family: "Fira Sans"
                                font.weight: Font.Black
                            }
                        }
                    }

                    Rectangle {
                        id: timeButton
                        property real hpad: 16 * panel.scaleFactor
                        implicitWidth: timeDisplay.implicitWidth + hpad * 2
                        width: implicitWidth

                        height: 30 * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: maTime.containsMouse ? Qt.lighter(moduleColor, 1.15) : moduleColor
                        border.color: maTime.containsMouse ? moduleFontColor : moduleBorderColor
                        border.width: 1 * panel.scaleFactor
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 16 * panel.scaleFactor
                        }

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: moduleFontColor
                        }

                        scale: maTime.pressed ? 0.95 : (maTime.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        MouseArea {
                            id: maTime
                            anchors.fill: parent
                            onClicked: switcher.toggle("calendar")
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }

                        Text {
                            id: timeDisplay
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: timeButton.hpad
                            }
                            property string currentTime: ""
                            text: currentTime
                            color: moduleFontColor
                            font.pixelSize: 14 * panel.scaleFactor
                            font.family: "Fira Sans Semibold"

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    var now = new Date();
                                    timeDisplay.currentTime = Qt.formatTime(now, "hh:mm") + " - " + Qt.formatDate(now, "ddd dd MMM");
                                }
                            }

                            Component.onCompleted: {
                                var now = new Date();
                                currentTime = Qt.formatDate(now, "MMM dd") + " " + Qt.formatTime(now, "hh:mm:ss");
                            }
                        }
                    }
                }
            }
        }
    }
}
