import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io as Io
import "../../theme" as ThemePkg
import "archtools_state" as ArchState

Item {
    id: root
    anchors.fill: parent

    readonly property int archPanelWidth: 790
    readonly property int archPanelHeight: 620
    readonly property int panelScreenMargin: 16
    readonly property int panelContentMargin: 22
    readonly property int resourceCardSpacing: 8
    readonly property int resourceCardCount: 5
    readonly property real resourceCardWidth: (archPanelWidth - (panelContentMargin * 2) - (resourceCardSpacing * (resourceCardCount - 1))) / resourceCardCount
    readonly property real detailsPanelSpacing: 18
    readonly property real maxPopupHeight: Math.max(0, root.height - (panelScreenMargin * 2))
    readonly property real maxExpandedDetailsHeight: Math.max(0, maxPopupHeight - archPanelHeight - detailsPanelSpacing)
    readonly property real popupOpenWidth: root.archPanelWidth
    readonly property real popupOpenHeight: root.archPanelHeight
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2
    readonly property int overlayEnterDuration: 515
    readonly property int overlayExitDuration: 375
    readonly property bool overlayOwnsCloseAnimation: true
    readonly property int detailsExpandDuration: 360
    readonly property int detailsCollapseDuration: 240

    property var switcher
    property color moduleColor
    property color moduleBorderColor
    property color moduleFontColor

    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color mantle: ThemePkg.Theme.surface(0.05)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color overlay1: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.4)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    readonly property color accent: ThemePkg.Theme.accent
    readonly property color accent2: ThemePkg.Theme.accent2
    readonly property color success: ThemePkg.Theme.success
    readonly property color red: ThemePkg.Theme.danger
    readonly property color maroon: ThemePkg.Theme.c1
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property string repoDir: Quickshell.env("HOME") + "/.config/Hyprdots"
    readonly property string legacyRepoDir: Quickshell.env("HOME") + "/.config/hyprdots"

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/archtools"
    readonly property string bundledScriptsDir: String(Qt.resolvedUrl("../../../../hypr/scripts/quickshell/archtools")).replace("file://", "")
    readonly property string updatesCheckScript: scriptsDir + "/updates-check.sh"
    readonly property string updatesListAllScript: scriptsDir + "/updates-list-all.sh"
    readonly property string updatesListPacmanScript: scriptsDir + "/updates-list-pacman.sh"
    readonly property string updatesListAurScript: scriptsDir + "/updates-list-aur.sh"
    readonly property string updatesListFlatpakScript: scriptsDir + "/updates-list-flatpak.sh"
    readonly property string updateInfoScript: scriptsDir + "/update-info.sh"
    readonly property string hypridleScript: scriptsDir + "/hypridle.sh"
    readonly property string archNewsScript: scriptsDir + "/arch-news.py"
    readonly property string dotfilesUpdatesScript: scriptsDir + "/dotfiles-updates.py"
    readonly property string weatherEnvScript: scriptsDir + "/weather-env.sh"

    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_cache.json"
    readonly property int updatesListCacheTtlMs: 60 * 1000
    readonly property string progressFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_update.jsonl"
    readonly property string updateLogFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_update.log"
    readonly property string updateCancelFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_update.cancel"
    readonly property string updatePidFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_update.pid"
    readonly property string updateLockFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_update.lock"
    property int _lastProgressLineCount: 0
    property bool startupRefreshStarted: false
    property real lastCacheSaveMs: 0

    property int upHours: 0
    property int upMins: 0
    property int upSecs: 0

    property int unreadNews: ArchState.ArchToolsState.unreadNews
    property int unreadDotfiles: ArchState.ArchToolsState.unreadDotfiles
    onUnreadNewsChanged: ArchState.ArchToolsState.unreadNews = unreadNews
    onUnreadDotfilesChanged: ArchState.ArchToolsState.unreadDotfiles = unreadDotfiles

    property bool autolockDisabled: false

    property int updPacman: ArchState.ArchToolsState.updatePacman
    property int updAur: ArchState.ArchToolsState.updateAur
    property int updFlatpak: ArchState.ArchToolsState.updateFlatpak
    property int updTotal: ArchState.ArchToolsState.updateTotal
    property var updatesListCache: ({})

    property real statCpuTotal: 0
    property var statCpuCores: []
    property string statGpuName: ""
    property real statGpuTotal: 0
    property var statGpuDetail: []
    property real statMemUsed: 0
    property real statMemTotal: 0
    property real statMemPercent: 0
    property int statDiskRoot: 0
    property int statDiskHome: 0
    property real statDiskHomeFree: 0
    property string statDiskOsName: ""
    property real statDiskOsPercent: 0
    property string statNetIface: ""
    property real statNetDown: 0
    property real statNetUp: 0
    property real statNetTotal: 0
    property var cpuHistory: []
    property var ramHistory: []
    property var diskHistory: []
    property var gpuHistory: []
    property var netHistory: []
    property string expandedResourceKey: ""
    property string detailsDisplayKey: ""
    property string pendingDetailKey: ""
    property bool detailRefreshQueued: false
    property bool expandedResourceLoading: false
    property string expandedResourceError: ""
    property var expandedResourceData: ({})
    readonly property bool detailsOpen: expandedResourceKey !== ""
    readonly property string visibleDetailsKey: detailsOpen ? expandedResourceKey : detailsDisplayKey
    property real detailsPanelScale: detailsOpen ? 1.0 : 0.975
    property real detailsPanelOffset: detailsOpen ? 0 : -16
    property real detailsContentOpacity: detailsOpen ? 1.0 : 0.0
    property real detailsContentOffset: detailsOpen ? 0 : -10

    property bool updateRunning: !!(switcher && switcher.archUpdRunning)
    property string updateProvider: (switcher ? switcher.archUpdProvider : "")
    property string updateStage: (switcher ? switcher.archUpdStage : "")
    property string updateStatus: (switcher ? switcher.archUpdStatus : "")
    property string updateDetail: (switcher ? switcher.archUpdDetail : "")
    property bool updateHadError: !!(switcher && switcher.archUpdHadError)
    property string updateErrorText: (switcher ? switcher.archUpdErrorText : "")
    property int updateCountPacman: (switcher ? switcher.archUpdCountPacman : 0)
    property int updateCountAur: (switcher ? switcher.archUpdCountAur : 0)
    property int updateCountFlatpak: (switcher ? switcher.archUpdCountFlatpak : 0)
    property int updateCountTotal: (switcher ? switcher.archUpdCountTotal : 0)
    property real updateProgress: (switcher ? switcher.archUpdProgress : 0)
    property real updateProgressPacman: (switcher ? switcher.archUpdProgressPacman : 0)
    property real updateProgressAur: (switcher ? switcher.archUpdProgressAur : 0)
    property real updateProgressFlatpak: (switcher ? switcher.archUpdProgressFlatpak : 0)
    property real updateFinishedTimestamp: (switcher ? switcher.archUpdFinishedTs : 0)
    readonly property bool updateResultVisible: updateFinishedTimestamp > 0
    readonly property bool updateShowStatus: updateRunning || updateResultVisible
    readonly property int updateResultTtlMs: 60000

    property string weatherApiKey: ""
    property string weatherCityId: ""
    property string weatherUnit: "metric"
    property string weatherEnvPath: ""
    property string weatherSaveStatus: ""
    property bool weatherSaveHovered: false
    property bool weatherSavePressed: false

    function openSddmPicker() {
        var pickerMode = profileSettingsPopup.activePickerMode === 0
            ? "sddm-background"
            : (profileSettingsPopup.activePickerMode === 1 ? "avatar" : "grub-background");
        var cmd = root.scriptRunCommand("archtools_portal_picker.py", [pickerMode, Quickshell.env("USER")]);

        profileSettingsPopupEnterAnim.stop();
        profileSettingsPopupExitAnim.stop();
        profileSettingsPopup.popupTargetVisible = false;
        profileSettingsPopup.popupMounted = false;
        archPanel.visible = true;

        if (root.switcher && typeof root.switcher.forceClose === "function")
            root.switcher.forceClose();
        else if (root.switcher && typeof root.switcher.close === "function")
            root.switcher.close();
        else
            root.beginOverlayClose();

        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    property real weatherSaveFillLevel: 0.0
    property bool weatherSaveTriggered: false
    property real weatherSaveFlashOpacity: 0.0
    property int weatherSaveHoldDuration: 750
    property string authPassFile: ""
    property string authStatus: ""
    property bool authSubmitHovered: false
    property bool authSubmitPressed: false
    property real authUnlockFillLevel: 0.0
    property bool authUnlockTriggered: false
    property real authUnlockFlashOpacity: 0.0
    property int authUnlockHoldDuration: 750

    property string updateStagePacman: (switcher ? switcher.archUpdStagePacman : "")
    property string updateStageAur: (switcher ? switcher.archUpdStageAur : "")
    property string updateStageFlatpak: (switcher ? switcher.archUpdStageFlatpak : "")
    property bool updateRestoredFromSwitcher: false

    readonly property color ambientPrimary: root.accent
    readonly property color ambientSecondary: ThemePkg.Theme.c5

    readonly property color activeColor: root.accent
    readonly property string textFont: "Fira Sans"

    property real globalOrbitAngle: 0
    property bool autolockNotificationPending: false
    property real autolockNotificationNotBefore: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 120000
        loops: Animation.Infinite
        running: ThemePkg.Theme.edgeAnimationsEnabled
    }

    property real introState: 0.0
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.42
    property real popupCardScaleY: 0.24
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: root.popupOriginLift()
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity

    function syncNotificationCountsFromState() {
        root.unreadNews = Number(ArchState.ArchToolsState.unreadNews || 0);
        root.unreadDotfiles = Number(ArchState.ArchToolsState.unreadDotfiles || 0);
    }

    function syncUpdateCountsFromState() {
        root.updPacman = Number(ArchState.ArchToolsState.updatePacman || 0);
        root.updAur = Number(ArchState.ArchToolsState.updateAur || 0);
        root.updFlatpak = Number(ArchState.ArchToolsState.updateFlatpak || 0);
        root.updTotal = Number(ArchState.ArchToolsState.updateTotal || 0);

        if (root.switcher) {
            root.switcher.updPacman = root.updPacman;
            root.switcher.updAur = root.updAur;
            root.switcher.updFlatpak = root.updFlatpak;
            root.switcher.updTotal = root.updTotal;
            root.switcher.updLastTs = ArchState.ArchToolsState.updatesLastTs || root.switcher.updLastTs;
            root.switcher._updLastMs = Number(ArchState.ArchToolsState.updatesLastMs || root.switcher._updLastMs || 0);
        }
    }

    function publishUpdateCountsToState(timestampMs) {
        var now = Number(timestampMs || Date.now());
        ArchState.ArchToolsState.updatePacman = Number(root.updPacman || 0);
        ArchState.ArchToolsState.updateAur = Number(root.updAur || 0);
        ArchState.ArchToolsState.updateFlatpak = Number(root.updFlatpak || 0);
        ArchState.ArchToolsState.updateTotal = Number(root.updTotal || 0);
        ArchState.ArchToolsState.updatesLastTs = Qt.formatDateTime(new Date(now), "HH:mm");
        ArchState.ArchToolsState.updatesLastMs = now;
    }

    Component.onCompleted: {
        root.restoreUpdateStateFromSwitcher();
        root.syncNotificationCountsFromState();
        root.syncUpdateCountsFromState();
        popupTargetVisible = true;
        introState = 1.0;
        archPanel.visible = true;
        loadCacheProc.running = true;
        root._lastProgressLineCount = 0;
        root.startImmediateStartupRefreshes();
        popupEnterAnim.start();
        startupRefreshTimer.start();
    }

    onSwitcherChanged: {
        root.restoreUpdateStateFromSwitcher();
        root.syncUpdateCountsFromState();
    }

    Connections {
        target: ArchState.ArchToolsState
        function onUnreadNewsChanged() {
            root.unreadNews = Number(ArchState.ArchToolsState.unreadNews || 0);
        }
        function onUnreadDotfilesChanged() {
            root.unreadDotfiles = Number(ArchState.ArchToolsState.unreadDotfiles || 0);
        }
        function onUpdatePacmanChanged() {
            root.syncUpdateCountsFromState();
        }
        function onUpdateAurChanged() {
            root.syncUpdateCountsFromState();
        }
        function onUpdateFlatpakChanged() {
            root.syncUpdateCountsFromState();
        }
        function onUpdateTotalChanged() {
            root.syncUpdateCountsFromState();
        }
        function onUpdatesLastTsChanged() {
            root.syncUpdateCountsFromState();
        }
        function onUpdatesLastMsChanged() {
            root.syncUpdateCountsFromState();
        }
    }

    onHostLoaderOpacityChanged: {
        if (hostLoaderOpacity < lastHostLoaderOpacity - 0.001 && popupTargetVisible) {
            popupTargetVisible = false;
            popupEnterAnim.stop();
            if (!popupExitAnim.running)
                popupExitAnim.start();
        }
        lastHostLoaderOpacity = hostLoaderOpacity;
    }

    Behavior on introState {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutQuint
        }
    }

    Behavior on detailsPanelScale {
        NumberAnimation {
            duration: root.detailsOpen ? root.detailsExpandDuration : root.detailsCollapseDuration
            easing.type: root.detailsOpen ? Easing.OutBack : Easing.InOutCubic
        }
    }

    Behavior on detailsPanelOffset {
        NumberAnimation {
            duration: root.detailsOpen ? root.detailsExpandDuration : root.detailsCollapseDuration
            easing.type: root.detailsOpen ? Easing.OutCubic : Easing.InCubic
        }
    }

    Behavior on detailsContentOpacity {
        NumberAnimation {
            duration: root.detailsOpen ? 230 : 170
            easing.type: root.detailsOpen ? Easing.OutCubic : Easing.InCubic
        }
    }

    Behavior on detailsContentOffset {
        NumberAnimation {
            duration: root.detailsOpen ? 320 : 180
            easing.type: root.detailsOpen ? Easing.OutCubic : Easing.InCubic
        }
    }

    function popupOriginLift() {
        return root.barPanelCenterY - (root.popupClosedHeight / 2);
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "popupCardOpacity"
                to: 0.82
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleX"
                to: 0.985
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleY"
                to: 0.94
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardWidth"
                to: root.popupOpenWidth - 18
                duration: 285
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardHeight"
                to: root.popupOpenHeight - 18
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardRadius"
                to: 28
                duration: 270
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardLift"
                to: 8
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "popupCardOpacity"
                to: 1.0
                duration: 175
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleX"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleY"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardWidth"
                to: root.popupOpenWidth
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardHeight"
                to: root.popupOpenHeight
                duration: 215
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardRadius"
                to: root.popupOpenRadius
                duration: 195
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardLift"
                to: 0
                duration: 205
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "popupCardScaleX"
                to: 1.04
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleY"
                to: 0.95
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardWidth"
                to: root.popupOpenWidth + 14
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardHeight"
                to: root.popupOpenHeight - 16
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardRadius"
                to: 28
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardLift"
                to: 5
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardOpacity"
                to: 0.88
                duration: 80
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "popupCardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleX"
                to: 0.42
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardScaleY"
                to: 0.24
                duration: 280
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardWidth"
                to: root.popupClosedWidth
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardHeight"
                to: root.popupClosedHeight
                duration: 210
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "popupCardRadius"
                to: root.popupClosedRadius
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root
                property: "popupCardLift"
                to: root.popupOriginLift()
                duration: 280
                easing.type: Easing.InCubic
            }
        }
    }

    function beginOverlayClose() {
        if (!popupTargetVisible)
            return;
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupExitAnim.running)
            popupExitAnim.start();
    }

    function cancelOverlayClose() {
        popupTargetVisible = true;
        popupExitAnim.stop();
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function handleEscape() {
        if (authPopup && authPopup.popupTargetVisible) {
            root.cancelAuthPassword();
            return true;
        }
        if (weatherSettingsPopup && weatherSettingsPopup.popupTargetVisible) {
            weatherSettingsPopup.hidePopup();
            return true;
        }
        if (updatesListPopup && updatesListPopup.popupTargetVisible) {
            updatesListPopup.hidePopup();
            return true;
        }
        if (root.detailsOpen) {
            root.closeResourceDetails();
            return true;
        }
        return false;
    }

    function safeNumber(value, fallback) {
        var num = Number(value);
        return isNaN(num) ? (fallback !== undefined ? fallback : 0) : num;
    }

    function normalizedProgress(value) {
        var num = Number(value);
        if (isNaN(num))
            return 0.0;
        if (num > 1.0)
            num = num / 100.0;
        return Math.max(0.0, Math.min(1.0, num));
    }

    function progressLabel(value) {
        return String(Math.round(root.normalizedProgress(value) * 100)) + "%";
    }

    function monotonicProgress(current, incoming) {
        var next = root.normalizedProgress(incoming);
        var previous = root.normalizedProgress(current);
        return root.updateRunning ? Math.max(previous, next) : next;
    }

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function resourceScriptCommand(fileName, args) {
        var file = String(fileName || "");
        var repoPath = root.repoDir + "/Resources/Scripts/" + file;
        var legacyPath = root.legacyRepoDir + "/Resources/Scripts/" + file;
        var quotedArgs = (args || []).map(function(arg) {
            return root.shellQuote(arg);
        }).join(" ");
        var suffix = quotedArgs ? " " + quotedArgs : "";

        return "if [ -f " + root.shellQuote(repoPath) + " ]; then pkexec bash " + root.shellQuote(repoPath) + suffix + "; " +
            "elif [ -f " + root.shellQuote(legacyPath) + " ]; then pkexec bash " + root.shellQuote(legacyPath) + suffix + "; " +
            "else exit 1; fi";
    }

    function archtoolsPkexecCommand(fileName, args) {
        var file = String(fileName || "");
        var deployed = root.scriptsDir + "/" + file;
        var bundled = root.bundledScriptsDir + "/" + file;
        var quotedArgs = (args || []).map(function(arg) {
            return root.shellQuote(arg);
        }).join(" ");
        var suffix = quotedArgs ? " " + quotedArgs : "";

        return "if [ -f " + root.shellQuote(deployed) + " ]; then pkexec bash " + root.shellQuote(deployed) + suffix + "; " +
            "elif [ -f " + root.shellQuote(bundled) + " ]; then pkexec bash " + root.shellQuote(bundled) + suffix + "; " +
            "else exit 1; fi";
    }

    function progressReadCommand() {
        var progressFile = root.shellQuote(root.progressFile);
        var pidFile = root.shellQuote(root.updatePidFile);
        return "progress_file=" + progressFile + "; "
            + "pid_file=" + pidFile + "; "
            + "runner_live=0; "
            + "if [ -s \"$pid_file\" ]; then "
            + "pid=$(cat \"$pid_file\" 2>/dev/null || true); "
            + "if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null && ps -p \"$pid\" -o args= 2>/dev/null | grep -F 'update-runner.sh' >/dev/null; then runner_live=1; fi; "
            + "fi; "
            + "if [ -f \"$progress_file\" ]; then "
            + "if [ \"$runner_live\" = 1 ] || tail -n 20 \"$progress_file\" 2>/dev/null | grep -q '\"stage\":\"complete\"'; then tail -n 200 \"$progress_file\" 2>/dev/null; else echo '__archtools_stale_update__'; fi; "
            + "elif [ \"$runner_live\" = 1 ]; then echo ''; "
            + "else echo '__archtools_stale_update__'; fi";
    }

    function clearUpdateRuntimeFiles() {
        Quickshell.execDetached(["bash", "-lc", "rm -f "
            + root.shellQuote(root.progressFile) + " "
            + root.shellQuote(root.updatePidFile) + " "
            + root.shellQuote(root.updateLockFile) + " "
            + root.shellQuote(root.updateCancelFile)]);
    }

    function clearStaleUpdateState() {
        updateProgressPoller.stop();
        root.clearUpdateState();
        root.clearUpdateRuntimeFiles();
    }

    function scriptRunCommand(fileName, args) {
        var file = String(fileName || "");
        var runner = file.endsWith(".py") ? "python3" : "bash";
        var deployed = root.scriptsDir + "/" + file;
        var bundled = root.bundledScriptsDir + "/" + file;
        var quotedArgs = (args || []).map(function (arg) {
            return root.shellQuote(arg);
        }).join(" ");

        function clause(path, keyword) {
            return keyword + " [ -f " + root.shellQuote(path) + " ]; then exec " + runner + " " + root.shellQuote(path) + (quotedArgs ? " " + quotedArgs : "") + "; ";
        }

        return clause(deployed, "if") + clause(bundled, "elif") + "else echo '{}'; exit 1; fi";
    }

    function runDetachedShell(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    function pushHistory(history, value) {
        var next = (history || []).slice(0);
        next.push(root.safeNumber(value, 0));
        while (next.length > 34)
            next.shift();
        return next;
    }

    function updateUsageHistory(cpuValue, memValue, diskValue, gpuValue, netValue) {
        root.cpuHistory = root.pushHistory(root.cpuHistory, cpuValue);
        root.ramHistory = root.pushHistory(root.ramHistory, memValue);
        root.diskHistory = root.pushHistory(root.diskHistory, diskValue);
        root.gpuHistory = root.pushHistory(root.gpuHistory, gpuValue);
        root.netHistory = root.pushHistory(root.netHistory, netValue);
    }

    function historyScaleMax(history, minimum) {
        var maxValue = root.safeNumber(minimum, 1);
        var values = history || [];
        for (var i = 0; i < values.length; i++)
            maxValue = Math.max(maxValue, root.safeNumber(values[i], 0));
        return maxValue * 1.12;
    }

    function resourceTitle(key) {
        switch (key) {
        case "cpu":
            return "CPU";
        case "ram":
            return "RAM";
        case "disk":
            return "DISK";
        case "gpu":
            return "GPU";
        case "net":
            return "NET";
        default:
            return "";
        }
    }

    function resourceIcon(key) {
        switch (key) {
        case "cpu":
            return "󰻠";
        case "ram":
            return "󰍛";
        case "disk":
            return "󰋊";
        case "gpu":
            return "󰢮";
        case "net":
            return "󰖩";
        default:
            return "󰣇";
        }
    }

    function resourceAccent(key) {
        return root.accent;
    }

    function notifyArchTools(summary, body, iconHint) {
        const args = ["notify-send", "-a", "ArchTools"];
        const icon = String(iconHint || "");
        if (icon.length > 0)
            args.push("-i", icon);
        args.push(String(summary || ""), String(body || ""));
        Quickshell.execDetached(args);
    }

    function notifyAutolockState() {
        root.notifyArchTools("Autolock", root.autolockDisabled ? "Hypridle disabled" : "Hypridle enabled", root.autolockDisabled ? "changes-prevent" : "system-lock-screen");
    }

    function refreshArchToolNotifications() {
        if (!archNewsFetchProc.running)
            archNewsFetchProc.running = true;
        if (!dotfilesBootCheckProc.running)
            dotfilesBootCheckProc.running = true;
    }

    function startImmediateStartupRefreshes() {
        if (!uptimeProc.running)
            uptimeProc.running = true;
        if (!updateProgressInitProc.running)
            updateProgressInitProc.running = true;
    }

    function startStartupRefreshes() {
        if (root.startupRefreshStarted)
            return;
        root.startupRefreshStarted = true;
        startupUptimeRefresh.start();
        startupAutolockRefresh.start();
        startupProgressRefresh.start();
        startupResourceRefresh.start();
        startupUpdatesRefresh.start();
        startupNotificationsRefresh.start();
    }

    Timer {
        id: startupRefreshTimer
        interval: root.overlayEnterDuration + 80
        repeat: false
        onTriggered: root.startStartupRefreshes()
    }

    Timer {
        id: startupUptimeRefresh
        interval: 0
        repeat: false
        onTriggered: if (!uptimeProc.running)
            uptimeProc.running = true
    }

    Timer {
        id: startupAutolockRefresh
        interval: 120
        repeat: false
        onTriggered: if (!autolockStatusProc.running)
            autolockStatusProc.running = true
    }

    Timer {
        id: startupProgressRefresh
        interval: 260
        repeat: false
        onTriggered: if (!updateProgressInitProc.running)
            updateProgressInitProc.running = true
    }

    Timer {
        id: startupResourceRefresh
        interval: 430
        repeat: false
        onTriggered: if (!resProc.running)
            resProc.running = true
    }

    Timer {
        id: startupUpdatesRefresh
        interval: 650
        repeat: false
        onTriggered: if (!updatesCheckProc.running)
            updatesCheckProc.running = true
    }

    Timer {
        id: startupNotificationsRefresh
        interval: 920
        repeat: false
        onTriggered: root.refreshArchToolNotifications()
    }

    function openResourceDetails(key) {
        if (!key)
            return;
        if (root.expandedResourceKey === key) {
            root.closeResourceDetails();
            return;
        }
        detailsCloseCleanup.stop();
        root.detailsDisplayKey = key;
        root.expandedResourceKey = key;
        root.expandedResourceError = "";
        root.expandedResourceData = ({});
        root.refreshExpandedResource();
    }

    function closeResourceDetails() {
        root.expandedResourceKey = "";
        root.pendingDetailKey = "";
        root.expandedResourceLoading = false;
        root.detailRefreshQueued = false;
        detailsCloseCleanup.restart();
    }

    function refreshExpandedResource() {
        if (!root.detailsOpen)
            return;
        if (resourceDetailsProc.running) {
            root.detailRefreshQueued = true;
            return;
        }
        root.detailRefreshQueued = false;
        root.pendingDetailKey = root.expandedResourceKey;
        root.expandedResourceLoading = true;
        root.expandedResourceError = "";
        resourceDetailsProc.command = ["bash", "-lc", root.scriptRunCommand("resources-detail.py", [root.expandedResourceKey])];
        resourceDetailsProc.running = true;
    }

    function formatBytes(bytes) {
        var value = Number(bytes);
        if (isNaN(value) || value < 0)
            return "N/A";
        var units = ["B", "KB", "MB", "GB", "TB", "PB"];
        var idx = 0;
        while (value >= 1024 && idx < units.length - 1) {
            value /= 1024;
            idx++;
        }
        var digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
        return value.toFixed(digits) + " " + units[idx];
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec === undefined || bytesPerSec === null)
            return "N/A";
        return root.formatBytes(bytesPerSec) + "/s";
    }

    function formatPercent(value, digits) {
        var num = Number(value);
        if (isNaN(num))
            return "N/A";
        return num.toFixed(digits === undefined ? 0 : digits) + "%";
    }

    function formatTemp(value) {
        var num = Number(value);
        return isNaN(num) ? "N/A" : num.toFixed(1) + "°C";
    }

    function formatPower(value) {
        if (value === undefined || value === null)
            return "N/A";
        var num = Number(value);
        return isNaN(num) ? "N/A" : num.toFixed(1) + " W";
    }

    function formatFrequency(value) {
        var num = Number(value);
        if (isNaN(num))
            return "N/A";
        return (num >= 1000 ? (num / 1000).toFixed(2) + " GHz" : num.toFixed(0) + " MHz");
    }

    function detailObject(key) {
        return (root.expandedResourceData && root.expandedResourceData[key]) ? root.expandedResourceData[key] : null;
    }

    function displayedCpuTotal() {
        var cpuData = root.detailObject("cpu");
        if (root.expandedResourceKey === "cpu" && cpuData && cpuData.total_percent !== undefined && cpuData.total_percent !== null)
            return root.safeNumber(cpuData.total_percent, root.statCpuTotal);
        return root.statCpuTotal;
    }

    function displayedNetValue(field, fallback) {
        var netData = root.detailObject("net");
        if (root.expandedResourceKey === "net" && netData && netData[field] !== undefined && netData[field] !== null)
            return root.safeNumber(netData[field], fallback);
        return fallback;
    }

    function detailComponentForKey(key) {
        switch (key) {
        case "cpu":
            return cpuDetailComp;
        case "ram":
            return ramDetailComp;
        case "disk":
            return diskDetailComp;
        case "gpu":
            return gpuDetailComp;
        case "net":
            return netDetailComp;
        default:
            return null;
        }
    }

    Timer {
        id: detailsCloseCleanup
        interval: root.detailsCollapseDuration + 80
        onTriggered: {
            if (root.detailsOpen)
                return;
            root.detailsDisplayKey = "";
            root.expandedResourceError = "";
            root.expandedResourceData = ({});
        }
    }

    function sumField(items, key) {
        var total = 0;
        if (!items)
            return 0;
        for (var i = 0; i < items.length; i++)
            total += root.safeNumber(items[i][key], 0);
        return total;
    }

    Io.Process {
        id: loadCacheProc
        command: ["bash", "-c", "cat " + root.cacheFile + " 2>/dev/null || echo '{}'"]
        stdout: Io.StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(text.trim());
                    var loadedUpdateCounts = false;
                    if (obj.updPacman !== undefined) {
                        root.updPacman = obj.updPacman;
                        loadedUpdateCounts = true;
                    }
                    if (obj.updAur !== undefined) {
                        root.updAur = obj.updAur;
                        loadedUpdateCounts = true;
                    }
                    if (obj.updFlatpak !== undefined) {
                        root.updFlatpak = obj.updFlatpak;
                        loadedUpdateCounts = true;
                    }
                    if (obj.updTotal !== undefined) {
                        root.updTotal = obj.updTotal;
                        loadedUpdateCounts = true;
                    }
                    if (loadedUpdateCounts) {
                        var cacheMs = Number(obj.updLastMs || 0);
                        var stateMs = Number(ArchState.ArchToolsState.updatesLastMs || 0);
                        var cacheIsCurrent = stateMs <= 0 || (cacheMs > 0 && cacheMs >= stateMs);

                        if (!cacheIsCurrent) {
                            root.syncUpdateCountsFromState();
                        } else {
                            ArchState.ArchToolsState.updatePacman = Number(root.updPacman || 0);
                            ArchState.ArchToolsState.updateAur = Number(root.updAur || 0);
                            ArchState.ArchToolsState.updateFlatpak = Number(root.updFlatpak || 0);
                            ArchState.ArchToolsState.updateTotal = Number(root.updTotal || 0);
                            if (obj.updLastTs !== undefined)
                                ArchState.ArchToolsState.updatesLastTs = String(obj.updLastTs || "");
                            if (obj.updLastMs !== undefined)
                                ArchState.ArchToolsState.updatesLastMs = Number(obj.updLastMs || 0);
                            root.syncUpdateCountsFromState();
                        }
                    }
                    if (obj.cpuTotal !== undefined)
                        root.statCpuTotal = obj.cpuTotal;
                    if (obj.cpuCores)
                        root.statCpuCores = obj.cpuCores;
                    if (obj.gpuName)
                        root.statGpuName = obj.gpuName;
                    if (obj.gpuTotal !== undefined)
                        root.statGpuTotal = obj.gpuTotal;
                    if (obj.gpuDetail)
                        root.statGpuDetail = obj.gpuDetail;
                    if (obj.memUsed !== undefined)
                        root.statMemUsed = obj.memUsed;
                    if (obj.memTotal !== undefined)
                        root.statMemTotal = obj.memTotal;
                    if (obj.memPercent !== undefined)
                        root.statMemPercent = obj.memPercent;
                    if (obj.diskRoot !== undefined)
                        root.statDiskRoot = obj.diskRoot;
                    if (obj.diskHome !== undefined)
                        root.statDiskHome = obj.diskHome;
                    if (obj.diskHomeFree !== undefined)
                        root.statDiskHomeFree = obj.diskHomeFree;
                    if (obj.diskOsName !== undefined)
                        root.statDiskOsName = obj.diskOsName;
                    if (obj.diskOsPercent !== undefined)
                        root.statDiskOsPercent = obj.diskOsPercent;
                    if (obj.netIface !== undefined)
                        root.statNetIface = obj.netIface;
                    if (obj.netDown !== undefined)
                        root.statNetDown = obj.netDown;
                    if (obj.netUp !== undefined)
                        root.statNetUp = obj.netUp;
                    if (obj.netTotal !== undefined)
                        root.statNetTotal = obj.netTotal;
                    if (obj.unreadNews !== undefined)
                        root.unreadNews = obj.unreadNews;
                    if (obj.unreadDotfiles !== undefined)
                        root.unreadDotfiles = obj.unreadDotfiles;
                } catch (e) {}
            }
        }
    }

    function saveCache(force) {
        var now = Date.now();
        if (!force && now - root.lastCacheSaveMs < 10000)
            return;
        root.lastCacheSaveMs = now;
        var obj = {
            updPacman: root.updPacman,
            updAur: root.updAur,
            updFlatpak: root.updFlatpak,
            updTotal: root.updTotal,
            updLastTs: ArchState.ArchToolsState.updatesLastTs,
            updLastMs: ArchState.ArchToolsState.updatesLastMs,
            cpuTotal: root.statCpuTotal,
            cpuCores: root.statCpuCores,
            gpuName: root.statGpuName,
            gpuTotal: root.statGpuTotal,
            gpuDetail: root.statGpuDetail,
            memUsed: root.statMemUsed,
            memTotal: root.statMemTotal,
            memPercent: root.statMemPercent,
            diskRoot: root.statDiskRoot,
            diskHome: root.statDiskHome,
            diskHomeFree: root.statDiskHomeFree,
            diskOsName: root.statDiskOsName,
            diskOsPercent: root.statDiskOsPercent,
            netIface: root.statNetIface,
            netDown: root.statNetDown,
            netUp: root.statNetUp,
            netTotal: root.statNetTotal,
            unreadNews: root.unreadNews,
            unreadDotfiles: root.unreadDotfiles
        };
        saveCacheProc.command = ["bash", "-c", "mkdir -p $(dirname " + root.cacheFile + ") && echo '" + JSON.stringify(obj) + "' > " + root.cacheFile];
        saveCacheProc.running = true;
    }
    Io.Process {
        id: saveCacheProc
    }

    Io.Process {
        id: uptimeProc
        command: ["bash", "-c", "awk '{s=int($1); h=int(s/3600); m=int((s%3600)/60); ss=s%60; printf \"%d %d %d\",h,m,ss}' /proc/uptime"]
        stdout: Io.StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(" ");
                if (parts.length >= 3) {
                    root.upHours = parseInt(parts[0]) || 0;
                    root.upMins = parseInt(parts[1]) || 0;
                    root.upSecs = parseInt(parts[2]) || 0;
                }
            }
        }
    }
    Timer {
        interval: 1000
        running: root.startupRefreshStarted
        repeat: true
        onTriggered: if (!uptimeProc.running)
            uptimeProc.running = true
    }

    Io.Process {
        id: autolockStatusProc
        command: ["bash", "-lc", "pgrep -x hypridle"]
        onExited: function (exitCode, exitStatus) {
            root.autolockDisabled = (exitCode !== 0);
            if (root.autolockNotificationPending && Date.now() >= root.autolockNotificationNotBefore) {
                root.autolockNotificationPending = false;
                root.autolockNotificationNotBefore = 0;
                root.notifyAutolockState();
            }
        }
    }
    Timer {
        interval: 3000
        running: root.startupRefreshStarted
        repeat: true
        onTriggered: if (!autolockStatusProc.running)
            autolockStatusProc.running = true
    }
    Timer {
        id: autolockRecheck
        interval: 400
        repeat: false
        onTriggered: autolockStatusProc.running = true
    }

    Io.Process {
        id: updatesCheckProc
        command: ["bash", "-lc", updatesCheckScript]
        stdout: Io.StdioCollector {
            id: updatesCheckOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var raw = (updatesCheckOut.text || "").trim();
            var start = raw.lastIndexOf("{");
            var end = raw.lastIndexOf("}");
            var json = (start !== -1 && end !== -1 && end > start) ? raw.slice(start, end + 1) : raw;
            var pc = 0, aur = 0, fl = 0, tot = 0;
            try {
                var obj = JSON.parse(json);
                pc = Number(obj.pacman || 0);
                aur = Number(obj.aur || 0);
                fl = Number(obj.flatpak || 0);
                tot = Number(obj.total || (pc + aur + fl));
            } catch (e) {
                return;
            }
            root.updPacman = pc;
            root.updAur = aur;
            root.updFlatpak = fl;
            root.updTotal = tot;
            var now = Date.now();
            root.publishUpdateCountsToState(now);
            if (root.switcher) {
                root.switcher.updPacman = pc;
                root.switcher.updAur = aur;
                root.switcher.updFlatpak = fl;
                root.switcher.updTotal = tot;
                root.switcher.updLastTs = ArchState.ArchToolsState.updatesLastTs;
                root.switcher._updLastMs = now;
            }
            root.saveCache(true);
        }
    }
    Timer {
        interval: 15 * 60 * 1000
        running: root.startupRefreshStarted
        repeat: true
        onTriggered: updatesCheckProc.running = true
    }
    Timer {
        id: updatesRecheckSoon
        interval: 5000
        repeat: false
        onTriggered: updatesCheckProc.running = true
    }

    Io.Process {
        id: archNewsFetchProc
        command: ["bash", "-lc", root.scriptRunCommand("arch-news.py", ["--fetch"])]
        stdout: Io.StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(text.trim());
                    if (obj.unread !== undefined) {
                        root.unreadNews = obj.unread;
                        root.saveCache(true);
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 3600000
        running: root.startupRefreshStarted
        repeat: true
        onTriggered: archNewsFetchProc.running = true
    }

    Io.Process {
        id: dotfilesBootCheckProc
        command: ["bash", "-lc", root.scriptRunCommand("dotfiles-updates.py", ["--fetch"])]
        stdout: Io.StdioCollector {
            id: dotfilesBootCheckOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var raw = (dotfilesBootCheckOut.text || "").trim();
            if (!raw)
                return;
            try {
                var obj = JSON.parse(raw);
                if (obj.unread !== undefined) {
                    root.unreadDotfiles = Number(obj.unread || 0);
                    root.saveCache(true);
                }
            } catch (e) {}
        }
    }

    Io.Process {
        id: dotfilesStatusProc
        command: ["bash", "-lc", root.scriptRunCommand("dotfiles-updates.py", ["--status"])]
        stdout: Io.StdioCollector {
            id: dotfilesStatusOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var raw = (dotfilesStatusOut.text || "").trim();
            if (!raw)
                return;
            try {
                var obj = JSON.parse(raw);
                if (obj.unread !== undefined) {
                    root.unreadDotfiles = Number(obj.unread || 0);
                    root.saveCache(true);
                }
            } catch (e) {}
        }
    }
    Timer {
        interval: 15000
        running: root.startupRefreshStarted
        repeat: true
        onTriggered: if (!dotfilesStatusProc.running)
            dotfilesStatusProc.running = true
    }
    Timer {
        id: dotfilesStatusRefreshSoon
        interval: 3000
        repeat: false
        onTriggered: if (!dotfilesStatusProc.running)
            dotfilesStatusProc.running = true
    }

    Io.Process {
        id: resProc
        command: ["bash", "-lc", root.scriptRunCommand("resources-stat.sh")]
        stdout: Io.StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var obj = JSON.parse(text.trim());
                    if (obj && obj.cpu && obj.mem && obj.disk) {
                        root.statCpuTotal = obj.cpu.total || 0;
                        root.statCpuCores = obj.cpu.per_core || [];
                        root.statGpuName = (obj.gpu && obj.gpu.name) ? obj.gpu.name : "";
                        root.statGpuTotal = (obj.gpu && obj.gpu.total) ? obj.gpu.total : 0;
                        root.statGpuDetail = (obj.gpu && obj.gpu.detail) ? obj.gpu.detail : [];
                        root.statMemUsed = obj.mem.used_gb || 0;
                        root.statMemTotal = obj.mem.total_gb || 0;
                        root.statMemPercent = obj.mem.percent || 0;
                        root.statDiskRoot = obj.disk.root_percent || 0;
                        root.statDiskHome = obj.disk.home_percent || 0;
                        root.statDiskHomeFree = obj.disk.home_free_bytes || 0;
                        root.statDiskOsName = obj.disk.os_disk_name || "";
                        root.statDiskOsPercent = obj.disk.os_disk_percent || 0;
                        root.statNetIface = (obj.net && obj.net.iface) ? obj.net.iface : "";
                        root.statNetDown = (obj.net && obj.net.down_bps) ? obj.net.down_bps : 0;
                        root.statNetUp = (obj.net && obj.net.up_bps) ? obj.net.up_bps : 0;
                        root.statNetTotal = (obj.net && obj.net.total_bps) ? obj.net.total_bps : 0;
                        root.updateUsageHistory(root.statCpuTotal, root.statMemPercent, root.statDiskOsPercent, root.statGpuTotal, root.statNetTotal);
                        root.saveCache();
                    }
                } catch (e) {
                    console.warn("resources json parse failed:", e, text);
                }
            }
        }
    }
    Timer {
        running: root.startupRefreshStarted
        repeat: true
        interval: 1500
        onTriggered: if (!resProc.running)
            resProc.running = true
    }

    Io.Process {
        id: resourceDetailsProc
        stdout: Io.StdioCollector {
            id: resourceDetailsOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var requestKey = root.pendingDetailKey;
            root.expandedResourceLoading = false;

            if (exitCode !== 0) {
                if (requestKey === root.expandedResourceKey)
                    root.expandedResourceError = "Telemetry script unavailable for " + root.resourceTitle(requestKey).toLowerCase() + ".";
            } else {
                try {
                    var obj = JSON.parse((resourceDetailsOut.text || "").trim());
                    if (requestKey === root.expandedResourceKey) {
                        root.expandedResourceData = obj || ({});
                        root.expandedResourceError = "";
                    }
                } catch (e) {
                    if (requestKey === root.expandedResourceKey)
                        root.expandedResourceError = "Unable to parse live telemetry for " + root.resourceTitle(requestKey).toLowerCase() + ".";
                }
            }

            if (root.detailRefreshQueued && root.detailsOpen)
                Qt.callLater(root.refreshExpandedResource);
        }
    }
    Timer {
        id: resourceDetailsTimer
        interval: 2200
        repeat: true
        running: root.detailsOpen
        onTriggered: root.refreshExpandedResource()
    }

    function runScript(path) {
        if (!path || path.trim() === "")
            return;
        ThemePkg.Theme.globalCloseAllPopups();

        var safeCmd = path.replace(/'/g, "'\\''");
        var fallbackCmd = safeCmd + "; echo; echo 'Done. Press Enter to close.'; read";

        var terminalCmd = "(command -v kitty >/dev/null 2>&1 && kitty --hold bash -lc '" + safeCmd + "')" + " || (command -v alacritty >/dev/null 2>&1 && alacritty --hold -e bash -lc '" + safeCmd + "')" + " || (command -v foot >/dev/null 2>&1 && foot -e bash -lc '" + fallbackCmd + "')" + " || (command -v wezterm >/dev/null 2>&1 && wezterm -e bash -lc '" + fallbackCmd + "')" + " || (command -v gnome-terminal >/dev/null 2>&1 && gnome-terminal -- bash -lc '" + fallbackCmd + "')" + " || (command -v xterm >/dev/null 2>&1 && xterm -e bash -lc '" + fallbackCmd + "')";

        root.runDetachedShell(terminalCmd);
    }

    function applyHyprdotsUpdates() {
        root.runScript(root.scriptRunCommand("dotfiles-updates.py", ["--apply"]));
        dotfilesStatusRefreshSoon.start();
    }

    function restoreUpdateStateFromSwitcher() {
        if (!root.switcher)
            return;
        root.updateRunning = !!root.switcher.archUpdRunning;
        root.updateProvider = root.switcher.archUpdProvider || "";
        root.updateStage = root.switcher.archUpdStage || "";
        root.updateStatus = root.switcher.archUpdStatus || "";
        root.updateDetail = root.switcher.archUpdDetail || "";
        root.updateHadError = !!root.switcher.archUpdHadError;
        root.updateErrorText = root.switcher.archUpdErrorText || "";
        root.updateCountPacman = root.switcher.archUpdCountPacman || 0;
        root.updateCountAur = root.switcher.archUpdCountAur || 0;
        root.updateCountFlatpak = root.switcher.archUpdCountFlatpak || 0;
        root.updateCountTotal = root.switcher.archUpdCountTotal || 0;
        root.updateProgress = root.normalizedProgress(root.switcher.archUpdProgress || 0);
        root.updateProgressPacman = root.normalizedProgress(root.switcher.archUpdProgressPacman || 0);
        root.updateProgressAur = root.normalizedProgress(root.switcher.archUpdProgressAur || 0);
        root.updateProgressFlatpak = root.normalizedProgress(root.switcher.archUpdProgressFlatpak || 0);
        root.updateFinishedTimestamp = root.switcher.archUpdFinishedTs || 0;
        root.updateStagePacman = root.switcher.archUpdStagePacman || "";
        root.updateStageAur = root.switcher.archUpdStageAur || "";
        root.updateStageFlatpak = root.switcher.archUpdStageFlatpak || "";
        root.updateRestoredFromSwitcher = root.updateRunning;
        if (root.updateRunning && root.updateStage !== "complete")
            updateProgressPoller.start();
        else if (root.updateFinishedTimestamp > 0)
            root.scheduleUpdateDisplayClear();
    }

    function clearUpdateState() {
        root.updateRunning = false;
        root.updateProvider = "";
        root.updateStage = "";
        root.updateStatus = "";
        root.updateDetail = "";
        root.updateHadError = false;
        root.updateErrorText = "";
        root.updateCountPacman = 0;
        root.updateCountAur = 0;
        root.updateCountFlatpak = 0;
        root.updateCountTotal = 0;
        root.updateProgress = 0;
        root.updateProgressPacman = 0;
        root.updateProgressAur = 0;
        root.updateProgressFlatpak = 0;
        root.updateFinishedTimestamp = 0;
        root.updateStagePacman = "";
        root.updateStageAur = "";
        root.updateStageFlatpak = "";
        root.updateRestoredFromSwitcher = false;
        updateDisplayClearTimer.stop();
        root.persistUpdateStateToSwitcher();
    }

    function persistUpdateStateToSwitcher() {
        if (!root.switcher)
            return;
        root.switcher.archUpdateState = {
            running: root.updateRunning,
            provider: root.updateProvider,
            stage: root.updateStage,
            status: root.updateStatus,
            detail: root.updateDetail,
            hadError: root.updateHadError,
            errorText: root.updateErrorText,
            countPacman: root.updateCountPacman,
            countAur: root.updateCountAur,
            countFlatpak: root.updateCountFlatpak,
            countTotal: root.updateCountTotal,
            progress: root.updateProgress,
            progressPacman: root.updateProgressPacman,
            progressAur: root.updateProgressAur,
            progressFlatpak: root.updateProgressFlatpak,
            finishedTimestamp: root.updateFinishedTimestamp,
            stagePacman: root.updateStagePacman,
            stageAur: root.updateStageAur,
            stageFlatpak: root.updateStageFlatpak
        };
        root.switcher.syncArchScalars();
    }

    function startBackgroundUpdate(provider) {
        if (root.updateRunning)
            return;
        root.updatesListCache = ({});
        root.updateRunning = true;
        root.updateProvider = provider;
        root.updateStage = "";
        root.updateStatus = "starting";
        root.updateDetail = "Preparing...";
        root.updateHadError = false;
        root.updateErrorText = "";
        root.updateCountPacman = 0;
        root.updateCountAur = 0;
        root.updateCountFlatpak = 0;
        root.updateCountTotal = 0;
        root.updateProgress = 0;
        root.updateProgressPacman = 0;
        root.updateProgressAur = 0;
        root.updateProgressFlatpak = 0;
        root.updateFinishedTimestamp = 0;
        root.updateStagePacman = "";
        root.updateStageAur = "";
        root.updateStageFlatpak = "";
        root.updateRestoredFromSwitcher = false;
        root._lastProgressLineCount = 0;
        root._notificationSentForRun = false;
        updateDisplayClearTimer.stop();
        root.persistUpdateStateToSwitcher();

        var scriptCmd = root.scriptRunCommand("update-runner.sh", ["--provider", provider]);
        Quickshell.execDetached(["bash", "-lc", scriptCmd]);

        updateProgressPoller.start();
    }

    function openUpdateOutputShell() {
        if (!root.updateRunning)
            return;

        var logFile = root.shellQuote(root.updateLogFile);
        var progressFile = root.shellQuote(root.progressFile);
        var monitorCmd = "printf '\\033]0;ArchTools Update Output\\007'; "
            + "echo 'ArchTools live update output'; "
            + "echo; "
            + "while [ ! -f " + logFile + " ] && [ ! -f " + progressFile + " ]; do echo 'Waiting for update output...'; sleep 1; done; "
            + "if [ -f " + logFile + " ]; then tail -n +1 -F " + logFile + "; else tail -n +1 -F " + progressFile + "; fi";

        Quickshell.execDetached(["kitty", "--title", "ArchTools Update Output", "bash", "-lc", monitorCmd]);
        root.closeArchToolsPanel();
    }

    function closeArchToolsPanel() {
        root.beginOverlayClose();
        if (root.switcher)
            root.switcher.close();
        ThemePkg.Theme.globalCloseShellPopups();
    }

    function cancelRunningUpdate() {
        if (!root.updateRunning)
            return;

        root.updateStage = "cancel";
        root.updateStatus = "running";
        root.updateDetail = "Cancellation requested";
        root.persistUpdateStateToSwitcher();
        Quickshell.execDetached(["bash", "-lc", "mkdir -p " + root.shellQuote(root.updateCancelFile.substring(0, root.updateCancelFile.lastIndexOf('/'))) + "; touch " + root.shellQuote(root.updateCancelFile)]);
        root.notifyArchTools("Update", "Cancellation requested.", "process-stop");
    }

    property bool _notificationSentForRun: false

    function updateProviderKey(providerLabel) {
        return providerLabel === "yay" ? "aur" : providerLabel;
    }

    function updateProviderWasRequested(providerKey) {
        return root.updateProvider === "all" || root.updateProvider === providerKey;
    }

    function isTerminalUpdateStatus(status) {
        return status === "done" || status === "success" || status === "error" || status === "skipped";
    }

    function finalProviderStatus(providerKey, currentStatus, completeStatus) {
        if (!root.updateProviderWasRequested(providerKey))
            return "";
        if (root.isTerminalUpdateStatus(currentStatus))
            return currentStatus;
        return completeStatus === "success" ? "done" : "error";
    }

    function scheduleUpdateDisplayClear() {
        if (root.updateFinishedTimestamp <= 0)
            return;
        var elapsed = Math.max(0, Date.now() - root.updateFinishedTimestamp);
        updateDisplayClearTimer.interval = Math.max(1, root.updateResultTtlMs - elapsed);
        updateDisplayClearTimer.restart();
    }

    function handleUpdateLine(line, isRestoring) {
        var trimmed = (line || "").trim();
        if (!trimmed || trimmed.charAt(0) !== "{")
            return;
        try {
            var obj = JSON.parse(trimmed);
            var stage = obj.stage || "";
            var status = obj.status || "";
            var detail = obj.detail || "";

            if (stage === "init") {
                root.updateProvider = obj.provider || root.updateProvider;
                root.updateRunning = true;
                root.updateStatus = "starting";
                root.updateRestoredFromSwitcher = false;
                root.persistUpdateStateToSwitcher();
                return;
            }

            if (stage !== "complete" && status !== "") {
                root.updateRunning = true;
                root.updateFinishedTimestamp = 0;
                updateDisplayClearTimer.stop();
            }

            root.updateStage = stage;
            root.updateStatus = status;
            root.updateDetail = detail;

            if (obj.progress !== undefined)
                root.updateProgress = root.monotonicProgress(root.updateProgress, obj.progress);
            if (obj.progressPacman !== undefined)
                root.updateProgressPacman = root.monotonicProgress(root.updateProgressPacman, obj.progressPacman);
            if (obj.progressAur !== undefined)
                root.updateProgressAur = root.monotonicProgress(root.updateProgressAur, obj.progressAur);
            if (obj.progressFlatpak !== undefined)
                root.updateProgressFlatpak = root.monotonicProgress(root.updateProgressFlatpak, obj.progressFlatpak);

            if (stage === "pacman") {
                root.updateStagePacman = status;
                if (obj.stageProgress !== undefined)
                    root.updateProgressPacman = root.monotonicProgress(root.updateProgressPacman, obj.stageProgress);
            } else if (stage === "aur") {
                root.updateStageAur = status;
                if (obj.stageProgress !== undefined)
                    root.updateProgressAur = root.monotonicProgress(root.updateProgressAur, obj.stageProgress);
            } else if (stage === "flatpak") {
                root.updateStageFlatpak = status;
                if (obj.stageProgress !== undefined)
                    root.updateProgressFlatpak = root.monotonicProgress(root.updateProgressFlatpak, obj.stageProgress);
            }

            if (status === "error") {
                root.updateHadError = true;
                if (detail) {
                    if (root.updateErrorText.length > 0)
                        root.updateErrorText += "\n";
                    root.updateErrorText += stage + ": " + detail;
                }
            }

            if (stage === "complete") {
                root.updatesListCache = ({});
                root.updateCountPacman = Number(obj.pacman || 0);
                root.updateCountAur = Number(obj.aur || 0);
                root.updateCountFlatpak = Number(obj.flatpak || 0);
                root.updateCountTotal = Number(obj.total || 0);
                if (obj.errors) {
                    root.updateHadError = true;
                    root.updateErrorText = String(obj.errors);
                }
                root.updateStagePacman = root.finalProviderStatus("pacman", root.updateStagePacman, status);
                root.updateStageAur = root.finalProviderStatus("aur", root.updateStageAur, status);
                root.updateStageFlatpak = root.finalProviderStatus("flatpak", root.updateStageFlatpak, status);
                root.updateProgress = 1.0;
                if (root.updateProviderWasRequested("pacman"))
                    root.updateProgressPacman = 1.0;
                if (root.updateProviderWasRequested("aur"))
                    root.updateProgressAur = 1.0;
                if (root.updateProviderWasRequested("flatpak"))
                    root.updateProgressFlatpak = 1.0;
                root.updateRunning = false;
                root.updateFinishedTimestamp = Number(obj.finishedTimestamp || root.updateFinishedTimestamp || Date.now());
                updateProgressPoller.stop();
                root.scheduleUpdateDisplayClear();
                updatesRecheckSoon.start();
            }

            if (stage === "pacman" && (status === "done" || status === "error")) {
                root.updateCountPacman = Number(obj.count || 0);
            } else if (stage === "aur" && (status === "done" || status === "error")) {
                root.updateCountAur = Number(obj.count || 0);
            } else if (stage === "flatpak" && (status === "done" || status === "error")) {
                root.updateCountFlatpak = Number(obj.count || 0);
            }

            root.persistUpdateStateToSwitcher();
        } catch (e) {}
    }

    function updateStatusIcon(status) {
        switch (status) {
        case "starting":
            return "⟳";
        case "running":
            return "⟳";
        case "queued":
            return "⟳";
        case "done":
            return "✓";
        case "success":
            return "✓";
        case "error":
            return "✗";
        case "skipped":
            return "–";
        default:
            return "⟳";
        }
    }

    function updateStatusText() {
        if (!root.updateRunning && !root.updateResultVisible)
            return "";
        if (root.updateStatus === "success" || (root.updateStage === "complete" && !root.updateRunning))
            return root.updateHadError ? "Error" : "Done";
        if (root.updateStage && root.updateStage !== "complete")
            return root.updateStage;
        return "...";
    }

    function providerStageStatus(providerLabel) {
        var status = "";
        switch (providerLabel) {
        case "pacman":
            status = root.updateStagePacman;
            break;
        case "yay":
            status = root.updateStageAur;
            break;
        case "flatpak":
            status = root.updateStageFlatpak;
            break;
        }

        if (status === "" && root.updateRunning) {
            var target = (providerLabel === "yay" ? "aur" : providerLabel);
            if (root.updateProvider === "all" || root.updateProvider === target) {
                return "queued";
            }
        }
        return status;
    }

    function providerStatusLabel(status, progress) {
        switch (status) {
        case "starting":
        case "running":
            return root.normalizedProgress(progress) > 0.0 ? "Update" : "...";
        case "queued":
            return "Queued";
        case "done":
        case "success":
            return "Done";
        case "error":
            return "Error";
        case "skipped":
            return "Skip";
        default:
            return status;
        }
    }

    function providerStatusIcon(providerLabel) {
        var s = root.providerStageStatus(providerLabel);
        if (!s)
            return "";
        return root.updateStatusIcon(s);
    }

    function providerProgress(providerLabel) {
        switch (providerLabel) {
        case "pacman":
            return root.updateProgressPacman;
        case "yay":
            return root.updateProgressAur;
        case "flatpak":
            return root.updateProgressFlatpak;
        default:
            return 0.0;
        }
    }

    function isActiveProviderStatus(status) {
        return status === "starting" || status === "running" || status === "queued";
    }

    Io.Process {
        id: updateProgressPollProc
        command: ["bash", "-c", root.progressReadCommand()]
        stdout: Io.StdioCollector {
            id: progressPollOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var raw = (progressPollOut.text || "").trim();
            if (!raw)
                return;
            if (raw === "__archtools_stale_update__") {
                root.clearStaleUpdateState();
                return;
            }
            root.updateRestoredFromSwitcher = false;
            var lines = raw.split("\n");
            if (root._lastProgressLineCount > lines.length)
                root._lastProgressLineCount = 0;
            for (var i = root._lastProgressLineCount; i < lines.length; i++) {
                root.handleUpdateLine(lines[i]);
            }
            root._lastProgressLineCount = lines.length;
        }
    }

    Timer {
        id: updateProgressPoller
        interval: 1500
        repeat: true
        running: false
        onTriggered: {
            if (!updateProgressPollProc.running)
                updateProgressPollProc.running = true;
        }
    }

    Timer {
        id: updateProgressInitCheck
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            if (!updateProgressPollProc.running)
                updateProgressPollProc.running = true;
            updateProgressInitCheckFollow.start();
        }
    }
    Timer {
        id: updateProgressInitCheckFollow
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.updateRunning && root.updateStage !== "complete") {
                updateProgressPoller.start();
            }
        }
    }

    Io.Process {
        id: updateProgressInitProc
        command: ["bash", "-c", root.progressReadCommand()]
        stdout: Io.StdioCollector {
            id: progressInitOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var raw = (progressInitOut.text || "").trim();
            if (raw === "__archtools_stale_update__") {
                root.clearStaleUpdateState();
                return;
            }
            if (!raw) {
                if (root.updateRestoredFromSwitcher || (root.updateRunning && root.updateStage === "complete"))
                    root.clearUpdateState();
                else if (root.updateRunning && root.updateStage !== "complete")
                    updateProgressPoller.start();
                return;
            }
            root.updateRestoredFromSwitcher = false;
            var lines = raw.split("\n");
            for (var i = 0; i < lines.length; i++) {
                root.handleUpdateLine(lines[i], true);
            }
            root._lastProgressLineCount = lines.length;
            if (root.updateRunning && root.updateStage !== "complete") {
                updateProgressPoller.start();
            } else if (root.updateStage === "complete" && root.updateFinishedTimestamp > 0) {
                root.scheduleUpdateDisplayClear();
            }
        }
    }

    Timer {
        id: updateDisplayClearTimer
        interval: root.updateResultTtlMs
        repeat: false
        onTriggered: {
            root.clearUpdateState();
            Quickshell.execDetached(["bash", "-c", "rm -f " + root.shellQuote(root.progressFile)]);
        }
    }

    function openHyprlandSettings() {
        ThemePkg.Theme.globalCloseAllPopups();

        var configDir = Quickshell.env("HOME") + "/.config/hypr";
        var safeTarget = configDir.replace(/'/g, "'\\''");
        var editCmd = "nvim '" + safeTarget + "'";
        var terminalCmd = "(command -v kitty >/dev/null 2>&1 && kitty bash -lc '" + editCmd + "')" + " || (command -v alacritty >/dev/null 2>&1 && alacritty -e bash -lc '" + editCmd + "')" + " || (command -v foot >/dev/null 2>&1 && foot -e bash -lc '" + editCmd + "')" + " || (command -v wezterm >/dev/null 2>&1 && wezterm -e bash -lc '" + editCmd + "')" + " || (command -v gnome-terminal >/dev/null 2>&1 && gnome-terminal -- bash -lc '" + editCmd + "')" + " || (command -v xterm >/dev/null 2>&1 && xterm -e bash -lc '" + editCmd + "')";

        root.runDetachedShell(terminalCmd);
    }

    function openUpdatesList(title, manager, listPath) {
        var cacheKey = manager + "|" + listPath;
        var cached = root.updatesListCache[cacheKey];

        archPanel.visible = false;
        updatesListPopup.titleStr = title;
        updatesListPopup.managerType = manager;
        updatesListPopup.currentCacheKey = cacheKey;
        updatesListPopup.currentViewIndex = 0;
        updatesListPopup.currentPackageName = "";
        updatesListPopup.packageDetailsText = "";
        updatesListPopup.fetchError = "";
        updatesListPopup.allPackages = [];
        updatesListPopup.listModel.clear();
        updatesListPopup.showPopup();

        if (cached && Date.now() - cached.ts <= root.updatesListCacheTtlMs) {
            updatesListPopup.fetchError = cached.error || "";
            updatesListPopup.allPackages = cached.packages || [];
            updatesListPopup.applyFilter("");
            return;
        }

        updatesFetcher.command = ["bash", "-c", listPath];
        updatesFetcher.running = true;
    }

    function openWeatherSettings() {
        weatherSaveStatus = "";
        weatherSettingsPopup.showPopup();
        weatherEnvReadProc.command = ["bash", "-lc", root.scriptRunCommand("weather-env.sh", ["read"])];
        weatherEnvReadProc.running = true;
    }

    function showAuthPopup(passFile) {
        var path = String(passFile || "");
        if (path.indexOf("/tmp/quickshell_sudo_pass_") !== 0)
            return;
        root.authPassFile = path;
        root.authStatus = "";
        archPanel.visible = false;
        authPopup.showPopup();
    }

    function submitAuthPassword() {
        if (!root.authPassFile || authSubmitProc.running)
            return;
        if (authPasswordField.text.length === 0) {
            root.authStatus = "Password required";
            authPasswordField.forceActiveFocus();
            return;
        }
        root.authStatus = "Unlocking...";
        authSubmitProc.command = ["bash", "-lc", "umask 077; printf '%s' \"$1\" > \"$2\"; chmod 600 \"$2\"", "archtools-auth", authPasswordField.text, root.authPassFile];
        authSubmitProc.running = true;
    }

    function completeAuthUnlock() {
        if (root.authUnlockTriggered || authSubmitProc.running)
            return;

        authUnlockFillAnim.stop();
        authUnlockDrainAnim.stop();
        root.authUnlockTriggered = true;
        root.authUnlockFlashOpacity = 0.6;
        authUnlockFlashDrainAnim.start();
        root.submitAuthPassword();
        root.authUnlockFillLevel = 0.0;
        root.authUnlockTriggered = false;
        root.authSubmitPressed = false;
    }

    function cancelAuthPassword() {
        if (root.authPassFile) {
            var cancelFile = root.authPassFile.replace("/tmp/quickshell_sudo_pass_", "/tmp/quickshell_auth_cancel_");
            Quickshell.execDetached(["bash", "-lc", "touch " + root.shellQuote(cancelFile)]);
        }
        authPasswordField.text = "";
        root.authStatus = "";
        authPopup.hidePopup();
    }

    function saveWeatherSettings() {
        weatherSaveStatus = "Saving...";
        weatherEnvWriteProc.command = ["bash", "-lc", root.scriptRunCommand("weather-env.sh", ["write", weatherKeyField.text.trim(), weatherCityField.text.trim(), weatherUnitField.text.trim() || "metric"])];
        weatherEnvWriteProc.running = true;
    }

    function escapeHtml(text) {
        return String(text === undefined || text === null ? "" : text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function linkifyText(text) {
        var raw = String(text === undefined || text === null ? "" : text);
        var linkRe = /((https?:\/\/|www\.)[^\s<>"']+)/g;
        var formatted = "";
        var lastIndex = 0;
        var match;

        while ((match = linkRe.exec(raw)) !== null) {
            var wholeMatch = match[1];
            var cleanLink = wholeMatch;
            var trailing = "";

            while (cleanLink.length > 0 && /[),.;!?]$/.test(cleanLink)) {
                trailing = cleanLink.slice(-1) + trailing;
                cleanLink = cleanLink.slice(0, -1);
            }

            formatted += root.escapeHtml(raw.slice(lastIndex, match.index));

            if (cleanLink.length > 0) {
                var href = cleanLink.indexOf("www.") === 0 ? "https://" + cleanLink : cleanLink;
                formatted += "<a href=\"" + root.escapeHtml(href) + "\">" + root.escapeHtml(cleanLink) + "</a>";
            }

            formatted += root.escapeHtml(trailing);
            lastIndex = match.index + wholeMatch.length;
        }

        formatted += root.escapeHtml(raw.slice(lastIndex));
        return formatted;
    }

    Io.Process {
        id: weatherEnvReadProc
        stdout: Io.StdioCollector {
            id: weatherEnvReadOut
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            var raw = (weatherEnvReadOut.text || "").trim();
            if (!raw)
                return;
            try {
                var obj = JSON.parse(raw);
                root.weatherApiKey = obj.key || "";
                root.weatherCityId = obj.city_id || "";
                root.weatherUnit = obj.unit || "metric";
                root.weatherEnvPath = obj.path || "";
                if (typeof weatherKeyField !== "undefined")
                    weatherKeyField.text = root.weatherApiKey;
                if (typeof weatherCityField !== "undefined")
                    weatherCityField.text = root.weatherCityId;
                if (typeof weatherUnitField !== "undefined")
                    weatherUnitField.text = root.weatherUnit;
            } catch (e) {
                root.weatherSaveStatus = "Unable to read .env";
            }
        }
    }

    Io.Process {
        id: weatherEnvWriteProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                root.weatherApiKey = weatherKeyField.text.trim();
                root.weatherCityId = weatherCityField.text.trim();
                root.weatherUnit = weatherUnitField.text.trim() || "metric";
                root.weatherSaveStatus = "Saved";
                root.notifyArchTools("OpenWeather", "Calendar weather settings saved.", "weather-clear");
            } else {
                root.weatherSaveStatus = "Save failed";
                root.notifyArchTools("OpenWeather", "Unable to save calendar weather settings.", "dialog-error");
            }
        }
    }

    Io.Process {
        id: authSubmitProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                authPasswordField.text = "";
                root.authStatus = "";
                authPopup.hidePopup();
            } else {
                root.authStatus = "Unable to send password";
                authPasswordField.text = "";
                authPasswordField.forceActiveFocus();
            }
        }
    }

    Item {
        id: cardShell
        width: root.popupCardWidth
        height: root.popupCardHeight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: root.panelScreenMargin
        opacity: root.popupCardOpacity
        transform: [
            Scale {
                origin.x: cardShell.width / 2
                origin.y: cardShell.height / 2
                xScale: root.popupCardScaleX
                yScale: root.popupCardScaleY
            },
            Translate {
                y: root.popupCardLift
            }
        ]

        Rectangle {
            id: archPanel
            width: root.archPanelWidth
            height: root.archPanelHeight + (detailsViewport.height > 0 ? (detailsViewport.height + root.detailsPanelSpacing) : 0)
            radius: root.popupCardRadius
            color: root.base
            border.color: root.panelBorderColor
            border.width: 1
            clip: true
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 0
                rightMargin: 0
            }

            AnimatedBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: root.activeColor
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            Item {
                id: archBaseSection
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.archPanelHeight
            }

            Rectangle {
                width: parent.width * 0.8
                height: width
                radius: width / 2
                x: Math.round((parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 150)
                y: Math.round((parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 100)
                opacity: 0.07
                color: root.ambientPrimary
                Behavior on color {
                    ColorAnimation {
                        duration: 1000
                    }
                }
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: Math.round((parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150)
                y: Math.round((parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100)
                opacity: 0.05
                color: root.ambientSecondary
                Behavior on color {
                    ColorAnimation {
                        duration: 1000
                    }
                }
            }

            Text {
                id: archParallaxIcon
                anchors.centerIn: archBaseSection
                anchors.verticalCenterOffset: -30
                property real drift: 0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    running: ThemePkg.Theme.edgeAnimationsEnabled
                    NumberAnimation {
                        to: -12
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }
                }
                transform: Translate {
                    y: archParallaxIcon.drift
                }
                text: "󰣇"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 490
                color: root.accent
                opacity: 0.04 + (0.015 * Math.sin(root.globalOrbitAngle * 4))
                z: 0
            }

            Item {
                anchors.fill: archBaseSection
                anchors.bottomMargin: 120
                Repeater {
                    model: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200 + (index * 140)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: root.accent
                        border.width: 1
                        opacity: 0.06 - (index * 0.015)
                    }
                }
            }

            Item {
                id: topBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.panelContentMargin
                height: 52
                z: 5

                transform: Translate {
                    y: -15 * (1.0 - introState)
                }
                opacity: introState

                Row {
                    id: uptimeRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Rectangle {
                        width: 42
                        height: 46
                        radius: 10
                        color: "#0dffffff"
                        border.color: "#1affffff"
                        border.width: 1
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: root.ambientPrimary
                            opacity: 0.05
                            Behavior on color {
                                ColorAnimation {
                                    duration: 1000
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            Text {
                                text: root.upHours.toString().padStart(2, '0')
                                font.pixelSize: 17
                                font.family: root.textFont
                                font.weight: Font.Black
                                color: root.ambientPrimary
                                anchors.horizontalCenter: parent.horizontalCenter
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 1000
                                    }
                                }
                            }
                            Text {
                                text: "HR"
                                font.pixelSize: 7
                                font.family: root.textFont
                                font.weight: Font.Bold
                                color: root.subtext0
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.pixelSize: 20
                        font.family: root.textFont
                        font.weight: Font.Black
                        color: root.ambientPrimary
                        Behavior on color {
                            ColorAnimation {
                                duration: 1000
                            }
                        }
                        opacity: colonPulse1
                        property real colonPulse1: 1.0
                        SequentialAnimation on colonPulse1 {
                            loops: Animation.Infinite
                            running: ThemePkg.Theme.edgeAnimationsEnabled
                            NumberAnimation {
                                to: 0.2
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1.0
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                        }
                    }

                    Rectangle {
                        width: 42
                        height: 46
                        radius: 10
                        color: "#0dffffff"
                        border.color: "#1affffff"
                        border.width: 1
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: root.ambientSecondary
                            opacity: 0.05
                            Behavior on color {
                                ColorAnimation {
                                    duration: 1000
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            Text {
                                text: root.upMins.toString().padStart(2, '0')
                                font.pixelSize: 17
                                font.family: root.textFont
                                font.weight: Font.Black
                                color: root.ambientSecondary
                                anchors.horizontalCenter: parent.horizontalCenter
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 1000
                                    }
                                }
                            }
                            Text {
                                text: "MIN"
                                font.pixelSize: 7
                                font.family: root.textFont
                                font.weight: Font.Bold
                                color: root.subtext0
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.pixelSize: 20
                        font.family: root.textFont
                        font.weight: Font.Black
                        color: root.ambientSecondary
                        Behavior on color {
                            ColorAnimation {
                                duration: 1000
                            }
                        }
                        opacity: colonPulse2
                        property real colonPulse2: 1.0
                        SequentialAnimation on colonPulse2 {
                            loops: Animation.Infinite
                            running: ThemePkg.Theme.edgeAnimationsEnabled
                            NumberAnimation {
                                to: 0.2
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1.0
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                        }
                    }

                    Rectangle {
                        width: 42
                        height: 46
                        radius: 10
                        color: "#0dffffff"
                        border.color: "#1affffff"
                        border.width: 1
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: root.accent2
                            opacity: 0.05
                            Behavior on color {
                                ColorAnimation {
                                    duration: 1000
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            Text {
                                text: root.upSecs.toString().padStart(2, '0')
                                font.pixelSize: 17
                                font.family: root.textFont
                                font.weight: Font.Black
                                color: root.accent2
                                anchors.horizontalCenter: parent.horizontalCenter
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 1000
                                    }
                                }
                            }
                            Text {
                                text: "SEC"
                                font.pixelSize: 7
                                font.family: root.textFont
                                font.weight: Font.Bold
                                color: root.subtext0
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                MouseArea {
                    id: uptimeMa
                    anchors.fill: uptimeRow
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "focustime", "toggle"])
                }

                HoverToolTip {
                    visible: uptimeMa.containsMouse
                    delay: 250
                    parent: topBar
                    x: Math.max(0, Math.min(topBar.width - implicitWidth, uptimeRow.x + Math.round((uptimeRow.width - implicitWidth) / 2)))
                    y: uptimeRow.y + uptimeRow.height + 6
                    text: "Focus Time"
                }

                Column {
                    id: toolBtnBlock
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 6

                    Row {
                        spacing: 6
                        anchors.right: parent.right
                        ToolBtn {
                            icon: "󰄡"
                            tip: "KDE Connect"
                            isActive: root.switcher && root.switcher.shownOverlay === "kdeconnect"
                            onBtnClicked: {
                                Quickshell.execDetached(["qs", "ipc", "call", "kdeconnect", "toggle"]);
                            }
                        }
                        ToolBtn {
                            icon: "󰍹"
                            tip: "Monitor Config"
                            onBtnClicked: {
                                Quickshell.execDetached(["qs", "ipc", "call", "monitor", "toggle"]);
                            }
                        }
                        ToolBtn {
                            icon: "󰅇"
                            tip: "Clipboard History"
                            onBtnClicked: {
                                ThemePkg.Theme.globalCloseAllPopups();
                                Quickshell.execDetached(["qs", "ipc", "call", "cliphist", "showAt", "0"]);
                            }
                        }
                        ToolBtn {
                            icon: "󰎕"
                            tip: "Arch News"
                            onBtnClicked: {
                                ThemePkg.Theme.globalCloseAllPopups();
                                Quickshell.execDetached(["xdg-open", "https://archlinux.org/news/"]);
                                root.unreadNews = 0;
                                root.saveCache(true);
                                Quickshell.execDetached(["bash", "-lc", root.scriptRunCommand("arch-news.py", ["--clear"])]);
                            }

                            Rectangle {
                                id: archNewsBadge
                                visible: root.unreadNews > 0
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom

                                readonly property real badgeDiameter: 20
                                readonly property real arcInset: parent.radius * (1 - Math.SQRT1_2)
                                anchors.rightMargin: Math.round(arcInset - (width / 2))
                                anchors.bottomMargin: Math.round(arcInset - (height / 2))
                                width: Math.max(badgeDiameter, archNewsBadgeText.implicitWidth + 10)
                                height: badgeDiameter
                                radius: height / 2
                                color: root.red
                                border.color: root.base
                                border.width: 1
                                z: 3

                                Text {
                                    id: archNewsBadgeText
                                    anchors.fill: parent
                                    text: root.unreadNews > 99 ? "99+" : String(root.unreadNews)
                                    color: ThemePkg.Theme.c15
                                    z: 1
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    renderType: Text.NativeRendering
                                    font.pixelSize: Math.round(parent.height * 0.5)
                                    font.family: root.textFont
                                    font.weight: Font.Black
                                }
                            }
                        }
                        ToolBtn {
                            icon: "󰊢"
                            tip: "Hyprdots Updates"
                            onBtnClicked: root.applyHyprdotsUpdates()

                            Rectangle {
                                id: dotfilesBadge
                                visible: root.unreadDotfiles > 0
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom

                                readonly property real badgeDiameter: 20
                                readonly property real arcInset: parent.radius * (1 - Math.SQRT1_2)
                                anchors.rightMargin: Math.round(arcInset - (width / 2))
                                anchors.bottomMargin: Math.round(arcInset - (height / 2))
                                width: Math.max(badgeDiameter, dotfilesBadgeText.implicitWidth + 10)
                                height: badgeDiameter
                                radius: height / 2
                                color: root.red
                                border.color: root.base
                                border.width: 1
                                z: 3

                                Text {
                                    id: dotfilesBadgeText
                                    anchors.fill: parent
                                    text: root.unreadDotfiles > 99 ? "99+" : String(root.unreadDotfiles)
                                    color: ThemePkg.Theme.c15
                                    z: 1
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    renderType: Text.NativeRendering
                                    font.pixelSize: Math.round(parent.height * 0.5)
                                    font.family: root.textFont
                                    font.weight: Font.Black
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.right: parent.right
                        ToolBtn {
                            icon: "WIP"
                            tip: "WIP"
                        }
                        ToolBtn {
                            icon: "󰂚"
                            tip: "Notification Sound Settings"
                            onBtnClicked: {
                                Quickshell.execDetached(["qs", "ipc", "call", "notificationsound", "toggle"]);
                            }
                        }
                        ToolBtn {
                            icon: "󰸉"
                            tip: "Wallpaper Picker"
                            onBtnClicked: {
                                Quickshell.execDetached(["qs", "ipc", "call", "wallpaper", "toggle"]);
                            }
                        }
                        ToolBtn {
                            icon: "󰌌"
                            tip: "Keybindings"
                            onBtnClicked: {
                                Quickshell.execDetached(["qs", "ipc", "call", "keybindings", "toggle"]);
                            }
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.right: parent.right
                        ToolBtn {
                            icon: "󰏘"
                            tip: "HyprGRUB Background"
                            onBtnClicked: {
                                profileSettingsPopup.activePickerMode = 2;
                                root.openSddmPicker();
                            }
                        }
                        ToolBtn {
                            id: borderAnimationsBtn
                            icon: "FX"
                            tip: ThemePkg.Theme.edgeAnimationsEnabled ? "Animations ON" : "Animations OFF"
                            isActive: !ThemePkg.Theme.edgeAnimationsEnabled
                            activeColor: ThemePkg.Theme.danger
                            requireHold: true
                            onBtnClicked: {
                                ThemePkg.Theme.edgeAnimationsEnabled = !ThemePkg.Theme.edgeAnimationsEnabled;
                                root.notifyArchTools("Animations", ThemePkg.Theme.edgeAnimationsEnabled ? "Animations enabled" : "Animations disabled", "video-display");
                            }
                        }
                        ToolBtn {
                            icon: ""
                            tip: "Hyprland Settings"
                            onBtnClicked: {
                                root.openHyprlandSettings();
                            }
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.right: parent.right
                        ToolBtn {
                            icon: "󰙽"
                            tip: "SDDM Customization"
                            onBtnClicked: {
                                profileSettingsPopup.showPopup();
                            }
                        }
                        ToolBtn {
                            id: autolockBtn
                            icon: root.autolockDisabled ? "󰌿" : "󰌾"
                            tip: root.autolockDisabled ? "Autolock OFF" : "Autolock ON"
                            isActive: root.autolockDisabled
                            activeColor: ThemePkg.Theme.danger
                            requireHold: true
                            onBtnClicked: {
                                root.autolockNotificationPending = true;
                                root.autolockNotificationNotBefore = Date.now() + 300;
                                Quickshell.execDetached(["bash", "-lc", root.hypridleScript]);
                                autolockRecheck.start();
                            }
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.right: parent.right
                        ToolBtn {
                            icon: "󰖨"
                            tip: "OpenWeather Settings"
                            onBtnClicked: root.openWeatherSettings()
                        }
                    }
                }
            }

            Item {
                id: updateCenter
                anchors.top: topBar.bottom
                anchors.topMargin: 5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: resourceSep.top
                anchors.bottomMargin: 5
                z: 2

                Canvas {
                    id: lightningCanvas
                    anchors.fill: parent
                    z: 0

                    Timer {
                        interval: ThemePkg.Theme.edgeAnimationsEnabled ? 45 : 500
                        running: true
                        repeat: true
                        onTriggered: lightningCanvas.requestPaint()
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var time = Date.now() / 1000;
                        ctx.lineJoin = "round";
                        ctx.lineCap = "round";

                        var cx = width / 2;
                        var cy = height / 2;
                        var coreW = centralUpdateCore.width;

                        for (var i = 0; i < orbitRepeater.count; i++) {
                            var item = orbitRepeater.itemAt(i);
                            if (!item)
                                continue;

                            var targetX = item.x + item.width / 2;
                            var targetY = item.y + item.height / 2;
                            var startX = cx;
                            var startY = cy;

                            var dx = targetX - startX;
                            var dy = targetY - startY;
                            var fullDist = Math.sqrt(dx * dx + dy * dy);
                            if (fullDist < 10)
                                continue;

                            var alpha = Math.atan2(dy, dx);
                            var cosA = Math.cos(alpha);
                            var sinA = Math.sin(alpha);
                            var perpX = -sinA;
                            var perpY = cosA;

                            var startOffset = coreW / 2 + 5;
                            var endOffset = item.width / 2 + 5;
                            var drawDist = fullDist - startOffset - endOffset;
                            if (drawDist <= 0)
                                continue;

                            var sX = startX + cosA * startOffset;
                            var sY = startY + sinA * startOffset;
                            var steps = 8;
                            var time = ThemePkg.Theme.edgeAnimationsEnabled ? (Date.now() / 1000) : 0;
                            var randAmp = ThemePkg.Theme.edgeAnimationsEnabled ? 1 : 0;
                            var tWave1 = time * 2.5;

                            var distanceFactor = Math.max(0, 1.0 - (fullDist / 500.0));

                            ctx.beginPath();
                            ctx.moveTo(sX, sY);
                            for (var j = 1; j <= steps; j++) {
                                var t = j / steps;
                                var currentDist = drawDist * t;
                                var envelope = Math.sin(t * Math.PI);
                                var offset = Math.sin(tWave1 + t * 6) * 6 * envelope + ((Math.random() - 0.5) * 5.0 * distanceFactor * randAmp);
                                ctx.lineTo(sX + cosA * currentDist + perpX * offset, sY + sinA * currentDist + perpY * offset);
                            }
                            ctx.lineWidth = 4.0 + (distanceFactor * 4.0);
                            ctx.strokeStyle = root.accent.toString();
                            ctx.globalAlpha = (0.2 + (distanceFactor * 0.7)) * 0.15;
                            ctx.stroke();

                            ctx.lineWidth = 1.0 + (distanceFactor * 2.0);
                            ctx.strokeStyle = "#ffffff";
                            ctx.globalAlpha = 0.2 + (distanceFactor * 0.7);
                            ctx.stroke();

                            ctx.beginPath();
                            ctx.moveTo(sX, sY);
                            for (var k = 1; k <= steps; k++) {
                                var tk = k / steps;
                                var currentDistK = drawDist * tk;
                                var envelopeK = Math.sin(tk * Math.PI);
                                var offsetK = Math.cos(tWave1 * -0.6 + tk * 8) * 12 * envelopeK + ((Math.random() - 0.5) * 3.0 * distanceFactor * randAmp);
                                ctx.lineTo(sX + cosA * currentDistK + perpX * offsetK, sY + sinA * currentDistK + perpY * offsetK);
                            }
                            ctx.lineWidth = (1.0 + (distanceFactor * 2.0)) * 1.5;
                            ctx.strokeStyle = root.accent.toString();
                            ctx.globalAlpha = (0.2 + (distanceFactor * 0.7)) * 0.3;
                            ctx.stroke();
                        }
                    }
                }

                Item {
                    id: centralUpdateCore
                    width: 150
                    height: 150
                    anchors.centerIn: parent
                    z: 3

                    UpdateBubble {
                        anchors.fill: parent
                        compact: false
                        value: root.updateRunning ? root.progressLabel(root.updateProgress) : (root.updateShowStatus ? root.updateStatusIcon(root.updateStatus) : String(root.updTotal))
                        label: root.updateShowStatus ? root.updateStatusText() : "updates"
                        isUpdateRunning: root.updateRunning
                        isUpdateResult: root.updateResultVisible
                        isUpdateError: root.updateHadError
                        updateProgress: root.updateProgress
                        onHoldComplete: {
                            root.startBackgroundUpdate("all");
                        }
                        onHoldCompleteRight: {
                            root.openUpdatesList("All Updates", "all", root.updatesListAllScript);
                        }
                        onClicked: {
                            root.openUpdateOutputShell();
                        }
                        onCancelRequested: {
                            root.cancelRunningUpdate();
                        }
                    }
                }

                Repeater {
                    id: orbitRepeater
                    model: [
                        {
                            label: "pacman",
                            count: function () {
                                return root.updPacman;
                            },
                            listScript: root.updatesListPacmanScript
                        },
                        {
                            label: "yay",
                            count: function () {
                                return root.updAur;
                            },
                            listScript: root.updatesListAurScript
                        },
                        {
                            label: "flatpak",
                            count: function () {
                                return root.updFlatpak;
                            },
                            listScript: root.updatesListFlatpakScript
                        }
                    ]
                    delegate: Item {
                        id: orbitItem
                        width: 84
                        height: 84
                        z: 2

                        property real baseAngle: (index / 3) * Math.PI * 2
                        property real liveAngle: root.globalOrbitAngle * 1.5 + baseAngle
                        property real orbitRadX: 235
                        property real orbitRadY: 168

                        x: Math.round((updateCenter.width / 2 - width / 2) + Math.cos(liveAngle) * orbitRadX)
                        y: Math.round((updateCenter.height / 2 - height / 2) + Math.sin(liveAngle) * orbitRadY)

                        UpdateBubble {
                            anchors.fill: parent
                            compact: true
                            property string providerStatus: root.updateShowStatus ? root.providerStageStatus(modelData.label) : ""
                            property real providerProgressValue: root.providerProgress(modelData.label)
                            property bool providerActive: root.isActiveProviderStatus(providerStatus)
                            property bool providerTerminal: root.isTerminalUpdateStatus(providerStatus)
                            value: providerActive ? root.progressLabel(providerProgressValue) : (providerStatus ? root.updateStatusIcon(providerStatus) : String(modelData.count()))
                            label: providerStatus ? root.providerStatusLabel(providerStatus, providerProgressValue) : modelData.label
                            isUpdateRunning: root.updateRunning && providerActive
                            isUpdateResult: providerTerminal || (root.updateResultVisible && providerStatus !== "")
                            isUpdateError: providerStatus === "error"
                            updateProgress: providerProgressValue
                            onHoldComplete: {
                                root.startBackgroundUpdate(modelData.label === "yay" ? "aur" : modelData.label);
                            }
                            onHoldCompleteRight: {
                                root.openUpdatesList(modelData.label.toUpperCase() + " Updates", modelData.label, modelData.listScript);
                            }
                            onClicked: {
                                root.openUpdateOutputShell();
                            }
                            onCancelRequested: {
                                root.cancelRunningUpdate();
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: resourceSep
                anchors.bottom: resourceRow.top
                anchors.bottomMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.panelContentMargin
                anchors.rightMargin: root.panelContentMargin
                height: 1
                color: ThemePkg.Theme.withAlpha(root.text, root.detailsOpen ? 0.12 : 0.0)
                z: 3
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            Row {
                id: resourceRow
                anchors.bottom: archBaseSection.bottom
                anchors.bottomMargin: 22
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.panelContentMargin
                anchors.rightMargin: root.panelContentMargin
                spacing: root.resourceCardSpacing
                z: 3

                transform: Translate {
                    y: 20 * (1.0 - introState)
                }
                opacity: introState

                ResCard {
                    resourceKey: "cpu"
                    title: "CPU"
                    value: Math.round(root.displayedCpuTotal()) + "%"
                    tip: root.statCpuCores.length ? "Per-core:\n" + root.statCpuCores.map(function (v, i) {
                        return "C" + i + ": " + Math.round(v) + "%";
                    }).join("   ") : "Collecting..."
                    selected: root.expandedResourceKey === resourceKey
                    accentColor: root.resourceAccent(resourceKey)
                    onCardTriggered: root.openResourceDetails(resourceKey)
                }
                ResCard {
                    resourceKey: "ram"
                    title: "RAM"
                    value: root.statMemUsed.toFixed(1) + "/" + root.statMemTotal.toFixed(1) + " GB"
                    tip: "Used: " + root.statMemUsed.toFixed(1) + " / " + root.statMemTotal.toFixed(1) + " GB (" + Math.round(root.statMemPercent) + "%)"
                    selected: root.expandedResourceKey === resourceKey
                    accentColor: root.resourceAccent(resourceKey)
                    onCardTriggered: root.openResourceDetails(resourceKey)
                }
                ResCard {
                    resourceKey: "disk"
                    title: "DISK"
                    value: root.statDiskOsPercent.toFixed(1) + "%"
                    tip: (root.statDiskOsName || "OS disk") + ": " + root.statDiskOsPercent.toFixed(1) + "% used\n/: " + root.statDiskRoot + "% used\n/home: " + root.statDiskHome + "% used\n/home free: " + root.formatBytes(root.statDiskHomeFree)
                    selected: root.expandedResourceKey === resourceKey
                    accentColor: root.resourceAccent(resourceKey)
                    onCardTriggered: root.openResourceDetails(resourceKey)
                }
                ResCard {
                    resourceKey: "gpu"
                    title: "GPU"
                    value: Math.round(root.statGpuTotal) + "%"
                    tip: (root.statGpuDetail && root.statGpuDetail.length) ? root.statGpuDetail.map(function (d) {
                        return d.name + ": " + Math.round(d.percent) + "%";
                    }).join("\n") : (root.statGpuName ? root.statGpuName + ": " + Math.round(root.statGpuTotal) + "%" : "No GPU data")
                    selected: root.expandedResourceKey === resourceKey
                    accentColor: root.resourceAccent(resourceKey)
                    onCardTriggered: root.openResourceDetails(resourceKey)
                }
                ResCard {
                    resourceKey: "net"
                    title: "NET"
                    value: root.formatRate(root.displayedNetValue("total_bps", root.statNetTotal))
                    tip: (root.statNetIface ? root.statNetIface + "\n" : "") + "Down: " + root.formatRate(root.displayedNetValue("down_bps", root.statNetDown)) + "\nUp: " + root.formatRate(root.displayedNetValue("up_bps", root.statNetUp))
                    selected: root.expandedResourceKey === resourceKey
                    accentColor: root.resourceAccent(resourceKey)
                    onCardTriggered: root.openResourceDetails(resourceKey)
                }
            }

            Rectangle {
                id: detailsSep
                anchors.top: resourceRow.bottom
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.panelContentMargin
                anchors.rightMargin: root.panelContentMargin
                height: 1
                color: ThemePkg.Theme.withAlpha(root.text, root.detailsOpen ? 0.18 : 0.0)
                z: 3
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            Item {
                id: detailsViewport
                anchors.top: detailsSep.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.panelContentMargin
                anchors.rightMargin: root.panelContentMargin
                readonly property real viewportPadding: 16
                readonly property real contentViewportHeight: Math.max(0, height - (viewportPadding * 2))
                readonly property bool needsScroll: detailsColumn.implicitHeight > contentViewportHeight + 1
                readonly property real targetHeight: root.detailsOpen ? Math.min(root.maxExpandedDetailsHeight, detailsColumn.implicitHeight + (viewportPadding * 2)) : 0
                height: targetHeight
                opacity: root.detailsContentOpacity
                clip: true
                z: 4
                visible: height > 0 || opacity > 0.01
                transform: [
                    Scale {
                        origin.x: detailsViewport.width / 2
                        origin.y: 0
                        xScale: root.detailsPanelScale
                        yScale: root.detailsPanelScale
                    },
                    Translate {
                        y: root.detailsPanelOffset
                    }
                ]

                Behavior on height {
                    enabled: !root.detailsOpen || !root.detailObject(root.visibleDetailsKey)
                    NumberAnimation {
                        duration: root.detailsOpen ? root.detailsExpandDuration : root.detailsCollapseDuration
                        easing.type: root.detailsOpen ? Easing.OutCubic : Easing.InOutCubic
                    }
                }

                Rectangle {
                    id: detailsBg
                    anchors.fill: parent
                    radius: 18
                    color: ThemePkg.Theme.withAlpha(root.mantle, 0.94)
                    border.width: 1
                    border.color: ThemePkg.Theme.withAlpha(root.resourceAccent(root.visibleDetailsKey), 0.45)
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: detailsBg
                    }

                    Rectangle {
                        width: parent.width * 0.60
                        height: width
                        radius: width / 2
                        x: -width * 0.20 + Math.cos(root.globalOrbitAngle * 1.7) * 42
                        y: -height * 0.22 + Math.sin(root.globalOrbitAngle * 1.4) * 18
                        color: root.resourceAccent(root.visibleDetailsKey)
                        opacity: 0.08
                    }

                    Rectangle {
                        width: parent.width * 0.52
                        height: width
                        radius: width / 2
                        x: parent.width - width * 0.72 + Math.sin(root.globalOrbitAngle * 1.1) * 34
                        y: parent.height - height * 0.62 + Math.cos(root.globalOrbitAngle * 1.3) * 16
                        color: root.ambientSecondary
                        opacity: 0.06
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 14
                        text: "󰣇"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 190
                        color: root.resourceAccent(root.visibleDetailsKey)
                        opacity: 0.035
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: ThemePkg.Theme.withAlpha("#ffffff", 0.08)
                    }
                }

                Flickable {
                    id: detailsFlick
                    anchors.fill: parent
                    anchors.margins: detailsViewport.viewportPadding
                    y: root.detailsContentOffset
                    contentWidth: width
                    contentHeight: detailsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: detailsViewport.needsScroll

                    ThemePkg.FastScrollHandler {
                        anchors.fill: parent
                        flickable: detailsFlick
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: detailsScrollBar
                        policy: detailsViewport.needsScroll ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                        hoverEnabled: true
                        implicitWidth: 10
                        minimumSize: 0.08
                        active: hovered || pressed || detailsFlick.moving

                        background: Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.moduleBorderColor
                            border.color: root.moduleBorderColor
                            opacity: detailsScrollBar.active ? 1.0 : 0.7
                        }

                        contentItem: Rectangle {
                            radius: width / 2
                            border.width: 1
                            border.color: root.moduleBorderColor
                            color: root.resourceAccent(root.visibleDetailsKey)
                        }
                    }

                    Column {
                        id: detailsColumn
                        width: detailsFlick.width - (detailsViewport.needsScroll ? detailsScrollBar.width + 8 : 0)
                        spacing: 14

                        Row {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                width: 46
                                height: 46
                                radius: 14
                                color: ThemePkg.Theme.withAlpha(root.resourceAccent(root.visibleDetailsKey), 0.16)
                                border.width: 1
                                border.color: ThemePkg.Theme.withAlpha(root.resourceAccent(root.visibleDetailsKey), 0.45)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.resourceIcon(root.visibleDetailsKey)
                                    color: root.resourceAccent(root.visibleDetailsKey)
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 22
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 58
                                spacing: 2

                                Text {
                                    text: root.resourceTitle(root.visibleDetailsKey) + " deep monitor"
                                    color: root.text
                                    font.pixelSize: 18
                                    font.family: root.textFont
                                    font.weight: Font.Black
                                }
                            }
                        }

                        Loader {
                            id: detailsLoader
                            width: parent.width
                            sourceComponent: root.expandedResourceError !== "" ? detailErrorComp : (root.expandedResourceLoading && !root.detailObject(root.visibleDetailsKey) ? detailLoadingComp : root.detailComponentForKey(root.visibleDetailsKey))
                        }
                    }
                }
            }
        }
    }

    Item {
        id: authPopup
        anchors.fill: parent
        z: 101
        visible: popupMounted
        focus: true

        property bool popupMounted: false
        property bool popupTargetVisible: false
        property real popupCardOpacity: 0.0
        property real popupCardScaleX: 0.42
        property real popupCardScaleY: 0.24
        property real popupCardWidth: 406
        property real popupCardHeight: 142
        property real popupCardRadius: 34
        property real popupCardLift: 8.5

        function showPopup() {
            popupMounted = true;
            popupTargetVisible = true;
            authPopupExitAnim.stop();
            popupCardOpacity = 0.0;
            popupCardScaleX = 0.42;
            popupCardScaleY = 0.24;
            popupCardWidth = 406;
            popupCardHeight = 142;
            popupCardRadius = 34;
            popupCardLift = 8.5;
            authPasswordField.text = "";
            root.authUnlockFillLevel = 0.0;
            root.authUnlockFlashOpacity = 0.0;
            root.authUnlockTriggered = false;
            authPopupEnterAnim.stop();
            authPopupEnterAnim.start();
            Qt.callLater(function () {
                authPasswordField.forceActiveFocus();
            });
        }

        function hidePopup() {
            popupTargetVisible = false;
            authPopupEnterAnim.stop();
            if (!popupMounted && popupCardOpacity <= 0.001) {
                archPanel.visible = true;
                return;
            }
            if (!authPopupExitAnim.running)
                authPopupExitAnim.start();
        }

        Keys.onReleased: e => {
            if (e.key === Qt.Key_Escape) {
                root.cancelAuthPassword();
                e.accepted = true;
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.completeAuthUnlock();
                e.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelAuthPassword()
        }

        Item {
            id: authPopupShell
            width: authPopup.popupCardWidth
            height: authPopup.popupCardHeight
            anchors.centerIn: parent
            opacity: authPopup.popupCardOpacity
            transform: [
                Scale {
                    origin.x: authPopupShell.width / 2
                    origin.y: authPopupShell.height / 2
                    xScale: authPopup.popupCardScaleX
                    yScale: authPopup.popupCardScaleY
                },
                Translate {
                    y: authPopup.popupCardLift
                }
            ]

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                radius: authPopup.popupCardRadius
                color: root.base
                border.color: root.panelBorderColor
                border.width: 1
                clip: true

                AnimatedBorder {
                    anchors.fill: parent
                    radius: parent.radius
                    borderWidth: parent.border.width
                    accentColor: root.activeColor
                    active: authPopup.popupMounted
                }

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0
                    to: Math.PI * 2
                    duration: 90000
                    loops: Animation.Infinite
                    running: authPopup.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                }

                Rectangle {
                    width: parent.width * 0.72
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.58 - width / 2) + Math.cos(parent.globalOrbitAngle * 1.5) * 70
                    y: (parent.height * 0.05 - height / 2) + Math.sin(parent.globalOrbitAngle * 1.5) * 80
                    opacity: 0.05
                    color: root.accent
                }

                Rectangle {
                    width: parent.width * 0.55
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.12 - width / 2) + Math.sin(parent.globalOrbitAngle * 1.2) * -52
                    y: (parent.height * 0.82 - height / 2) + Math.cos(parent.globalOrbitAngle * 1.2) * -64
                    opacity: 0.035
                    color: ThemePkg.Theme.c5
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    text: "󰌾"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 210
                    color: root.accent
                    opacity: 0.035
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 25
                    anchors.rightMargin: 25
                    anchors.topMargin: 25
                    anchors.bottomMargin: 25
                    spacing: 10
                    z: 1

                    TextField {
                        id: authPasswordField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        placeholderText: "Password"
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: root.text
                        placeholderTextColor: root.overlay1
                        font.family: root.textFont
                        font.pixelSize: 14
                        padding: 10
                        leftPadding: 42
                        Keys.onEscapePressed: root.cancelAuthPassword()
                        onAccepted: root.completeAuthUnlock()
                        background: Rectangle {
                            color: "#0dffffff"
                            border.color: authPasswordField.activeFocus ? root.accent : "#1affffff"
                            border.width: 1
                            radius: 10
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 13
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            font.family: "CaskaydiaMono Nerd Font"
                            font.pixelSize: 16
                            color: authPasswordField.activeFocus ? root.accent : root.overlay1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: root.authStatus
                            color: root.authStatus === "Password required" || root.authStatus === "Unable to send password" ? root.red : root.subtext0
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 38
                            radius: 10
                            color: root.authSubmitHovered ? ThemePkg.Theme.withAlpha(root.accent, 0.86) : ThemePkg.Theme.withAlpha(root.accent, 0.70)
                            border.color: ThemePkg.Theme.withAlpha(root.accent, 0.95)
                            border.width: 1
                            scale: root.authSubmitPressed ? 0.94 : (root.authSubmitHovered ? 1.04 : 1.0)
                            clip: true

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutBack
                                }
                            }

                            Canvas {
                                id: authUnlockWaveCanvas
                                anchors.fill: parent
                                visible: root.authUnlockFillLevel > 0.0
                                opacity: 0.92
                                property real wavePhase: 0.0

                                NumberAnimation on wavePhase {
                                    running: root.authUnlockFillLevel > 0.0 && root.authUnlockFillLevel < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                                    loops: Animation.Infinite
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 800
                                }

                                onWavePhaseChanged: requestPaint()
                                Connections {
                                    target: root
                                    function onAuthUnlockFillLevelChanged() {
                                        authUnlockWaveCanvas.requestPaint();
                                    }
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (root.authUnlockFillLevel <= 0.001)
                                        return;

                                    var currentW = width * root.authUnlockFillLevel;
                                    var waveAmpBase = 10 * Math.sin(root.authUnlockFillLevel * Math.PI);
                                    var waveAmp = Math.min(Math.max(0, currentW), waveAmpBase);
                                    var r = 10;

                                    ctx.save();
                                    ctx.beginPath();
                                    ctx.moveTo(r, 0);
                                    ctx.lineTo(width - r, 0);
                                    ctx.arcTo(width, 0, width, r, r);
                                    ctx.lineTo(width, height - r);
                                    ctx.arcTo(width, height, width - r, height, r);
                                    ctx.lineTo(r, height);
                                    ctx.arcTo(0, height, 0, height - r, r);
                                    ctx.lineTo(0, r);
                                    ctx.arcTo(0, 0, r, 0, r);
                                    ctx.closePath();
                                    ctx.clip();

                                    ctx.beginPath();
                                    ctx.moveTo(0, 0);
                                    if (root.authUnlockFillLevel < 0.99) {
                                        var cp1x = currentW + Math.sin(authUnlockWaveCanvas.wavePhase) * waveAmp;
                                        var cp2x = currentW + Math.cos(authUnlockWaveCanvas.wavePhase + Math.PI) * waveAmp;
                                        ctx.lineTo(currentW, 0);
                                        ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                                        ctx.lineTo(0, height);
                                    } else {
                                        ctx.lineTo(width, 0);
                                        ctx.lineTo(width, height);
                                        ctx.lineTo(0, height);
                                    }
                                    ctx.closePath();

                                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, root.surface1.toString());
                                    grad.addColorStop(1, root.crust.toString());
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    ctx.restore();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "#ffffff"
                                opacity: root.authUnlockFlashOpacity
                            }

                            Text {
                                anchors.centerIn: parent
                                text: authSubmitProc.running ? "Unlocking" : "Unlock"
                                color: root.authUnlockFillLevel > 0.05 ? root.text : root.crust
                                font.family: root.textFont
                                font.pixelSize: 13
                                font.weight: Font.Black
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.authSubmitHovered = true
                                onExited: root.authSubmitHovered = false
                                onPressed: {
                                    if (authSubmitProc.running)
                                        return;
                                    root.authSubmitPressed = true;
                                    if (!root.authUnlockTriggered) {
                                        authUnlockDrainAnim.stop();
                                        authUnlockFillAnim.start();
                                    }
                                }
                                onReleased: {
                                    root.authSubmitPressed = false;
                                    if (!root.authUnlockTriggered && root.authUnlockFillLevel < 1.0) {
                                        authUnlockFillAnim.stop();
                                        authUnlockDrainAnim.start();
                                    }
                                }
                                onCanceled: {
                                    root.authSubmitPressed = false;
                                    if (!root.authUnlockTriggered) {
                                        authUnlockFillAnim.stop();
                                        authUnlockDrainAnim.start();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: weatherSettingsPopup
        anchors.fill: parent
        z: 99
        visible: popupMounted
        focus: true

        property bool popupMounted: false
        property bool popupTargetVisible: false
        property real popupCardOpacity: 0.0
        property real popupCardScaleX: 0.42
        property real popupCardScaleY: 0.24
        property real popupCardWidth: 460
        property real popupCardHeight: 253
        property real popupCardRadius: 34
        property real popupCardLift: 8.5
        readonly property real contentMargin: 25
        readonly property real borderedSpacing: 15

        function showPopup() {
            popupMounted = true;
            popupTargetVisible = true;
            weatherSettingsPopupExitAnim.stop();
            popupCardOpacity = 0.0;
            popupCardScaleX = 0.42;
            popupCardScaleY = 0.24;
            popupCardWidth = 460;
            popupCardHeight = 253;
            popupCardRadius = 34;
            popupCardLift = 8.5;
            weatherSettingsPopupEnterAnim.stop();
            weatherSettingsPopupEnterAnim.start();
            Qt.callLater(function () {
                weatherKeyField.forceActiveFocus();
            });
        }

        function hidePopup() {
            popupTargetVisible = false;
            weatherSettingsPopupEnterAnim.stop();
            if (!popupMounted && popupCardOpacity <= 0.001) {
                archPanel.visible = true;
                return;
            }
            if (!weatherSettingsPopupExitAnim.running)
                weatherSettingsPopupExitAnim.start();
        }

        Keys.onReleased: e => {
            if (e.key === Qt.Key_Escape) {
                weatherSettingsPopup.hidePopup();
                e.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: weatherSettingsPopup.hidePopup()
        }

        Item {
            id: weatherPopupShell
            width: weatherSettingsPopup.popupCardWidth
            height: weatherSettingsPopup.popupCardHeight
            anchors.centerIn: parent
            opacity: weatherSettingsPopup.popupCardOpacity
            transform: [
                Scale {
                    origin.x: weatherPopupShell.width / 2
                    origin.y: weatherPopupShell.height / 2
                    xScale: weatherSettingsPopup.popupCardScaleX
                    yScale: weatherSettingsPopup.popupCardScaleY
                },
                Translate {
                    y: weatherSettingsPopup.popupCardLift
                }
            ]

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                radius: weatherSettingsPopup.popupCardRadius
                color: root.base
                border.color: root.panelBorderColor
                border.width: 1
                clip: true

                AnimatedBorder {
                    anchors.fill: parent
                    radius: parent.radius
                    borderWidth: parent.border.width
                    accentColor: root.activeColor
                    active: weatherSettingsPopup.popupMounted
                }

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0
                    to: Math.PI * 2
                    duration: 90000
                    loops: Animation.Infinite
                    running: weatherSettingsPopup.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                }

                Rectangle {
                    width: parent.width * 0.72
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.58 - width / 2) + Math.cos(parent.globalOrbitAngle * 1.5) * 70
                    y: (parent.height * 0.05 - height / 2) + Math.sin(parent.globalOrbitAngle * 1.5) * 80
                    opacity: 0.05
                    color: root.accent
                }

                Rectangle {
                    width: parent.width * 0.55
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.12 - width / 2) + Math.sin(parent.globalOrbitAngle * 1.2) * -52
                    y: (parent.height * 0.82 - height / 2) + Math.cos(parent.globalOrbitAngle * 1.2) * -64
                    opacity: 0.035
                    color: ThemePkg.Theme.c5
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    text: "󰖨"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 240
                    color: root.accent
                    opacity: 0.035
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: weatherSettingsPopup.contentMargin
                    spacing: weatherSettingsPopup.borderedSpacing
                    z: 1

                    TextField {
                        id: weatherKeyField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "OpenWeather API key"
                        text: root.weatherApiKey
                        color: root.text
                        placeholderTextColor: root.overlay1
                        font.family: root.textFont
                        font.pixelSize: 14
                        padding: 8
                        leftPadding: 42
                        Keys.onEscapePressed: weatherSettingsPopup.hidePopup()
                        background: Rectangle {
                            color: "#0dffffff"
                            border.color: weatherKeyField.activeFocus ? root.accent : "#1affffff"
                            border.width: 1
                            radius: 10
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: weatherSettingsPopup.borderedSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            font.family: "CaskaydiaMono Nerd Font"
                            font.pixelSize: 16
                            color: weatherKeyField.activeFocus ? root.accent : root.overlay1
                        }
                    }

                    TextField {
                        id: weatherCityField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "OpenWeather city ID"
                        text: root.weatherCityId
                        color: root.text
                        placeholderTextColor: root.overlay1
                        font.family: root.textFont
                        font.pixelSize: 14
                        padding: 8
                        leftPadding: 42
                        Keys.onEscapePressed: weatherSettingsPopup.hidePopup()
                        background: Rectangle {
                            color: "#0dffffff"
                            border.color: weatherCityField.activeFocus ? root.accent : "#1affffff"
                            border.width: 1
                            radius: 10
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: weatherSettingsPopup.borderedSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍎"
                            font.family: "CaskaydiaMono Nerd Font"
                            font.pixelSize: 16
                            color: weatherCityField.activeFocus ? root.accent : root.overlay1
                        }
                    }

                    TextField {
                        id: weatherUnitField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "Unit: metric, imperial or standard"
                        text: root.weatherUnit
                        color: root.text
                        placeholderTextColor: root.overlay1
                        font.family: root.textFont
                        font.pixelSize: 14
                        padding: 8
                        leftPadding: 42
                        Keys.onEscapePressed: weatherSettingsPopup.hidePopup()
                        background: Rectangle {
                            color: "#0dffffff"
                            border.color: weatherUnitField.activeFocus ? root.accent : "#1affffff"
                            border.width: 1
                            radius: 10
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: weatherSettingsPopup.borderedSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰔏"
                            font.family: "CaskaydiaMono Nerd Font"
                            font.pixelSize: 16
                            color: weatherUnitField.activeFocus ? root.accent : root.overlay1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: weatherSettingsPopup.borderedSpacing

                        Text {
                            Layout.fillWidth: true
                            text: root.weatherSaveStatus
                            color: root.weatherSaveStatus === "Save failed" ? root.red : root.subtext0
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            Layout.preferredWidth: 108
                            Layout.preferredHeight: 38
                            property real saveRadius: 10
                            radius: 10
                            color: root.weatherSaveHovered ? ThemePkg.Theme.withAlpha(root.accent, 0.86) : ThemePkg.Theme.withAlpha(root.accent, 0.70)
                            border.color: ThemePkg.Theme.withAlpha(root.accent, 0.95)
                            border.width: 1
                            scale: root.weatherSavePressed ? 0.94 : (root.weatherSaveHovered ? 1.04 : 1.0)
                            clip: true

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutBack
                                }
                            }

                            Canvas {
                                id: weatherSaveWaveCanvas
                                anchors.fill: parent
                                visible: root.weatherSaveFillLevel > 0.0
                                opacity: 0.92
                                property real wavePhase: 0.0

                                NumberAnimation on wavePhase {
                                    running: root.weatherSaveFillLevel > 0.0 && root.weatherSaveFillLevel < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                                    loops: Animation.Infinite
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 800
                                }

                                onWavePhaseChanged: requestPaint()
                                Connections {
                                    target: root
                                    function onWeatherSaveFillLevelChanged() {
                                        weatherSaveWaveCanvas.requestPaint();
                                    }
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (root.weatherSaveFillLevel <= 0.001)
                                        return;

                                    var currentW = width * root.weatherSaveFillLevel;
                                    var waveAmpBase = 10 * Math.sin(root.weatherSaveFillLevel * Math.PI);
                                    var waveAmp = Math.min(Math.max(0, currentW), waveAmpBase);
                                    var r = 10;

                                    ctx.save();
                                    ctx.beginPath();
                                    ctx.moveTo(r, 0);
                                    ctx.lineTo(width - r, 0);
                                    ctx.arcTo(width, 0, width, r, r);
                                    ctx.lineTo(width, height - r);
                                    ctx.arcTo(width, height, width - r, height, r);
                                    ctx.lineTo(r, height);
                                    ctx.arcTo(0, height, 0, height - r, r);
                                    ctx.lineTo(0, r);
                                    ctx.arcTo(0, 0, r, 0, r);
                                    ctx.closePath();
                                    ctx.clip();

                                    ctx.beginPath();
                                    ctx.moveTo(0, 0);
                                    if (root.weatherSaveFillLevel < 0.99) {
                                        var cp1x = currentW + Math.sin(weatherSaveWaveCanvas.wavePhase) * waveAmp;
                                        var cp2x = currentW + Math.cos(weatherSaveWaveCanvas.wavePhase + Math.PI) * waveAmp;
                                        ctx.lineTo(currentW, 0);
                                        ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                                        ctx.lineTo(0, height);
                                    } else {
                                        ctx.lineTo(width, 0);
                                        ctx.lineTo(width, height);
                                        ctx.lineTo(0, height);
                                    }
                                    ctx.closePath();

                                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, root.surface1.toString());
                                    grad.addColorStop(1, root.crust.toString());
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    ctx.restore();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "#ffffff"
                                opacity: root.weatherSaveFlashOpacity
                            }

                            Text {
                                anchors.centerIn: parent
                                text: weatherEnvWriteProc.running ? "Saving" : "Save"
                                color: root.weatherSaveFillLevel > 0.05 ? root.text : root.crust
                                font.family: root.textFont
                                font.pixelSize: 13
                                font.weight: Font.Black
                            }

                            MouseArea {
                                id: weatherSaveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.weatherSaveHovered = true
                                onExited: root.weatherSaveHovered = false
                                onPressed: {
                                    if (weatherEnvWriteProc.running)
                                        return;
                                    root.weatherSavePressed = true;
                                    if (!root.weatherSaveTriggered) {
                                        weatherSaveDrainAnim.stop();
                                        weatherSaveFillAnim.start();
                                    }
                                }
                                onReleased: {
                                    root.weatherSavePressed = false;
                                    if (!root.weatherSaveTriggered && root.weatherSaveFillLevel < 1.0) {
                                        weatherSaveFillAnim.stop();
                                        weatherSaveDrainAnim.start();
                                    }
                                }
                                onCanceled: {
                                    root.weatherSavePressed = false;
                                    if (!root.weatherSaveTriggered) {
                                        weatherSaveFillAnim.stop();
                                        weatherSaveDrainAnim.start();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: updatesListPopup
        anchors.fill: parent
        z: 100
        visible: popupMounted
        property bool popupMounted: false
        property bool popupTargetVisible: false
        property real popupCardOpacity: 0.0
        property real popupCardScaleX: 0.42
        property real popupCardScaleY: 0.24
        property real popupCardWidth: 436
        property real popupCardHeight: 572
        property real popupCardRadius: 34
        property real popupCardLift: 8.5

        property string titleStr: ""
        property string managerType: ""
        property alias listModel: updatesListModel

        property int currentViewIndex: 0
        property string currentPackageName: ""
        property string packageDetailsText: ""
        property string fetchError: ""
        property string currentCacheKey: ""

        function showPopup() {
            popupMounted = true;
            popupTargetVisible = true;
            updatesListPopupExitAnim.stop();
            popupCardOpacity = 0.0;
            popupCardScaleX = 0.42;
            popupCardScaleY = 0.24;
            popupCardWidth = 436;
            popupCardHeight = 572;
            popupCardRadius = 34;
            popupCardLift = 8.5;
            updatesListPopupEnterAnim.stop();
            updatesListPopupEnterAnim.start();
            if (typeof updatesSearch !== "undefined") {
                updatesSearch.text = "";
                Qt.callLater(function () {
                    updatesSearch.forceActiveFocus();
                });
            } else {
                Qt.callLater(function () {
                    updatesListPopup.forceActiveFocus();
                });
            }
        }

        function hidePopup() {
            popupTargetVisible = false;
            updatesListPopupEnterAnim.stop();
            if (!popupMounted && popupCardOpacity <= 0.001) {
                archPanel.visible = true;
                currentViewIndex = 0;
                return;
            }
            if (!updatesListPopupExitAnim.running)
                updatesListPopupExitAnim.start();
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                updatesListPopup.hidePopup();
            }
        }

        focus: true
        Keys.onReleased: e => {
            if (e.key === Qt.Key_Escape) {
                updatesListPopup.hidePopup();
                e.accepted = true;
            }
        }

        ListModel {
            id: updatesListModel
        }

        property var allPackages: []

        function applyFilter(q) {
            updatesListModel.clear();
            var needle = String(q || "").toLowerCase();
            var itemsToAppend = [];

            if (!needle) {
                itemsToAppend = updatesListPopup.allPackages;
            } else {
                for (var i = 0; i < updatesListPopup.allPackages.length; i++) {
                    if (updatesListPopup.allPackages[i].pkgName.toLowerCase().includes(needle)) {
                        itemsToAppend.push(updatesListPopup.allPackages[i]);
                    }
                }
            }

            if (itemsToAppend.length > 0) {
                updatesListModel.append(itemsToAppend);
            }

            if (typeof updatesListView !== 'undefined' && updatesListView.count > 0) {
                updatesListView.positionViewAtBeginning();
            }
        }

        Io.Process {
            id: updatesFetcher
            stdout: Io.StdioCollector {
                onStreamFinished: {
                    var lines = this.text.trim().split("\n");
                    var pkgs = [];
                    for (var i = 0; i < lines.length; i++) {
                        var clean = lines[i].replace(/\x1b\[[0-9;]*[mK]/g, "").trim();
                        if (clean !== "") {
                            pkgs.push({
                                "pkgName": clean
                            });
                        }
                    }
                    updatesListPopup.allPackages = pkgs;
                    updatesListPopup.applyFilter("");
                }
            }
            onExited: function (exitCode, exitStatus) {
                if (exitCode === 0) {
                    updatesListPopup.fetchError = "";
                    if (updatesListPopup.currentCacheKey !== "") {
                        var cache = root.updatesListCache;
                        cache[updatesListPopup.currentCacheKey] = {
                            ts: Date.now(),
                            packages: updatesListPopup.allPackages,
                            error: ""
                        };
                        root.updatesListCache = cache;
                    }
                    return;
                }

                updatesListPopup.fetchError = updatesListPopup.allPackages.length > 0
                    ? "Package list may be incomplete."
                    : "Package database is busy. Try again in a moment.";
            }
        }

        Io.Process {
            id: detailsFetcher
            stdout: Io.StdioCollector {
                onStreamFinished: {
                    var cleanText = this.text.replace(/\x1b\[[0-9;]*[mK]/g, "");
                    var lines = cleanText.split("\n");
                    var formatted = "";
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        if (line.trim() === "")
                            continue;

                        var startsWithSpace = /^\s/.test(line);
                        var colonIdx = line.indexOf(":");

                        if (!startsWithSpace && colonIdx > 0) {
                            var key = line.substring(0, colonIdx).trim();
                            var val = line.substring(colonIdx + 1).trim();
                            formatted += "<font color='" + root.accent + "'><b>" + root.escapeHtml(key) + ":</b></font> " + root.linkifyText(val) + "<br><br>";
                        } else {
                            var escapedLine = root.linkifyText(line.trim());
                            if (formatted.endsWith("<br><br>")) {
                                formatted = formatted.substring(0, formatted.length - 8);
                                formatted += " " + escapedLine + "<br><br>";
                            } else {
                                formatted += escapedLine + "<br><br>";
                            }
                        }
                    }
                    updatesListPopup.packageDetailsText = formatted;
                }
            }
        }

        Item {
            id: updatesPopupShell
            width: updatesListPopup.popupCardWidth
            height: updatesListPopup.popupCardHeight
            anchors.centerIn: parent
            opacity: updatesListPopup.popupCardOpacity
            transform: [
                Scale {
                    origin.x: updatesPopupShell.width / 2
                    origin.y: updatesPopupShell.height / 2
                    xScale: updatesListPopup.popupCardScaleX
                    yScale: updatesListPopup.popupCardScaleY
                },
                Translate {
                    y: updatesListPopup.popupCardLift
                }
            ]

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                radius: updatesListPopup.popupCardRadius
                color: root.base
                border.color: root.panelBorderColor
                border.width: 1
                clip: true

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0
                    to: Math.PI * 2
                    duration: 90000
                    loops: Animation.Infinite
                    running: updatesListPopup.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                }

                Rectangle {
                    width: parent.width * 0.8
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.5 - width / 2) + Math.cos(parent.globalOrbitAngle * 1.5) * 80
                    y: (parent.height * 0.1 - height / 2) + Math.sin(parent.globalOrbitAngle * 1.5) * 100
                    opacity: 0.04
                    color: root.accent
                    z: 0
                }

                Rectangle {
                    width: parent.width * 0.6
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.2 - width / 2) + Math.sin(parent.globalOrbitAngle * 1.2) * -60
                    y: (parent.height * 0.8 - height / 2) + Math.cos(parent.globalOrbitAngle * 1.2) * -80
                    opacity: 0.03
                    color: ThemePkg.Theme.c5
                    z: 0
                }

                Text {
                    id: parallaxIcon
                    anchors.centerIn: parent
                    property real drift: 0
                    SequentialAnimation on drift {
                        loops: Animation.Infinite
                        running: updatesListPopup.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                        NumberAnimation {
                            to: -15
                            duration: 6000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 0
                            duration: 6000
                            easing.type: Easing.InOutSine
                        }
                    }
                    transform: Translate {
                        y: parallaxIcon.drift
                    }

                    text: "󰏔"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 320
                    color: root.accent
                    opacity: 0.03 + (0.01 * Math.sin(parent.globalOrbitAngle * 4))
                    z: 0
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 8
                    z: 1
                    visible: updatesListPopup.currentViewIndex === 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: updatesListPopup.titleStr
                            color: root.text
                            font.pixelSize: 22
                            font.family: root.textFont
                            font.weight: Font.Black
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    TextField {
                        id: updatesSearch
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "Search Updates…"
                        color: root.text
                        placeholderTextColor: root.overlay1

                        background: Rectangle {
                            color: "#0dffffff"
                            border.color: updatesSearch.activeFocus ? root.accent : "#1affffff"
                            border.width: 1
                            radius: 10
                        }

                        font.family: root.textFont
                        font.pixelSize: 14

                        padding: 8
                        leftPadding: 40

                        Text {
                            text: ""
                            font.family: "Material Design Icons"
                            font.pixelSize: 18
                            color: updatesSearch.activeFocus ? root.accent : root.overlay1
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Keys.onEscapePressed: updatesListPopup.hidePopup()

                        onTextChanged: updatesListPopup.applyFilter(text)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Column {
                            anchors.centerIn: parent
                            spacing: 20
                            visible: updatesFetcher.running

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰑐"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 52
                                color: root.accent

                                layer.enabled: true
                                layer.smooth: true

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1200
                                    loops: Animation.Infinite
                                    running: updatesFetcher.running && updatesListPopup.popupMounted
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Fetching packages..."
                                color: root.subtext0
                                font.family: root.textFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 20
                            visible: !updatesFetcher.running && updatesListModel.count === 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: updatesSearch.text !== "" ? "󰈉" : (updatesListPopup.fetchError !== "" ? "󰅙" : "󰄵")
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 52
                                color: updatesListPopup.fetchError !== "" ? root.red : root.accent
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: updatesSearch.text !== "" ? "No packages match your search." : (updatesListPopup.fetchError !== "" ? updatesListPopup.fetchError : "System is up to date.")
                                color: root.subtext0
                                font.family: root.textFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        ListView {
                            id: updatesListView
                            anchors.fill: parent
                            visible: !updatesFetcher.running && updatesListModel.count > 0
                            clip: true

                            ThemePkg.FastScrollHandler {
                                anchors.fill: parent
                                flickable: updatesListView
                            }

                            ScrollBar.vertical: ScrollBar {
                                id: vbar
                                policy: ScrollBar.AsNeeded
                                hoverEnabled: true
                                implicitWidth: 10
                                minimumSize: 0.08
                                active: hovered || pressed || updatesListView.moving

                                background: Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: root.moduleBorderColor
                                    border.color: root.moduleBorderColor
                                    opacity: vbar.active ? 1.0 : 0.7
                                }

                                contentItem: Rectangle {
                                    radius: width / 2
                                    border.width: 1
                                    border.color: root.moduleBorderColor
                                    color: root.accent
                                }
                            }
                            model: updatesListModel
                            spacing: 8
                            delegate: Rectangle {
                                width: ListView.view.width - 16
                                height: Math.max(40, mainRow.implicitHeight + 20)
                                radius: 14
                                color: hoverMa.containsMouse ? "#0affffff" : "#05ffffff"
                                border.width: 1
                                border.color: hoverMa.containsMouse ? root.accent : "#1affffff"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                RowLayout {
                                    id: mainRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    Rectangle {
                                        id: badge
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 24
                                        radius: 8
                                        color: "#0dffffff"
                                        border.color: "#1affffff"
                                        border.width: 1

                                        Text {
                                            anchors.fill: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            bottomPadding: 1
                                            text: "󰏔"
                                            color: root.accent
                                            font.pixelSize: 12
                                            font.family: root.textFont
                                        }
                                    }

                                    Text {
                                        text: model.pkgName
                                        color: root.text
                                        font.pixelSize: 13
                                        font.family: root.textFont
                                        Layout.fillWidth: true
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: hoverMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    HoverToolTip {
                                        visible: hoverMa.containsMouse
                                        delay: 200
                                        text: "Click to see details for " + model.pkgName
                                    }

                                    onClicked: {
                                        var mgr = updatesListPopup.managerType;
                                        var pkg = model.pkgName.replace(/[^\w.-]/g, "");
                                        if (pkg.length > 0) {
                                            updatesListPopup.currentPackageName = pkg;
                                            updatesListPopup.packageDetailsText = "Loading details for " + pkg + "...";
                                            updatesListPopup.currentViewIndex = 1;
                                            detailsFetcher.command = ["bash", "-c", root.updateInfoScript + " " + mgr + " " + pkg];
                                            detailsFetcher.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 15
                    z: 1
                    visible: updatesListPopup.currentViewIndex === 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: backBtnMa.containsMouse ? "#20ffffff" : "transparent"
                            border.color: backBtnMa.containsMouse ? root.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰁍"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 20
                                color: root.text
                            }

                            MouseArea {
                                id: backBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: updatesListPopup.currentViewIndex = 0
                            }
                        }

                        Text {
                            text: "Details: " + updatesListPopup.currentPackageName
                            color: root.text
                            font.pixelSize: 18
                            font.family: root.textFont
                            font.weight: Font.Black
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Flickable {
                        id: detailsFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: detailsText.implicitHeight

                        ThemePkg.FastScrollHandler {
                            anchors.fill: parent
                            flickable: detailsFlickable
                        }

                        TextArea {
                            id: detailsText
                            width: parent.width - 16
                            textFormat: TextEdit.RichText
                            text: updatesListPopup.packageDetailsText
                            color: root.text
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            readOnly: true
                            hoverEnabled: true
                            selectByMouse: true
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            background: Item {}
                        }

                        HoverHandler {
                            cursorShape: detailsText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: vbarDetails
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || detailsFlickable.moving

                            background: Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: root.moduleBorderColor
                                border.color: root.moduleBorderColor
                                opacity: vbarDetails.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: root.moduleBorderColor
                                color: root.accent
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 15
                    width: 30
                    height: 30
                    radius: 8
                    color: closeMa.containsMouse ? "#20ffffff" : "transparent"
                    border.color: closeMa.containsMouse ? root.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "CaskaydiaMono Nerd Font"
                        font.pixelSize: 16
                        color: root.text
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            updatesListPopup.hidePopup();
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: weatherSaveFillAnim
        target: root
        property: "weatherSaveFillLevel"
        to: 1.0
        duration: root.weatherSaveHoldDuration * (1.0 - root.weatherSaveFillLevel)
        easing.type: Easing.InSine
        onFinished: {
            if (!root.weatherSaveTriggered) {
                root.weatherSaveTriggered = true;
                root.weatherSaveFlashOpacity = 0.6;
                weatherSaveFlashDrainAnim.start();
                root.saveWeatherSettings();
                root.weatherSaveFillLevel = 0.0;
                root.weatherSaveTriggered = false;
                root.weatherSavePressed = false;
            }
        }
    }

    NumberAnimation {
        id: weatherSaveDrainAnim
        target: root
        property: "weatherSaveFillLevel"
        to: 0.0
        duration: 1000 * root.weatherSaveFillLevel
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: weatherSaveFlashDrainAnim
        target: root
        property: "weatherSaveFlashOpacity"
        to: 0.0
        duration: 520
        easing.type: Easing.OutExpo
    }

    NumberAnimation {
        id: authUnlockFillAnim
        target: root
        property: "authUnlockFillLevel"
        to: 1.0
        duration: root.authUnlockHoldDuration * (1.0 - root.authUnlockFillLevel)
        easing.type: Easing.InSine
        onFinished: {
            root.completeAuthUnlock();
        }
    }

    NumberAnimation {
        id: authUnlockDrainAnim
        target: root
        property: "authUnlockFillLevel"
        to: 0.0
        duration: 1000 * root.authUnlockFillLevel
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: authUnlockFlashDrainAnim
        target: root
        property: "authUnlockFlashOpacity"
        to: 0.0
        duration: 520
        easing.type: Easing.OutExpo
    }

    SequentialAnimation {
        id: authPopupEnterAnim
        running: false

        onStopped: {
            if (!authPopup.popupTargetVisible && authPopup.popupCardOpacity <= 0.001) {
                authPopup.popupMounted = false;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: authPopup
                property: "popupCardOpacity"
                to: 0.82
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleX"
                to: 0.985
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleY"
                to: 0.94
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardWidth"
                to: 434
                duration: 285
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardHeight"
                to: 150
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardRadius"
                to: 28
                duration: 270
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardLift"
                to: 8
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: authPopup
                property: "popupCardOpacity"
                to: 1.0
                duration: 175
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleX"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleY"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardWidth"
                to: 460
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardHeight"
                to: 154
                duration: 215
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardRadius"
                to: 20
                duration: 195
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardLift"
                to: 0
                duration: 205
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: authPopupExitAnim
        running: false

        onStopped: {
            if (!authPopup.popupTargetVisible && authPopup.popupCardOpacity <= 0.001) {
                authPopup.popupMounted = false;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleX"
                to: 1.04
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleY"
                to: 0.95
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardWidth"
                to: 478
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardHeight"
                to: 150
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardRadius"
                to: 30
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardLift"
                to: 5
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardOpacity"
                to: 0.88
                duration: 80
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: authPopup
                property: "popupCardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleX"
                to: 0.42
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardScaleY"
                to: 0.24
                duration: 280
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardWidth"
                to: 406
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardHeight"
                to: 142
                duration: 210
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardRadius"
                to: 34
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: authPopup
                property: "popupCardLift"
                to: 8.5
                duration: 280
                easing.type: Easing.InCubic
            }
        }
    }

    SequentialAnimation {
        id: weatherSettingsPopupEnterAnim
        running: false

        onStopped: {
            if (!weatherSettingsPopup.popupTargetVisible && weatherSettingsPopup.popupCardOpacity <= 0.001) {
                weatherSettingsPopup.popupMounted = false;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardOpacity"
                to: 0.82
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleX"
                to: 0.985
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleY"
                to: 0.94
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardWidth"
                to: 434
                duration: 285
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardHeight"
                to: 238
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardRadius"
                to: 28
                duration: 270
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardLift"
                to: 8
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardOpacity"
                to: 1.0
                duration: 175
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleX"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleY"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardWidth"
                to: 460
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardHeight"
                to: 253
                duration: 215
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardRadius"
                to: 20
                duration: 195
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardLift"
                to: 0
                duration: 205
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: weatherSettingsPopupExitAnim
        running: false

        onStopped: {
            if (!weatherSettingsPopup.popupTargetVisible && weatherSettingsPopup.popupCardOpacity <= 0.001) {
                weatherSettingsPopup.popupMounted = false;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleX"
                to: 1.04
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleY"
                to: 0.95
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardWidth"
                to: 478
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardHeight"
                to: 239
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardRadius"
                to: 30
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardLift"
                to: 5
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardOpacity"
                to: 0.88
                duration: 80
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleX"
                to: 0.42
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardScaleY"
                to: 0.24
                duration: 280
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardWidth"
                to: 460
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardHeight"
                to: 253
                duration: 210
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardRadius"
                to: 34
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: weatherSettingsPopup
                property: "popupCardLift"
                to: 8.5
                duration: 280
                easing.type: Easing.InCubic
            }
        }
    }

    Item {
        id: profileSettingsPopup
        anchors.fill: parent
        z: 99
        visible: popupMounted
        focus: true

        property bool popupMounted: false
        property bool popupTargetVisible: false
        property real popupCardOpacity: 0.0
        property real popupCardScaleX: 0.42
        property real popupCardScaleY: 0.24
        property real popupCardWidth: 460
        property real popupCardHeight: 165
        property real popupCardRadius: 34
        property real popupCardLift: 8.5

        property int activePickerMode: 0 // 0 = SDDM, 1 = Avatar, 2 = GRUB

        function showPopup() {
            popupMounted = true;
            popupTargetVisible = true;
            profileSettingsPopupExitAnim.stop();
            popupCardOpacity = 0.0;
            popupCardScaleX = 0.42;
            popupCardScaleY = 0.24;
            popupCardWidth = 460;
            popupCardHeight = 165;
            popupCardRadius = 34;
            popupCardLift = 8.5;
            profileSettingsPopupEnterAnim.stop();
            profileSettingsPopupEnterAnim.start();
        }

        function hidePopup() {
            popupTargetVisible = false;
            profileSettingsPopupEnterAnim.stop();
            if (!popupMounted && popupCardOpacity <= 0.001) {
                archPanel.visible = true;
                return;
            }
            if (!profileSettingsPopupExitAnim.running)
                profileSettingsPopupExitAnim.start();
        }

        Keys.onReleased: e => {
            if (e.key === Qt.Key_Escape) {
                profileSettingsPopup.hidePopup();
                e.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: profileSettingsPopup.hidePopup()
        }

        Item {
            id: profilePopupShell
            width: profileSettingsPopup.popupCardWidth
            height: profileSettingsPopup.popupCardHeight
            anchors.centerIn: parent
            opacity: profileSettingsPopup.popupCardOpacity
            transform: [
                Scale {
                    origin.x: profilePopupShell.width / 2
                    origin.y: profilePopupShell.height / 2
                    xScale: profileSettingsPopup.popupCardScaleX
                    yScale: profileSettingsPopup.popupCardScaleY
                },
                Translate {
                    y: profileSettingsPopup.popupCardLift
                }
            ]

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                radius: profileSettingsPopup.popupCardRadius
                color: root.base
                border.color: root.panelBorderColor
                border.width: 1
                clip: true

                AnimatedBorder {
                    anchors.fill: parent
                    radius: parent.radius
                    borderWidth: parent.border.width
                    accentColor: root.accent
                    active: profileSettingsPopup.popupMounted
                }

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0
                    to: Math.PI * 2
                    duration: 90000
                    loops: Animation.Infinite
                    running: profileSettingsPopup.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                }

                Rectangle {
                    width: parent.width * 0.72
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.58 - width / 2) + Math.cos(parent.globalOrbitAngle * 1.5) * 70
                    y: (parent.height * 0.05 - height / 2) + Math.sin(parent.globalOrbitAngle * 1.5) * 80
                    opacity: 0.05
                    color: root.accent
                }

                Rectangle {
                    width: parent.width * 0.55
                    height: width
                    radius: width / 2
                    x: (parent.width * 0.12 - width / 2) + Math.sin(parent.globalOrbitAngle * 1.2) * -52
                    y: (parent.height * 0.82 - height / 2) + Math.cos(parent.globalOrbitAngle * 1.2) * -64
                    opacity: 0.035
                    color: ThemePkg.Theme.c5
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    text: "󰙽"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 240
                    color: root.accent
                    opacity: 0.035
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 25
                    anchors.rightMargin: 25
                    anchors.topMargin: 25
                    anchors.bottomMargin: 25
                    spacing: 15
                    z: 1

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: 12
                        color: sddmBtnMa.containsMouse ? "#20ffffff" : "#10ffffff"
                        border.color: sddmBtnMa.containsMouse ? root.accent : "#20ffffff"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            Text {
                                text: "󰄄"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 18
                                color: root.text
                            }
                            Text {
                                text: "Change SDDM Background"
                                font.family: root.textFont
                                font.pixelSize: 14
                                color: root.text
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: sddmBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                profileSettingsPopup.activePickerMode = 0;
                                root.openSddmPicker();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: 12
                        color: avatarBtnMa.containsMouse ? "#20ffffff" : "#10ffffff"
                        border.color: avatarBtnMa.containsMouse ? root.accent : "#20ffffff"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            Text {
                                text: "󰙽"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 18
                                color: root.text
                            }
                            Text {
                                text: "Change Profile Avatar"
                                font.family: root.textFont
                                font.pixelSize: 14
                                color: root.text
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: avatarBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                profileSettingsPopup.activePickerMode = 1;
                                root.openSddmPicker();
                            }
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: profileSettingsPopupEnterAnim
        running: false

        onStopped: {
            if (!profileSettingsPopup.popupTargetVisible && profileSettingsPopup.popupCardOpacity <= 0.001) {
                profileSettingsPopup.popupMounted = false;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardOpacity"
                to: 0.82
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleX"
                to: 0.985
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleY"
                to: 0.94
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardWidth"
                to: 434
                duration: 285
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardHeight"
                to: 150
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardRadius"
                to: 28
                duration: 270
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardLift"
                to: 8
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardOpacity"
                to: 1.0
                duration: 175
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleX"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleY"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardWidth"
                to: 460
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardHeight"
                to: 165
                duration: 215
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardRadius"
                to: 20
                duration: 195
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardLift"
                to: 0
                duration: 205
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: profileSettingsPopupExitAnim
        running: false

        onStopped: {
            if (!profileSettingsPopup.popupTargetVisible && profileSettingsPopup.popupCardOpacity <= 0.001) {
                profileSettingsPopup.popupMounted = false;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleX"
                to: 1.04
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleY"
                to: 0.95
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardWidth"
                to: 478
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardHeight"
                to: 306
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardRadius"
                to: 30
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardLift"
                to: 5
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardOpacity"
                to: 0.88
                duration: 80
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleX"
                to: 0.42
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardScaleY"
                to: 0.24
                duration: 280
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardWidth"
                to: 406
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardHeight"
                to: 292
                duration: 210
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardRadius"
                to: 34
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: profileSettingsPopup
                property: "popupCardLift"
                to: 8.5
                duration: 280
                easing.type: Easing.InCubic
            }
        }
    }

    SequentialAnimation {
        id: updatesListPopupEnterAnim
        running: false

        onStopped: {
            if (!updatesListPopup.popupTargetVisible && updatesListPopup.popupCardOpacity <= 0.001) {
                updatesListPopup.popupMounted = false;
                updatesListPopup.currentViewIndex = 0;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardOpacity"
                to: 0.82
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleX"
                to: 0.985
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleY"
                to: 0.94
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardWidth"
                to: 454
                duration: 285
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardHeight"
                to: 566
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardRadius"
                to: 28
                duration: 270
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardLift"
                to: 8
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardOpacity"
                to: 1.0
                duration: 175
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleX"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleY"
                to: 1.0
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardWidth"
                to: 480
                duration: 205
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardHeight"
                to: 600
                duration: 215
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardRadius"
                to: 20
                duration: 195
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardLift"
                to: 0
                duration: 205
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: updatesListPopupExitAnim
        running: false

        onStopped: {
            if (!updatesListPopup.popupTargetVisible && updatesListPopup.popupCardOpacity <= 0.001) {
                updatesListPopup.popupMounted = false;
                updatesListPopup.currentViewIndex = 0;
                archPanel.visible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleX"
                to: 1.04
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleY"
                to: 0.95
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardWidth"
                to: 498
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardHeight"
                to: 580
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardRadius"
                to: 30
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardLift"
                to: 5
                duration: 95
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardOpacity"
                to: 0.88
                duration: 80
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleX"
                to: 0.42
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardScaleY"
                to: 0.24
                duration: 280
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardWidth"
                to: 436
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardHeight"
                to: 572
                duration: 210
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardRadius"
                to: 34
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: updatesListPopup
                property: "popupCardLift"
                to: 8.5
                duration: 280
                easing.type: Easing.InCubic
            }
        }
    }

    component DetailSection: Rectangle {
        id: detailSection
        property string title: ""
        property string subtitle: ""
        property color accentColor: root.accent
        default property alias sectionData: detailSectionBody.data

        width: parent ? parent.width : 0
        implicitHeight: detailSectionColumn.implicitHeight + 24
        radius: 16
        color: "#0dffffff"
        border.width: 1
        border.color: ThemePkg.Theme.withAlpha(accentColor, 0.24)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: ThemePkg.Theme.withAlpha("#ffffff", 0.05)
        }

        Column {
            id: detailSectionColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 6
                    height: 18
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: detailSection.accentColor
                }

                Text {
                    text: detailSection.title
                    color: root.text
                    font.pixelSize: 13
                    font.family: root.textFont
                    font.weight: Font.Black
                }
            }

            Text {
                visible: detailSection.subtitle !== ""
                width: parent.width
                text: detailSection.subtitle
                wrapMode: Text.Wrap
                color: root.subtext0
                font.pixelSize: 10
                font.family: root.textFont
            }

            Column {
                id: detailSectionBody
                width: parent.width
                spacing: 10
            }
        }
    }

    component DetailMetric: Rectangle {
        id: detailMetric
        property string label: ""
        property string value: ""
        property string secondary: ""
        property color accentColor: root.accent

        implicitHeight: metricColumn.implicitHeight + 20
        radius: 14
        color: "#0affffff"
        border.width: 1
        border.color: ThemePkg.Theme.withAlpha(accentColor, 0.18)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: ThemePkg.Theme.withAlpha("#ffffff", 0.04)
        }

        Column {
            id: metricColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Text {
                text: detailMetric.label
                color: detailMetric.accentColor
                font.pixelSize: 10
                font.family: root.textFont
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: detailMetric.value
                wrapMode: Text.Wrap
                color: root.text
                font.pixelSize: 15
                font.family: root.textFont
                font.weight: Font.Black
            }

            Text {
                visible: detailMetric.secondary !== ""
                width: parent.width
                text: detailMetric.secondary
                wrapMode: Text.Wrap
                color: root.subtext0
                font.pixelSize: 9
                font.family: root.textFont
            }
        }
    }

    component DetailEntryRow: Rectangle {
        id: detailEntryRow
        property string title: ""
        property string subtitle: ""
        property string primaryValue: ""
        property string secondaryValue: ""
        property color accentColor: root.accent

        implicitHeight: 54
        radius: 12
        color: "#09ffffff"
        border.width: 1
        border.color: ThemePkg.Theme.withAlpha(accentColor, 0.12)

        Rectangle {
            width: 4
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 2
            color: ThemePkg.Theme.withAlpha(detailEntryRow.accentColor, 0.75)
            opacity: 0.70
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Column {
                width: parent.width - valueColumn.width - parent.spacing
                spacing: 2

                Text {
                    width: parent.width
                    text: detailEntryRow.title
                    color: root.text
                    font.pixelSize: 12
                    font.family: root.textFont
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    visible: detailEntryRow.subtitle !== ""
                    width: parent.width
                    text: detailEntryRow.subtitle
                    color: root.subtext0
                    font.pixelSize: 10
                    font.family: root.textFont
                    elide: Text.ElideRight
                }
            }

            Column {
                id: valueColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    anchors.right: parent.right
                    text: detailEntryRow.primaryValue
                    color: detailEntryRow.accentColor
                    font.pixelSize: 11
                    font.family: root.textFont
                    font.weight: Font.Black
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    visible: detailEntryRow.secondaryValue !== ""
                    anchors.right: parent.right
                    text: detailEntryRow.secondaryValue
                    color: root.subtext0
                    font.pixelSize: 10
                    font.family: root.textFont
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    component UsageHistoryChart: Item {
        id: chart
        property var points: []
        property var liveValue: undefined
        property color accentColor: root.accent
        property real maxValue: 100
        property real labelWidth: 30
        property var valueFormatter: null
        readonly property bool hasLiveValue: liveValue !== undefined && liveValue !== null && !isNaN(Number(liveValue))
        readonly property real effectiveMaxValue: Math.max(maxValue, hasLiveValue ? Number(liveValue) : 0, 1)
        readonly property real latestValue: {
            if (hasLiveValue)
                return Math.max(0, Number(liveValue));
            if (!points || !points.length)
                return 0;
            return Math.max(0, Number(points[points.length - 1]) || 0);
        }

        function formatValue(value) {
            return valueFormatter ? valueFormatter(value) : root.formatPercent(value);
        }

        implicitHeight: 138

        Rectangle {
            id: chartFrame
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: chart.labelWidth + 4
            anchors.right: parent.right
            radius: 14
            color: ThemePkg.Theme.withAlpha(root.surface2, 0.34)
            border.width: 1
            border.color: ThemePkg.Theme.withAlpha(chart.accentColor, 0.20)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.width: 1
                border.color: ThemePkg.Theme.withAlpha("#ffffff", 0.04)
            }
        }

        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: chart.labelWidth

            Repeater {
                model: 5
                delegate: Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    y: (parent.height / 4) * (4 - index) - height / 2
                    text: chart.formatValue((chart.effectiveMaxValue / 4) * index)
                    color: ThemePkg.Theme.withAlpha(root.text, 0.40)
                    font.pixelSize: 8
                    font.family: root.textFont
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        Canvas {
            id: chartCanvas
            anchors.fill: chartFrame
            anchors.margins: 10
            renderTarget: Canvas.FramebufferObject

            function paintGrid(ctx) {
                ctx.strokeStyle = ThemePkg.Theme.withAlpha(root.text, 0.07);
                ctx.lineWidth = 1;
                for (var i = 0; i < 5; i++) {
                    var y = height * (i / 4);
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }
                ctx.strokeStyle = ThemePkg.Theme.withAlpha(root.text, 0.045);
                for (var j = 0; j < 7; j++) {
                    var x = width * (j / 6);
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                }
            }

            function paintTrace(ctx, coords) {
                if (!coords.length)
                    return;
                ctx.beginPath();
                ctx.moveTo(coords[0].x, coords[0].y);
                if (coords.length === 1) {
                    ctx.lineTo(coords[0].x, coords[0].y);
                    return;
                }
                for (var i = 1; i < coords.length; i++) {
                    var previous = coords[i - 1];
                    var current = coords[i];
                    var midX = (previous.x + current.x) / 2;
                    var midY = (previous.y + current.y) / 2;
                    ctx.quadraticCurveTo(previous.x, previous.y, midX, midY);
                }
                var last = coords[coords.length - 1];
                ctx.quadraticCurveTo(last.x, last.y, last.x, last.y);
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (width <= 0 || height <= 0)
                    return;

                paintGrid(ctx);

                var values = (chart.points || []).slice(0);
                if (chart.hasLiveValue) {
                    if (values.length)
                        values[values.length - 1] = chart.liveValue;
                    else
                        values.push(chart.liveValue);
                }
                if (!values.length)
                    return;

                var maxRef = chart.effectiveMaxValue;
                var inset = 6;
                var plotWidth = Math.max(0, width - (inset * 2));
                var plotHeight = Math.max(0, height - (inset * 2));
                var stepX = values.length > 1 ? plotWidth / (values.length - 1) : 0;
                var coords = [];
                for (var i = 1; i < values.length; i++) {
                    var clamped = Math.max(0, Math.min(maxRef, Number(values[i]) || 0));
                    coords.push({
                        "x": inset + (stepX * i),
                        "y": inset + plotHeight - (clamped / maxRef) * plotHeight
                    });
                }
                var first = Math.max(0, Math.min(maxRef, Number(values[0]) || 0));
                coords.unshift({
                    "x": values.length > 1 ? inset : width - inset,
                    "y": inset + plotHeight - (first / maxRef) * plotHeight
                });

                paintTrace(ctx, coords);
                ctx.lineTo(coords[coords.length - 1].x, height - inset);
                ctx.lineTo(coords[0].x, height - inset);
                ctx.closePath();

                var fillGrad = ctx.createLinearGradient(0, 0, 0, height);
                fillGrad.addColorStop(0, ThemePkg.Theme.withAlpha(chart.accentColor, 0.48));
                fillGrad.addColorStop(0.58, ThemePkg.Theme.withAlpha(chart.accentColor, 0.16));
                fillGrad.addColorStop(1, ThemePkg.Theme.withAlpha(chart.accentColor, 0.015));
                ctx.fillStyle = fillGrad;
                ctx.fill();

                paintTrace(ctx, coords);
                ctx.strokeStyle = ThemePkg.Theme.withAlpha(chart.accentColor, 0.24);
                ctx.lineWidth = 6;
                ctx.stroke();

                paintTrace(ctx, coords);
                ctx.strokeStyle = chart.accentColor;
                ctx.lineWidth = 2.2;
                ctx.stroke();

                var latest = coords[coords.length - 1];
                ctx.beginPath();
                ctx.arc(latest.x, latest.y, 6, 0, Math.PI * 2);
                ctx.fillStyle = ThemePkg.Theme.withAlpha(chart.accentColor, 0.22);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(latest.x, latest.y, 3, 0, Math.PI * 2);
                ctx.fillStyle = chart.accentColor;
                ctx.fill();
            }
        }

        Rectangle {
            anchors.top: chartFrame.top
            anchors.right: chartFrame.right
            anchors.topMargin: 10
            anchors.rightMargin: 10
            width: liveValueRow.implicitWidth + 16
            height: 24
            radius: 12
            color: ThemePkg.Theme.withAlpha(root.crust, 0.74)
            border.width: 1
            border.color: ThemePkg.Theme.withAlpha(chart.accentColor, 0.30)

            Row {
                id: liveValueRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: chart.accentColor
                }

                Text {
                    text: chart.formatValue(chart.latestValue)
                    color: root.text
                    font.pixelSize: 10
                    font.family: root.textFont
                    font.weight: Font.Black
                }
            }
        }

        onPointsChanged: chartCanvas.requestPaint()
        onWidthChanged: chartCanvas.requestPaint()
        onHeightChanged: chartCanvas.requestPaint()
        onAccentColorChanged: chartCanvas.requestPaint()
        onMaxValueChanged: chartCanvas.requestPaint()
        onLiveValueChanged: chartCanvas.requestPaint()
    }

    Component {
        id: detailLoadingComp

        Item {
            width: parent ? parent.width : 0
            implicitHeight: 92

            DetailSection {
                width: parent.width
                title: "Loading"
                subtitle: "The selected telemetry block is polling the detail script right now."
                accentColor: root.resourceAccent(root.visibleDetailsKey)

                Text {
                    width: parent.width
                    text: "Collecting live data for " + root.resourceTitle(root.visibleDetailsKey) + "..."
                    color: root.text
                    font.pixelSize: 13
                    font.family: root.textFont
                    font.weight: Font.Bold
                }
            }
        }
    }

    Component {
        id: detailErrorComp

        Item {
            width: parent ? parent.width : 0
            implicitHeight: 112

            DetailSection {
                width: parent.width
                title: "Telemetry Error"
                subtitle: "The summary tiles keep updating, but the expanded panel could not parse its detailed payload."
                accentColor: root.red

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.expandedResourceError
                    color: root.text
                    font.pixelSize: 12
                    font.family: root.textFont
                }
            }
        }
    }

    Component {
        id: cpuDetailComp

        Item {
            id: cpuDetailRoot
            width: parent ? parent.width : 0
            property var cpuData: root.detailObject("cpu") || ({})
            implicitHeight: cpuDetailColumn.implicitHeight

            Column {
                id: cpuDetailColumn
                width: parent.width
                spacing: 12

                DetailSection {
                    width: parent.width
                    title: "Processor Snapshot"
                    subtitle: cpuData.model || "Collecting processor identification..."
                    accentColor: root.resourceAccent("cpu")

                    Flow {
                        width: parent.width
                        spacing: 10

                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Usage"
                            value: root.formatPercent(root.displayedCpuTotal())
                            secondary: "Current package load"
                            accentColor: root.resourceAccent("cpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Frequency"
                            value: root.formatFrequency(cpuData.average_mhz)
                            secondary: cpuData.max_mhz ? "Boost " + root.formatFrequency(cpuData.max_mhz) : "Average clock"
                            accentColor: root.resourceAccent("cpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Temperature"
                            value: root.formatTemp(cpuData.temperature_c)
                            secondary: "Package sensor"
                            accentColor: root.resourceAccent("cpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Power Draw"
                            value: root.formatPower(cpuData.power_w)
                            secondary: "Best effort package power"
                            accentColor: root.resourceAccent("cpu")
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Usage History"
                    subtitle: "Recent live samples collected by the summary poller."
                    accentColor: root.resourceAccent("cpu")

                    UsageHistoryChart {
                        width: parent.width
                        points: root.cpuHistory
                        liveValue: root.displayedCpuTotal()
                        accentColor: root.resourceAccent("cpu")
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Per-Core Clock / Usage"
                    subtitle: "Live usage per logical core paired with its current clock."
                    accentColor: root.resourceAccent("cpu")

                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: cpuData.per_core || []
                            delegate: DetailMetric {
                                width: Math.floor((parent.width - 24) / 4)
                                label: "Core " + modelData.id
                                value: root.formatPercent(modelData.usage_percent, 1)
                                secondary: root.formatFrequency(modelData.mhz)
                                accentColor: root.resourceAccent("cpu")
                            }
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Top CPU Processes"
                    subtitle: "Processes currently with the highest CPU usage."
                    accentColor: root.resourceAccent("cpu")

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            visible: !(cpuData.top_processes && cpuData.top_processes.length)
                            text: "No process telemetry available right now."
                            color: root.subtext0
                            font.pixelSize: 11
                            font.family: root.textFont
                        }

                        Repeater {
                            model: cpuData.top_processes || []
                            delegate: DetailEntryRow {
                                width: parent.width
                                title: (index + 1) + ". " + modelData.name
                                subtitle: "PID " + modelData.pid
                                primaryValue: root.formatPercent(modelData.cpu_percent, 1)
                                accentColor: root.resourceAccent("cpu")
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: ramDetailComp

        Item {
            id: ramDetailRoot
            width: parent ? parent.width : 0
            property var ramData: root.detailObject("ram") || ({})
            implicitHeight: ramDetailColumn.implicitHeight

            Column {
                id: ramDetailColumn
                width: parent.width
                spacing: 12

                DetailSection {
                    width: parent.width
                    title: "Memory Snapshot"
                    subtitle: "Current RAM occupancy, cache state and effective memory speed."
                    accentColor: root.resourceAccent("ram")

                    Flow {
                        width: parent.width
                        spacing: 10

                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Usage"
                            value: root.formatBytes(ramData.used_bytes) + " / " + root.formatBytes(ramData.total_bytes)
                            secondary: root.formatPercent(ramData.percent, 1) + " used"
                            accentColor: root.resourceAccent("ram")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Free"
                            value: root.formatBytes(ramData.free_bytes)
                            secondary: "Immediately free pages"
                            accentColor: root.resourceAccent("ram")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Cached"
                            value: root.formatBytes(ramData.cached_bytes)
                            secondary: "Page cache + reclaimable"
                            accentColor: root.resourceAccent("ram")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Available"
                            value: root.formatBytes(ramData.available_bytes)
                            secondary: "Usable without swapping"
                            accentColor: root.resourceAccent("ram")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Frequency"
                            value: ramData.frequency_mhz ? root.formatFrequency(ramData.frequency_mhz) : "N/A"
                            secondary: "Detected memory speed"
                            accentColor: root.resourceAccent("ram")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Swap"
                            value: root.formatBytes(ramData.swap_used_bytes)
                            secondary: "of " + root.formatBytes(ramData.swap_total_bytes)
                            accentColor: root.resourceAccent("ram")
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Usage History"
                    subtitle: "Recent live RAM usage percentages."
                    accentColor: root.resourceAccent("ram")

                    UsageHistoryChart {
                        width: parent.width
                        points: root.ramHistory
                        liveValue: ramData.percent
                        accentColor: root.resourceAccent("ram")
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Top RAM Processes"
                    subtitle: "Processes currently holding the largest resident sets."
                    accentColor: root.resourceAccent("ram")

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            visible: !(ramData.top_processes && ramData.top_processes.length)
                            text: "No process telemetry available right now."
                            color: root.subtext0
                            font.pixelSize: 11
                            font.family: root.textFont
                        }

                        Repeater {
                            model: ramData.top_processes || []
                            delegate: DetailEntryRow {
                                width: parent.width
                                title: (index + 1) + ". " + modelData.name
                                subtitle: "PID " + modelData.pid
                                primaryValue: root.formatBytes(modelData.rss_bytes)
                                secondaryValue: root.formatPercent(modelData.mem_percent, 1)
                                accentColor: root.resourceAccent("ram")
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: diskDetailComp

        Item {
            id: diskDetailRoot
            width: parent ? parent.width : 0
            property var diskData: root.detailObject("disk") || ({})
            property var osFilesystem: diskData.os_filesystem || ({})
            property var osDisk: diskData.os_disk || ({})
            implicitHeight: diskDetailColumn.implicitHeight

            Column {
                id: diskDetailColumn
                width: parent.width
                spacing: 12

                DetailSection {
                    width: parent.width
                    title: "Storage Overview"
                    subtitle: "OS filesystem usage plus aggregate capacity and current throughput across detected disks."
                    accentColor: root.resourceAccent("disk")

                    Flow {
                        width: parent.width
                        spacing: 10

                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "OS Disk"
                            value: root.formatPercent(osDisk.percent, 1)
                            secondary: osDisk.name || "Physical system disk"
                            accentColor: root.resourceAccent("disk")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "OS Filesystem"
                            value: root.formatPercent(osFilesystem.percent, 1)
                            secondary: (osFilesystem.mountpoint || "/") + " on " + (osFilesystem.device || "system disk")
                            accentColor: root.resourceAccent("disk")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "All Disks"
                            value: root.formatPercent(diskData.total_percent, 1)
                            secondary: "Aggregate physical capacity"
                            accentColor: root.resourceAccent("disk")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Read I/O"
                            value: root.formatRate(root.sumField(diskData.devices, "read_bps"))
                            secondary: "Aggregate disk reads"
                            accentColor: root.resourceAccent("disk")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Write I/O"
                            value: root.formatRate(root.sumField(diskData.devices, "write_bps"))
                            secondary: "Aggregate disk writes"
                            accentColor: root.resourceAccent("disk")
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Usage History"
                    subtitle: "Recent summary samples for the storage tile."
                    accentColor: root.resourceAccent("disk")

                    UsageHistoryChart {
                        width: parent.width
                        points: root.diskHistory
                        liveValue: osDisk.percent
                        accentColor: root.resourceAccent("disk")
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Disks & Partitions"
                    subtitle: "Each physical disk is grouped with its mounted partitions and current I/O."
                    accentColor: root.resourceAccent("disk")

                    Column {
                        width: parent.width
                        spacing: 10

                        Text {
                            visible: !(diskData.devices && diskData.devices.length)
                            text: "No block devices detected."
                            color: root.subtext0
                            font.pixelSize: 11
                            font.family: root.textFont
                        }

                        Repeater {
                            model: diskData.devices || []
                            delegate: Rectangle {
                                width: parent.width
                                radius: 14
                                color: ThemePkg.Theme.withAlpha(root.surface2, 0.60)
                                border.width: 1
                                border.color: ThemePkg.Theme.withAlpha(root.resourceAccent("disk"), 0.14)
                                implicitHeight: diskDeviceColumn.implicitHeight + 20

                                Column {
                                    id: diskDeviceColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Item {
                                        width: parent.width
                                        height: Math.max(diskLeftInfo.implicitHeight, diskRightInfo.implicitHeight)

                                        Column {
                                            id: diskLeftInfo
                                            anchors.left: parent.left
                                            anchors.right: diskRightInfo.left
                                            anchors.rightMargin: 12
                                            spacing: 2

                                            Text {
                                                text: modelData.name + (modelData.model ? "  " + modelData.model : "")
                                                color: root.text
                                                font.pixelSize: 12
                                                font.family: root.textFont
                                                font.weight: Font.Black
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                text: (modelData.transport ? modelData.transport.toUpperCase() + "  •  " : "") + root.formatBytes(modelData.total_bytes)
                                                color: root.subtext0
                                                font.pixelSize: 10
                                                font.family: root.textFont
                                            }
                                        }

                                        Column {
                                            id: diskRightInfo
                                            anchors.right: parent.right
                                            spacing: 2

                                            Text {
                                                anchors.right: parent.right
                                                text: root.formatBytes(modelData.used_bytes) + " / " + root.formatBytes(modelData.total_bytes)
                                                color: root.resourceAccent("disk")
                                                font.pixelSize: 11
                                                font.family: root.textFont
                                                font.weight: Font.Black
                                                horizontalAlignment: Text.AlignRight
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                text: root.formatPercent(modelData.percent, 1)
                                                color: root.subtext0
                                                font.pixelSize: 10
                                                font.family: root.textFont
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 18

                                        Text {
                                            text: "Read  " + root.formatRate(modelData.read_bps)
                                            color: root.text
                                            font.pixelSize: 10
                                            font.family: root.textFont
                                        }

                                        Text {
                                            text: "Write  " + root.formatRate(modelData.write_bps)
                                            color: root.text
                                            font.pixelSize: 10
                                            font.family: root.textFont
                                        }
                                    }

                                    Repeater {
                                        model: modelData.partitions || []
                                        delegate: DetailEntryRow {
                                            width: parent.width
                                            title: modelData.name + (modelData.mountpoint ? "  →  " + modelData.mountpoint : "")
                                            subtitle: modelData.fstype ? modelData.fstype.toUpperCase() : "Unmounted"
                                            primaryValue: (modelData.used_bytes !== null && modelData.used_bytes !== undefined) ? (root.formatBytes(modelData.used_bytes) + " / " + root.formatBytes(modelData.total_bytes)) : "Unmounted"
                                            secondaryValue: (modelData.percent !== null && modelData.percent !== undefined) ? root.formatPercent(modelData.percent, 1) : ""
                                            accentColor: root.resourceAccent("disk")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Top Disk I/O Processes"
                    subtitle: "Processes currently moving the most data through disk I/O."
                    accentColor: root.resourceAccent("disk")

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            visible: !(diskData.top_processes && diskData.top_processes.length)
                            text: "No active disk-heavy processes detected in this sample window."
                            color: root.subtext0
                            font.pixelSize: 11
                            font.family: root.textFont
                        }

                        Repeater {
                            model: diskData.top_processes || []
                            delegate: DetailEntryRow {
                                width: parent.width
                                title: (index + 1) + ". " + modelData.name
                                subtitle: "PID " + modelData.pid + "  •  Read " + root.formatRate(modelData.read_bps) + "  •  Write " + root.formatRate(modelData.write_bps)
                                primaryValue: root.formatRate(modelData.total_bps)
                                accentColor: root.resourceAccent("disk")
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: gpuDetailComp

        Item {
            id: gpuDetailRoot
            width: parent ? parent.width : 0
            property var gpuData: root.detailObject("gpu") || ({})
            implicitHeight: gpuDetailColumn.implicitHeight

            Column {
                id: gpuDetailColumn
                width: parent.width
                spacing: 12

                DetailSection {
                    width: parent.width
                    title: "GPU Snapshot"
                    subtitle: gpuData.name || root.statGpuName || "Collecting GPU identification..."
                    accentColor: root.resourceAccent("gpu")

                    Flow {
                        width: parent.width
                        spacing: 10

                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Usage"
                            value: root.formatPercent(gpuData.usage_percent, 1)
                            secondary: "Graphics engine load"
                            accentColor: root.resourceAccent("gpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "VRAM"
                            value: (gpuData.vram_used_mb !== null && gpuData.vram_used_mb !== undefined) ? (root.formatBytes(gpuData.vram_used_mb * 1024 * 1024) + " / " + root.formatBytes(gpuData.vram_total_mb * 1024 * 1024)) : "N/A"
                            secondary: (gpuData.vram_free_mb !== null && gpuData.vram_free_mb !== undefined) ? ("Free " + root.formatBytes(gpuData.vram_free_mb * 1024 * 1024)) : "VRAM telemetry"
                            accentColor: root.resourceAccent("gpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Temperature"
                            value: root.formatTemp(gpuData.temperature_c)
                            secondary: "On-die sensor"
                            accentColor: root.resourceAccent("gpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Power Draw"
                            value: root.formatPower(gpuData.power_w)
                            secondary: "Current board power"
                            accentColor: root.resourceAccent("gpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Fan"
                            value: root.formatPercent(gpuData.fan_percent, 1)
                            secondary: "Fan speed percentage"
                            accentColor: root.resourceAccent("gpu")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Memory Bus"
                            value: (gpuData.memory_percent !== null && gpuData.memory_percent !== undefined) ? root.formatPercent(gpuData.memory_percent, 1) : "N/A"
                            secondary: "Memory activity"
                            accentColor: root.resourceAccent("gpu")
                        }
                    }

                    Text {
                        visible: gpuData.message !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: gpuData.message
                        color: root.subtext0
                        font.pixelSize: 10
                        font.family: root.textFont
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Usage History"
                    subtitle: "Recent summary samples for the GPU tile."
                    accentColor: root.resourceAccent("gpu")

                    UsageHistoryChart {
                        width: parent.width
                        points: root.gpuHistory
                        liveValue: gpuData.usage_percent
                        accentColor: root.resourceAccent("gpu")
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Top GPU Processes"
                    subtitle: "Best effort list of processes currently using the GPU the most."
                    accentColor: root.resourceAccent("gpu")

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            visible: !(gpuData.top_processes && gpuData.top_processes.length)
                            text: gpuData.available ? "No active GPU processes reported in this sample." : "Detailed GPU process telemetry is not available for the current session."
                            color: root.subtext0
                            font.pixelSize: 11
                            font.family: root.textFont
                        }

                        Repeater {
                            model: gpuData.top_processes || []
                            delegate: DetailEntryRow {
                                width: parent.width
                                title: (index + 1) + ". " + modelData.name
                                subtitle: "PID " + modelData.pid
                                primaryValue: (modelData.gpu_percent !== null && modelData.gpu_percent !== undefined) ? root.formatPercent(modelData.gpu_percent, 1) : "N/A"
                                secondaryValue: (modelData.vram_mb !== null && modelData.vram_mb !== undefined) ? root.formatBytes(modelData.vram_mb * 1024 * 1024) : ((modelData.memory_percent !== null && modelData.memory_percent !== undefined) ? root.formatPercent(modelData.memory_percent, 1) : "")
                                accentColor: root.resourceAccent("gpu")
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: netDetailComp

        Item {
            id: netDetailRoot
            width: parent ? parent.width : 0
            property var netData: root.detailObject("net") || ({})
            property var socketData: netData.sockets || ({})
            property string expandedInterface: ""
            implicitHeight: netDetailColumn.implicitHeight

            Column {
                id: netDetailColumn
                width: parent.width
                spacing: 12

                DetailSection {
                    width: parent.width
                    title: "Network Snapshot"
                    subtitle: netData.primary_iface ? "Live traffic on " + netData.primary_iface : "No active network interface detected."
                    accentColor: root.resourceAccent("net")

                    Flow {
                        width: parent.width
                        spacing: 10

                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Traffic"
                            value: root.formatRate(netData.total_bps)
                            secondary: "Combined throughput"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Download"
                            value: root.formatRate(netData.down_bps)
                            secondary: "Current receive rate"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Upload"
                            value: root.formatRate(netData.up_bps)
                            secondary: "Current transmit rate"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Received"
                            value: root.formatBytes(netData.rx_bytes)
                            secondary: "Transferred since boot"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Sent"
                            value: root.formatBytes(netData.tx_bytes)
                            secondary: "Transferred since boot"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 20) / 3)
                            label: "Gateway"
                            value: netData.gateway || "N/A"
                            secondary: (netData.active_interfaces || 0) + " active interfaces"
                            accentColor: root.resourceAccent("net")
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Traffic History"
                    subtitle: "Recent combined download and upload throughput samples."
                    accentColor: root.resourceAccent("net")

                    UsageHistoryChart {
                        width: parent.width
                        points: root.netHistory
                        liveValue: netData.total_bps
                        maxValue: root.historyScaleMax(root.netHistory, 1024)
                        labelWidth: 66
                        valueFormatter: function(value) {
                            return root.formatRate(value);
                        }
                        accentColor: root.resourceAccent("net")
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Interfaces"
                    subtitle: "Physical, wireless and virtual interfaces with their current activity."
                    accentColor: root.resourceAccent("net")

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            visible: !(netData.interfaces && netData.interfaces.length)
                            text: "No network interfaces detected."
                            color: root.subtext0
                            font.pixelSize: 11
                            font.family: root.textFont
                        }

                        Repeater {
                            model: netData.interfaces || []
                            delegate: Rectangle {
                                id: interfaceCard
                                width: parent.width
                                property bool expanded: netDetailRoot.expandedInterface === String(modelData.name || "")
                                implicitHeight: interfaceCardColumn.implicitHeight + 20
                                radius: 14
                                color: ThemePkg.Theme.withAlpha(root.surface2, expanded ? 0.72 : 0.50)
                                border.width: 1
                                border.color: ThemePkg.Theme.withAlpha(root.resourceAccent("net"), expanded ? 0.42 : 0.16)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 160
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 160
                                    }
                                }

                                Column {
                                    id: interfaceCardColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Item {
                                        width: parent.width
                                        height: Math.max(interfaceLeftInfo.implicitHeight, interfaceRightInfo.implicitHeight, 34)

                                        Column {
                                            id: interfaceLeftInfo
                                            anchors.left: parent.left
                                            anchors.right: interfaceRightInfo.left
                                            anchors.rightMargin: 12
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: modelData.name + (modelData.connection ? "  " + modelData.connection : "") + (modelData.ssid ? "  " + modelData.ssid : "")
                                                color: root.text
                                                font.pixelSize: 12
                                                font.family: root.textFont
                                                font.weight: Font.Black
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: String(modelData.kind || "interface").toUpperCase() + "  •  " + String(modelData.state || "unknown").toUpperCase() + (modelData.default_route ? "  •  DEFAULT ROUTE" : "") + (modelData.speed_mbps ? "  •  " + modelData.speed_mbps + " Mbps" : "")
                                                color: root.subtext0
                                                font.pixelSize: 10
                                                font.family: root.textFont
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Column {
                                            id: interfaceRightInfo
                                            anchors.right: interfaceArrow.left
                                            anchors.rightMargin: 10
                                            spacing: 3

                                            Text {
                                                anchors.right: parent.right
                                                text: "Down " + root.formatRate(modelData.down_bps)
                                                color: root.resourceAccent("net")
                                                font.pixelSize: 11
                                                font.family: root.textFont
                                                font.weight: Font.Black
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                text: "Up " + root.formatRate(modelData.up_bps)
                                                color: root.subtext0
                                                font.pixelSize: 10
                                                font.family: root.textFont
                                            }
                                        }

                                        Text {
                                            id: interfaceArrow
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: ""
                                            color: root.resourceAccent("net")
                                            font.pixelSize: 12
                                            font.family: "CaskaydiaMono Nerd Font"
                                            rotation: interfaceCard.expanded ? 90 : 0

                                            Behavior on rotation {
                                                NumberAnimation {
                                                    duration: 180
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                netDetailRoot.expandedInterface = interfaceCard.expanded ? "" : String(modelData.name || "");
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 10
                                        visible: interfaceCard.expanded

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: ThemePkg.Theme.withAlpha(root.resourceAccent("net"), 0.18)
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 3

                                            Text {
                                                text: "Addresses"
                                                color: root.resourceAccent("net")
                                                font.pixelSize: 10
                                                font.family: root.textFont
                                                font.weight: Font.Bold
                                            }

                                            Text {
                                                width: parent.width
                                                wrapMode: Text.Wrap
                                                text: (modelData.addresses && modelData.addresses.length) ? modelData.addresses.join(", ") : "N/A"
                                                color: root.text
                                                font.pixelSize: 11
                                                font.family: root.textFont
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 8

                                            DetailMetric {
                                                width: Math.floor((parent.width - 16) / 3)
                                                label: "MAC Address"
                                                value: modelData.mac || "N/A"
                                                secondary: modelData.virtual ? "Virtual adapter" : "Hardware adapter"
                                                accentColor: root.resourceAccent("net")
                                            }
                                            DetailMetric {
                                                width: Math.floor((parent.width - 16) / 3)
                                                label: "MTU / Carrier"
                                                value: (modelData.mtu || "N/A") + " / " + (modelData.carrier === 1 ? "Link" : "No link")
                                                secondary: "Maximum transmission unit"
                                                accentColor: root.resourceAccent("net")
                                            }
                                            DetailMetric {
                                                width: Math.floor((parent.width - 16) / 3)
                                                label: "Packets"
                                                value: "RX " + (modelData.rx_packets || 0) + " / TX " + (modelData.tx_packets || 0)
                                                secondary: "Frames transferred"
                                                accentColor: root.resourceAccent("net")
                                            }
                                            DetailMetric {
                                                width: Math.floor((parent.width - 16) / 3)
                                                label: "Errors"
                                                value: "RX " + (modelData.rx_errors || 0) + " / TX " + (modelData.tx_errors || 0)
                                                secondary: "Interface errors"
                                                accentColor: root.resourceAccent("net")
                                            }
                                            DetailMetric {
                                                width: Math.floor((parent.width - 16) / 3)
                                                label: "Dropped"
                                                value: "RX " + (modelData.rx_dropped || 0) + " / TX " + (modelData.tx_dropped || 0)
                                                secondary: "Dropped packets"
                                                accentColor: root.resourceAccent("net")
                                            }
                                        }

                                        Text {
                                            text: "Top Processes by Active Sockets"
                                            color: root.text
                                            font.pixelSize: 11
                                            font.family: root.textFont
                                            font.weight: Font.Black
                                        }

                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: netData.process_telemetry_note || "Best effort attribution for visible sockets on this interface. Sorted by socket count."
                                            color: root.subtext0
                                            font.pixelSize: 10
                                            font.family: root.textFont
                                        }

                                        Text {
                                            visible: !(modelData.top_processes && modelData.top_processes.length)
                                            text: "No attributable process sockets visible for this interface right now."
                                            color: root.subtext0
                                            font.pixelSize: 11
                                            font.family: root.textFont
                                        }

                                        Repeater {
                                            model: modelData.top_processes || []
                                            delegate: DetailEntryRow {
                                                width: parent.width
                                                title: (index + 1) + ". " + modelData.name
                                                subtitle: "PID " + modelData.pid + "  •  TCP " + modelData.tcp + "  •  UDP " + modelData.udp + "  •  Established " + modelData.established + (modelData.peers && modelData.peers.length ? "  •  " + modelData.peers.join(", ") : "")
                                                primaryValue: modelData.sockets + (modelData.sockets === 1 ? " socket" : " sockets")
                                                accentColor: root.resourceAccent("net")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                DetailSection {
                    width: parent.width
                    title: "Socket Summary"
                    subtitle: "Current local TCP and UDP socket counts."
                    accentColor: root.resourceAccent("net")

                    Flow {
                        width: parent.width
                        spacing: 10

                        DetailMetric {
                            width: Math.floor((parent.width - 30) / 4)
                            label: "Sockets"
                            value: String(socketData.total || 0)
                            secondary: "Tracked endpoints"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 30) / 4)
                            label: "TCP"
                            value: String(socketData.tcp || 0)
                            secondary: "TCP sockets"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 30) / 4)
                            label: "UDP"
                            value: String(socketData.udp || 0)
                            secondary: "UDP sockets"
                            accentColor: root.resourceAccent("net")
                        }
                        DetailMetric {
                            width: Math.floor((parent.width - 30) / 4)
                            label: "Established"
                            value: String(socketData.established || 0)
                            secondary: "Active TCP links"
                            accentColor: root.resourceAccent("net")
                        }
                    }
                }
            }
        }
    }

    component UpdateBubble: Item {
        id: bubble
        property string value: "0"
        property string label: ""
        property bool compact: false
        property color accentColor: root.activeColor
        property real fillLevel: 0.0
        property real updateProgress: 0.0
        property bool triggered: false
        property real flashOpacity: 0.0
        property int holdDuration: 700
        property bool isUpdateRunning: false
        property bool isUpdateResult: false
        property bool isUpdateError: false
        readonly property bool showUpdateState: isUpdateRunning || isUpdateResult
        readonly property bool progressSliceActive: isUpdateRunning
        readonly property color updateStateColor: isUpdateError ? root.red : (isUpdateRunning ? bubble.accentColor : root.success)
        readonly property color effectiveAccent: showUpdateState ? updateStateColor : accentColor
        readonly property bool hovered: bubbleMa.containsMouse
        readonly property bool isDangerState: bubble.hovered || bubble.fillLevel > 0.0
        readonly property color bubbleTopColor: bubble.progressSliceActive ? Qt.lighter(root.surface1, 1.12) : (bubble.showUpdateState ? Qt.lighter(bubble.effectiveAccent, 1.15) : (bubble.isDangerState ? Qt.lighter(root.red, 1.15) : Qt.lighter(accentColor, 1.15)))
        readonly property color bubbleBottomColor: bubble.progressSliceActive ? root.surface0 : (bubble.showUpdateState ? bubble.effectiveAccent : (bubble.isDangerState ? root.red : accentColor))
        readonly property color bubbleBorderColor: bubble.showUpdateState ? Qt.lighter(bubble.effectiveAccent, 1.1) : (bubble.isDangerState ? root.maroon : Qt.lighter(accentColor, 1.1))
        readonly property color bubbleWaveTopColor: root.surface1
        readonly property color bubbleWaveBottomColor: root.crust
        readonly property color bubbleGlowColor: bubble.showUpdateState ? bubble.effectiveAccent : (bubble.isDangerState ? root.red : bubble.accentColor)
        readonly property color bubblePulseColor: bubble.showUpdateState ? bubble.effectiveAccent : (bubble.isDangerState ? root.red : bubble.accentColor)
        readonly property color bubblePrimaryTextColor: bubble.progressSliceActive ? root.text : root.crust
        readonly property color bubbleSecondaryTextColor: bubble.progressSliceActive ? root.subtext0 : (bubble.hovered ? root.crust : "#99000000")
        readonly property real progressAccentLuma: (bubble.effectiveAccent.r * 0.299) + (bubble.effectiveAccent.g * 0.587) + (bubble.effectiveAccent.b * 0.114)
        readonly property color progressSliceColor: bubble.progressAccentLuma < 0.36 ? ThemePkg.Theme.mix(bubble.effectiveAccent, root.text, 0.52) : bubble.effectiveAccent
        readonly property real waveAmplitude: compact ? 6 : 10
        readonly property real glowBaseOpacity: compact ? 0.14 : 0.18
        readonly property real pulseBaseOpacity: compact ? 0.24 : 0.30
        signal holdComplete
        signal holdCompleteRight
        signal clicked
        signal cancelRequested
        property int pressedButton: Qt.LeftButton
        property bool syntheticRightHold: false
        property bool suppressNextClick: false
        property double lastRightReleaseMs: 0
        property int doubleTapHoldWindow: 350

        Behavior on updateProgress {
            NumberAnimation {
                duration: 360
                easing.type: Easing.OutCubic
            }
        }

        function canvasColor(colorValue, lightenAmount, alpha) {
            var c = colorValue || root.accent;
            var amount = Math.max(0.0, Math.min(1.0, lightenAmount || 0.0));
            var r = Math.round((c.r + (1.0 - c.r) * amount) * 255);
            var g = Math.round((c.g + (1.0 - c.g) * amount) * 255);
            var b = Math.round((c.b + (1.0 - c.b) * amount) * 255);
            var a = alpha === undefined ? 1.0 : Math.max(0.0, Math.min(1.0, alpha));
            return "rgba(" + r + "," + g + "," + b + "," + a + ")";
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + (bubble.compact ? 14 : 24)
            height: width
            radius: width / 2
            color: "#000000"
            opacity: bubble.compact ? 0.14 : 0.18
            z: -3
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + (bubble.compact ? 20 : 40)
            height: width
            radius: width / 2
            color: bubble.bubbleGlowColor
            opacity: bubble.isDangerState ? 0.30 : bubble.glowBaseOpacity
            z: -2
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: ThemePkg.Theme.edgeAnimationsEnabled
                NumberAnimation {
                    to: bubble.hovered ? 1.15 : 1.10
                    duration: bubble.hovered ? 800 : 2000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.0
                    duration: bubble.hovered ? 800 : 2000
                    easing.type: Easing.InOutSine
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + (bubble.compact ? 10 : 15)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: bubble.compact ? 2 : 3
            border.color: bubble.bubblePulseColor
            opacity: pulseOpacity
            scale: pulseScale
            z: -1

            property real pulseOpacity: 0.0
            property real pulseScale: 1.0

            Timer {
                interval: 45
                running: parent.visible && ThemePkg.Theme.edgeAnimationsEnabled
                repeat: true
                onTriggered: {
                    var time = Date.now() / 1000;
                    parent.pulseOpacity = bubble.pulseBaseOpacity + Math.sin(time * 2.5) * 0.15;
                    parent.pulseScale = 1.01 + Math.cos(time * 3.0) * 0.02;
                }
            }
        }

        Rectangle {
            id: bubbleShell
            anchors.fill: parent
            radius: width / 2
            border.width: 1
            border.color: bubble.bubbleBorderColor
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: bubble.bubbleTopColor
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                        }
                    }
                }
                GradientStop {
                    position: 1.0
                    color: bubble.bubbleBottomColor
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                        }
                    }
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }
            }
            layer.enabled: true
            layer.smooth: true
        }

        Canvas {
            id: progressSliceCanvas
            anchors.fill: parent
            visible: bubble.progressSliceActive
            opacity: 0.96
            z: 2

            Connections {
                target: bubble
                function onUpdateProgressChanged() {
                    progressSliceCanvas.requestPaint();
                }
                function onEffectiveAccentChanged() {
                    progressSliceCanvas.requestPaint();
                }
                function onProgressSliceColorChanged() {
                    progressSliceCanvas.requestPaint();
                }
                function onProgressSliceActiveChanged() {
                    progressSliceCanvas.requestPaint();
                }
            }
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!bubble.progressSliceActive)
                    return;

                var progress = Math.max(0.0, Math.min(1.0, bubble.updateProgress));
                if (progress <= 0.001)
                    return;

                var cx = width / 2;
                var cy = height / 2;
                var radius = Math.max(0, Math.min(width, height) / 2 - 1);
                var startAngle = -Math.PI / 2;
                var endAngle = startAngle + (Math.PI * 2 * progress);

                ctx.save();
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.clip();

                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, radius, startAngle, endAngle, false);
                ctx.closePath();

                var grad = ctx.createRadialGradient(cx, cy, radius * 0.08, cx, cy, radius);
                grad.addColorStop(0.0, bubble.canvasColor(bubble.progressSliceColor, 0.32, 1.0));
                grad.addColorStop(0.58, bubble.canvasColor(bubble.progressSliceColor, 0.10, 1.0));
                grad.addColorStop(1.0, bubble.canvasColor(bubble.progressSliceColor, 0.0, 1.0));
                ctx.fillStyle = grad;
                ctx.fill();

                ctx.restore();
            }
        }

        Rectangle {
            anchors.fill: bubbleShell
            radius: bubbleShell.radius
            z: 1
            color: "transparent"
            border.width: 1
            border.color: ThemePkg.Theme.withAlpha("#ffffff", bubble.hovered ? 0.08 : 0.04)
        }

        Canvas {
            id: waveCanvas
            anchors.fill: parent
            visible: bubble.fillLevel > 0.0
            opacity: 0.95
            z: 2
            property real wavePhase: 0.0

            NumberAnimation on wavePhase {
                running: bubble.fillLevel > 0.0 && bubble.fillLevel < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                loops: Animation.Infinite
                from: 0
                to: Math.PI * 2
                duration: 800
            }

            onWavePhaseChanged: requestPaint()
            Connections {
                target: bubble
                function onFillLevelChanged() {
                    waveCanvas.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (bubble.fillLevel <= 0.001)
                    return;

                var radius = width / 2;
                var fillY = height * (1.0 - bubble.fillLevel);
                ctx.save();
                ctx.beginPath();
                ctx.arc(radius, radius, radius, 0, 2 * Math.PI);
                ctx.clip();
                ctx.beginPath();
                ctx.moveTo(0, fillY);
                if (bubble.fillLevel < 0.99) {
                    var waveAmp = bubble.waveAmplitude * Math.sin(bubble.fillLevel * Math.PI);
                    var cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                    var cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                    ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                } else {
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                }
                ctx.closePath();
                var grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, bubble.bubbleWaveTopColor.toString());
                grad.addColorStop(1, bubble.bubbleWaveBottomColor.toString());
                ctx.fillStyle = grad;
                ctx.fill();
                ctx.restore();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: bubbleShell.radius
            color: "#ffffff"
            opacity: bubble.flashOpacity
            z: 3
        }

        ColumnLayout {
            id: bubbleBaseText
            anchors.centerIn: parent
            z: 4
            spacing: bubble.compact ? 1 : 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: bubble.value
                font.family: root.textFont
                font.weight: Font.Black
                font.pixelSize: bubble.showUpdateState ? (bubble.compact ? 18 : 32) : (bubble.compact ? 22 : 42)
                color: bubble.bubblePrimaryTextColor
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: bubble.fillLevel > 0.01 ? (root.updateRunning ? "Cancel..." : "Hold...") : bubble.label
                font.family: root.textFont
                font.weight: Font.Bold
                font.pixelSize: bubble.compact ? 9 : 11
                color: bubble.fillLevel > 0.01 ? bubble.bubblePrimaryTextColor : bubble.bubbleSecondaryTextColor
            }
        }

        Item {
            id: waveClipItem
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(parent.height, Math.max(0, parent.height * bubble.fillLevel + 8))
            clip: true
            visible: bubble.fillLevel > 0.0
            z: 4

            ColumnLayout {
                spacing: bubble.compact ? 1 : 2
                x: waveClipItem.width / 2 - width / 2
                y: (bubble.height / 2) - (height / 2) - (bubble.height - waveClipItem.height)

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: bubble.value
                    font.family: root.textFont
                    font.weight: Font.Black
                    font.pixelSize: bubble.showUpdateState ? (bubble.compact ? 18 : 32) : (bubble.compact ? 22 : 42)
                    color: root.text
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: bubble.fillLevel > 0.01 ? (root.updateRunning ? "Cancel..." : "Hold...") : bubble.label
                    font.family: root.textFont
                    font.weight: Font.Bold
                    font.pixelSize: bubble.compact ? 9 : 11
                    color: root.text
                }
            }
        }

        MouseArea {
            id: bubbleMa
            anchors.fill: parent
            z: 5
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (bubble.suppressNextClick) {
                    suppressClickResetTimer.stop();
                    bubble.suppressNextClick = false;
                    return;
                }
                if (root.updateRunning)
                    bubble.clicked();
            }
            onPressed: mouse => {
                if (root.updateRunning && mouse.button !== Qt.LeftButton)
                    return;
                var now = Date.now();
                bubble.pressedButton = mouse.button;
                bubble.syntheticRightHold = mouse.button === Qt.RightButton && bubble.lastRightReleaseMs > 0 && (now - bubble.lastRightReleaseMs) <= bubble.doubleTapHoldWindow;
                if (bubble.syntheticRightHold) {
                    bubble.lastRightReleaseMs = 0;
                }
                if (!bubble.triggered) {
                    drainAnim.stop();
                    fillAnim.start();
                }
            }
            onReleased: {
                if (root.updateRunning && bubble.triggered)
                    return;
                if (!bubble.triggered) {
                    if (bubble.pressedButton === Qt.RightButton) {
                        bubble.lastRightReleaseMs = Date.now();
                        if (bubble.syntheticRightHold) {
                            return;
                        }
                    }
                    fillAnim.stop();
                    drainAnim.start();
                }
            }
            onCanceled: {
                if (!bubble.triggered) {
                    bubble.syntheticRightHold = false;
                    fillAnim.stop();
                    drainAnim.start();
                }
            }
        }

        Timer {
            id: suppressClickResetTimer
            interval: 450
            repeat: false
            onTriggered: bubble.suppressNextClick = false
        }

        NumberAnimation {
            id: fillAnim
            target: bubble
            property: "fillLevel"
            to: 1.0
            duration: bubble.holdDuration * (1.0 - bubble.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                if (!bubble.triggered) {
                    bubble.triggered = true;
                    bubble.suppressNextClick = true;
                    suppressClickResetTimer.restart();
                    bubble.flashOpacity = 0.6;
                    flashDrainAnim.start();
                    if (root.updateRunning) {
                        bubble.cancelRequested();
                    } else if (bubble.pressedButton === Qt.RightButton) {
                        bubble.holdCompleteRight();
                    } else {
                        bubble.holdComplete();
                    }
                    bubble.syntheticRightHold = false;
                    bubble.fillLevel = 0.0;
                    bubble.triggered = false;
                }
            }
        }

        NumberAnimation {
            id: drainAnim
            target: bubble
            property: "fillLevel"
            to: 0.0
            duration: 1000 * bubble.fillLevel
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: flashDrainAnim
            target: bubble
            property: "flashOpacity"
            to: 0.0
            duration: 450
            easing.type: Easing.OutExpo
        }
    }

    component HoverToolTip: ToolTip {
        id: hoverToolTipRoot

        x: parent ? Math.round((parent.width - implicitWidth) / 2) : 0
        y: -implicitHeight - 3
        margins: 6
        horizontalPadding: 8
        verticalPadding: 6

        background: Rectangle {
            radius: 10
            color: root.base
            border.width: 1
            border.color: root.panelBorderColor
        }

        contentItem: Text {
            text: hoverToolTipRoot.text
            color: root.accent
            font.pixelSize: 13
            font.family: "Fira Sans Semibold"
            wrapMode: Text.Wrap
        }
    }

    component ToolBtn: Rectangle {
        id: toolBtnRoot
        width: 42
        height: 42
        radius: 10
        property string icon: ""
        property string tip: ""
        property bool isActive: false
        property color activeColor: root.accent
        property bool requireHold: false
        property int holdDuration: 600
        signal btnClicked

        property real fillLevel: 0.0
        property bool triggered: false
        property real flashOpacity: 0.0
        readonly property color fillColor: activeColor
        readonly property color fillColor2: Qt.lighter(activeColor, 1.2)

        color: isActive ? (toolBtnMa.containsMouse ? ThemePkg.Theme.withAlpha(activeColor, 0.85) : ThemePkg.Theme.withAlpha(activeColor, 0.7)) : (toolBtnMa.containsMouse ? "#14ffffff" : "#0dffffff")
        border.color: toolBtnMa.containsMouse ? root.accent : "#1affffff"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        scale: toolBtnMa.pressed ? (toolBtnRoot.requireHold ? 0.95 : 0.92) : (toolBtnMa.containsMouse ? (toolBtnRoot.requireHold ? 1.05 : 1.06) : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: toolBtnRoot.requireHold ? 400 : 200
                easing.type: toolBtnRoot.requireHold ? Easing.OutQuart : Easing.OutCubic
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Canvas {
                id: toolBtnWaveCanvas
                anchors.fill: parent

                property real wavePhase: 0.0
                NumberAnimation on wavePhase {
                    running: toolBtnRoot.requireHold && toolBtnRoot.fillLevel > 0.0 && toolBtnRoot.fillLevel < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: 800
                }
                onWavePhaseChanged: requestPaint()
                Connections {
                    target: toolBtnRoot
                    function onFillLevelChanged() {
                        toolBtnWaveCanvas.requestPaint();
                    }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!toolBtnRoot.requireHold || toolBtnRoot.fillLevel <= 0.001)
                        return;

                    var r = toolBtnRoot.radius;
                    var fillY = height * (1.0 - toolBtnRoot.fillLevel);
                    ctx.save();
                    ctx.beginPath();
                    ctx.moveTo(r, 0);
                    ctx.lineTo(width - r, 0);
                    ctx.arcTo(width, 0, width, r, r);
                    ctx.lineTo(width, height - r);
                    ctx.arcTo(width, height, width - r, height, r);
                    ctx.lineTo(r, height);
                    ctx.arcTo(0, height, 0, height - r, r);
                    ctx.lineTo(0, r);
                    ctx.arcTo(0, 0, r, 0, r);
                    ctx.closePath();
                    ctx.clip();

                    ctx.beginPath();
                    ctx.moveTo(0, fillY);
                    if (toolBtnRoot.fillLevel < 0.99) {
                        var waveAmp = 5 * Math.sin(toolBtnRoot.fillLevel * Math.PI);
                        var cp1y = fillY + Math.sin(toolBtnWaveCanvas.wavePhase) * waveAmp;
                        var cp2y = fillY + Math.cos(toolBtnWaveCanvas.wavePhase + Math.PI) * waveAmp;
                        ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                    } else {
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                    }
                    ctx.closePath();

                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, toolBtnRoot.fillColor.toString());
                    grad.addColorStop(1, toolBtnRoot.fillColor2.toString());
                    ctx.fillStyle = grad;
                    ctx.fill();
                    ctx.restore();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: toolBtnRoot.icon
            color: toolBtnRoot.isActive ? ThemePkg.Theme.c15 : root.text
            font.pixelSize: toolBtnRoot.icon.length > 1 ? 13 : 18
            font.family: "CaskaydiaMono Nerd Font"
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: toolBtnRoot.height * toolBtnRoot.fillLevel
            clip: true
            visible: toolBtnRoot.requireHold && toolBtnRoot.fillLevel > 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (toolBtnRoot.height / 2) - (height / 2) - (toolBtnRoot.height - parent.height)
                text: toolBtnRoot.icon
                color: root.crust
                font.pixelSize: toolBtnRoot.icon.length > 1 ? 13 : 18
                font.family: "CaskaydiaMono Nerd Font"
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: toolBtnRoot.radius
            color: "#ffffff"
            opacity: toolBtnRoot.flashOpacity
            visible: toolBtnRoot.requireHold
            PropertyAnimation on opacity {
                id: toolBtnFlashAnim
                to: 0
                duration: 500
                easing.type: Easing.OutExpo
            }
        }

        MouseArea {
            id: toolBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: toolBtnRoot.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
            onPressed: {
                if (toolBtnRoot.requireHold && !toolBtnRoot.triggered) {
                    toolBtnDrainAnim.stop();
                    toolBtnFillAnim.start();
                }
            }
            onReleased: {
                if (toolBtnRoot.requireHold && !toolBtnRoot.triggered && toolBtnRoot.fillLevel < 1.0) {
                    toolBtnFillAnim.stop();
                    toolBtnDrainAnim.start();
                }
            }
            onCanceled: {
                if (toolBtnRoot.requireHold && !toolBtnRoot.triggered) {
                    toolBtnFillAnim.stop();
                    toolBtnDrainAnim.start();
                }
            }
            onClicked: {
                if (!toolBtnRoot.requireHold)
                    toolBtnRoot.btnClicked();
            }
        }

        HoverToolTip {
            visible: toolBtnMa.containsMouse
            delay: 250
            text: toolBtnRoot.tip
        }

        NumberAnimation {
            id: toolBtnFillAnim
            target: toolBtnRoot
            property: "fillLevel"
            to: 1.0
            duration: toolBtnRoot.holdDuration * (1.0 - toolBtnRoot.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                toolBtnRoot.triggered = true;
                toolBtnRoot.flashOpacity = 0.6;
                toolBtnFlashAnim.start();
                toolBtnTriggerTimer.start();
            }
        }

        NumberAnimation {
            id: toolBtnDrainAnim
            target: toolBtnRoot
            property: "fillLevel"
            to: 0.0
            duration: 1500 * toolBtnRoot.fillLevel
            easing.type: Easing.OutQuad
        }

        Timer {
            id: toolBtnTriggerTimer
            interval: 500
            onTriggered: {
                toolBtnRoot.btnClicked();
                toolBtnResetAnim.start();
            }
        }

        NumberAnimation {
            id: toolBtnResetAnim
            target: toolBtnRoot
            property: "fillLevel"
            to: 0.0
            duration: 350
            easing.type: Easing.OutExpo
            onFinished: toolBtnRoot.triggered = false
        }
    }

    component ResCard: Rectangle {
        id: resCardRoot
        width: root.resourceCardWidth
        height: 76
        radius: 14
        property string title: ""
        property string value: ""
        property string tip: ""
        property string resourceKey: ""
        property bool selected: false
        property color accentColor: root.accent
        property int holdDuration: 600
        property real fillLevel: 0.0
        property bool triggered: false
        property real flashOpacity: 0.0
        signal cardTriggered

        readonly property color fillColor: accentColor
        readonly property color fillColor2: Qt.lighter(accentColor, 1.18)

        color: selected ? ThemePkg.Theme.withAlpha(accentColor, resMa.containsMouse ? 0.20 : 0.14) : (resMa.containsMouse ? "#14ffffff" : "#08ffffff")
        border.color: selected ? ThemePkg.Theme.withAlpha(accentColor, 0.72) : (resMa.containsMouse ? ThemePkg.Theme.withAlpha(accentColor, 0.58) : "#1affffff")
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }
        scale: resMa.pressed ? 0.96 : ((resMa.containsMouse || selected) ? 1.03 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: selected ? 1 : 0
            border.color: ThemePkg.Theme.withAlpha(accentColor, 0.22)
        }

        Item {
            anchors.fill: parent
            clip: true

            Canvas {
                id: resWaveCanvas
                anchors.fill: parent
                property real wavePhase: 0.0

                NumberAnimation on wavePhase {
                    running: resCardRoot.fillLevel > 0.0 && resCardRoot.fillLevel < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: 800
                }

                onWavePhaseChanged: requestPaint()
                Connections {
                    target: resCardRoot
                    function onFillLevelChanged() {
                        resWaveCanvas.requestPaint();
                    }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (resCardRoot.fillLevel <= 0.001)
                        return;

                    var r = resCardRoot.radius;
                    var fillY = height * (1.0 - resCardRoot.fillLevel);

                    ctx.save();
                    ctx.beginPath();
                    ctx.moveTo(r, 0);
                    ctx.lineTo(width - r, 0);
                    ctx.arcTo(width, 0, width, r, r);
                    ctx.lineTo(width, height - r);
                    ctx.arcTo(width, height, width - r, height, r);
                    ctx.lineTo(r, height);
                    ctx.arcTo(0, height, 0, height - r, r);
                    ctx.lineTo(0, r);
                    ctx.arcTo(0, 0, r, 0, r);
                    ctx.closePath();
                    ctx.clip();

                    ctx.beginPath();
                    ctx.moveTo(0, fillY);
                    if (resCardRoot.fillLevel < 0.99) {
                        var waveAmp = 6 * Math.sin(resCardRoot.fillLevel * Math.PI);
                        var cp1y = fillY + Math.sin(resWaveCanvas.wavePhase) * waveAmp;
                        var cp2y = fillY + Math.cos(resWaveCanvas.wavePhase + Math.PI) * waveAmp;
                        ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                    } else {
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                    }
                    ctx.closePath();

                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, resCardRoot.fillColor.toString());
                    grad.addColorStop(1, resCardRoot.fillColor2.toString());
                    ctx.fillStyle = grad;
                    ctx.fill();
                    ctx.restore();
                }
            }
        }

        MouseArea {
            id: resMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: resCardRoot.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
            onPressed: {
                if (!resCardRoot.triggered) {
                    resDrainAnim.stop();
                    resFillAnim.start();
                }
            }
            onReleased: {
                if (!resCardRoot.triggered && resCardRoot.fillLevel < 1.0) {
                    resFillAnim.stop();
                    resDrainAnim.start();
                }
            }
            onCanceled: {
                if (!resCardRoot.triggered) {
                    resFillAnim.stop();
                    resDrainAnim.start();
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 3
            Text {
                text: resCardRoot.value
                color: resCardRoot.selected ? resCardRoot.accentColor : root.text
                font.pixelSize: resCardRoot.value.length > 11 ? 16 : (resCardRoot.value.length > 8 ? 18 : 20)
                font.family: root.textFont
                font.weight: Font.Black
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: resCardRoot.fillLevel > 0.01 ? "Hold..." : resCardRoot.title
                color: root.subtext0
                font.pixelSize: 10
                font.family: root.textFont
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: resCardRoot.height * resCardRoot.fillLevel
            clip: true
            visible: resCardRoot.fillLevel > 0

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (resCardRoot.height / 2) - (height / 2) - (resCardRoot.height - parent.height)
                spacing: 3

                Text {
                    text: resCardRoot.value
                    color: root.crust
                    font.pixelSize: resCardRoot.value.length > 11 ? 16 : (resCardRoot.value.length > 8 ? 18 : 20)
                    font.family: root.textFont
                    font.weight: Font.Black
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: resCardRoot.fillLevel > 0.01 ? "Hold..." : resCardRoot.title
                    color: root.crust
                    font.pixelSize: 10
                    font.family: root.textFont
                    font.weight: Font.Bold
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: resCardRoot.radius
            color: "#ffffff"
            opacity: resCardRoot.flashOpacity
        }

        NumberAnimation {
            id: resFillAnim
            target: resCardRoot
            property: "fillLevel"
            to: 1.0
            duration: resCardRoot.holdDuration * (1.0 - resCardRoot.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                if (!resCardRoot.triggered) {
                    resCardRoot.triggered = true;
                    resCardRoot.flashOpacity = 0.55;
                    resFlashAnim.start();
                    resTriggerTimer.start();
                }
            }
        }

        NumberAnimation {
            id: resDrainAnim
            target: resCardRoot
            property: "fillLevel"
            to: 0.0
            duration: 1200 * resCardRoot.fillLevel
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: resFlashAnim
            target: resCardRoot
            property: "flashOpacity"
            to: 0.0
            duration: 420
            easing.type: Easing.OutExpo
        }

        Timer {
            id: resTriggerTimer
            interval: 360
            onTriggered: {
                resCardRoot.cardTriggered();
                resResetAnim.start();
            }
        }

        NumberAnimation {
            id: resResetAnim
            target: resCardRoot
            property: "fillLevel"
            to: 0.0
            duration: 320
            easing.type: Easing.OutExpo
            onFinished: resCardRoot.triggered = false
        }
    }

}
