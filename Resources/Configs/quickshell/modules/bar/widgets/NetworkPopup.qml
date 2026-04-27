import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Controls
import "../../theme" as ThemePkg

Item {
    id: window
    focus: true
    anchors.fill: parent

    readonly property int panelWidth: 860
    readonly property int panelHeight: 600
    readonly property int panelMargin: 16
    readonly property real popupOpenWidth: panelWidth
    readonly property real popupOpenHeight: panelHeight
    readonly property real popupClosedWidth: panelWidth - 44
    readonly property real popupClosedHeight: panelHeight - 28
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 34
    readonly property int overlayEnterDuration: 405
    readonly property int overlayExitDuration: 305
    readonly property bool overlayOwnsCloseAnimation: true
    property bool popupTargetVisible: false
    property var overlaySwitcher: null
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity

    Shortcut {
        sequence: "Tab"
        onActivated: {
            window.activeMode = window.activeMode === "wifi" ? "bt" : "wifi";
        }
    }

    QtObject {
        id: cache
        property string lastWifiSsid: ""
        property string lastWifiJson: ""
        property string lastBtJson: ""
        
        onLastWifiSsidChanged: {
            if (window.introState === 1.0) cacheSaveTimer.restart();
        }
        onLastWifiJsonChanged: {
            if (window.introState === 1.0) cacheSaveTimer.restart();
        }
        onLastBtJsonChanged: {
            if (window.introState === 1.0) cacheSaveTimer.restart();
        }
    }

    Timer {
        id: cacheSaveTimer
        interval: 1000
        running: false
        onTriggered: {
            let data = {
                lastWifiSsid: cache.lastWifiSsid,
                lastWifiJson: cache.lastWifiJson,
                lastBtJson: cache.lastBtJson
            };
            let jsonStr = JSON.stringify(data);
            let escaped = "'" + jsonStr.replace(/'/g, "'\\''") + "'";
            Quickshell.execDetached(["bash", "-c", "mkdir -p ~/.cache/quickshell && echo " + escaped + " > ~/.cache/quickshell/network_cache.json"]);
        }
    }

    Process {
        id: cacheReader
        command: ["bash", "-c", "cat ~/.cache/quickshell/network_cache.json 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim();
                let initialSsid = "";
                if (text !== "") {
                    try {
                        let data = JSON.parse(text);
                        if (data.lastWifiSsid !== undefined) {
                            cache.lastWifiSsid = data.lastWifiSsid;
                            initialSsid = data.lastWifiSsid;
                        }
                        if (data.lastWifiJson !== undefined) {
                            cache.lastWifiJson = data.lastWifiJson;
                        }
                        if (data.lastBtJson !== undefined) {
                            cache.lastBtJson = data.lastBtJson;
                        }
                    } catch (e) {
                         console.log("Failed to load network cache:", e);
                    }
                }
                if (cache.lastWifiJson !== "") processWifiJson(cache.lastWifiJson);
                if (cache.lastBtJson !== "") processBtJson(cache.lastBtJson);
                if (initialSsid !== "") cache.lastWifiSsid = initialSsid;
                syncCores();
            }
        }
    }

    property bool ignoreNextModeFileUpdate: false
    Process {
        id: modeReader
        command: ["bash", "-c", "cat /tmp/qs_network_mode 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let mode = this.text.trim();
                if ((mode === "wifi" || mode === "bt") && window.activeMode !== mode) {
                    window.ignoreNextModeFileUpdate = true;
                    window.activeMode = mode;
                }
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: modeReader.running = true
    }

    Component.onCompleted: {
        popupTargetVisible = true;
        Quickshell.execDetached(["bash", "-c", "if [ ! -f /tmp/qs_network_mode ]; then echo '" + activeMode + "' > /tmp/qs_network_mode; fi"]);
        window.resetSpeedtestState();
        if (cache.lastWifiJson !== "")
            processWifiJson(cache.lastWifiJson);
        if (cache.lastBtJson !== "")
            processBtJson(cache.lastBtJson);
        syncCores();
        introState = 1.0;
        trafficPoller.running = true;
        speedtestPollerProc.running = true;
        tailscalePoller.running = true;
        popupEnterAnim.start();
    }

    Component.onDestruction: {
        window.clearSpeedtestSession();
    }

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
    readonly property color mauve: ThemePkg.Theme.c5
    readonly property color pink: ThemePkg.Theme.c13
    readonly property color sapphire: ThemePkg.Theme.c4
    readonly property color blue: ThemePkg.Theme.c4
    readonly property color red: ThemePkg.Theme.danger
    readonly property color maroon: ThemePkg.Theme.c1
    readonly property color peach: ThemePkg.Theme.warning
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property string textFont: "Fira Sans"

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/network"
    readonly property string trafficScriptPath: window.scriptsDir + "/traffic_panel_logic.sh"
    readonly property string speedtestScriptPath: window.scriptsDir + "/speedtest_panel_logic.sh"
    readonly property string tailscaleScriptPath: window.scriptsDir + "/tailscale_panel_logic.sh"
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string speedtestCacheFile: window.runtimeDir + "/quickshell/speedtest_status.json"

    readonly property color networkAccent: Qt.lighter(window.sapphire, 1.15)
    readonly property color wifiAccent: window.networkAccent
    readonly property color btAccent: window.networkAccent
    readonly property color ethAccent: Qt.lighter(window.peach, 1.10)
    property string activeMode: "wifi"
    readonly property color activeColor: {
        if (activeMode === "wifi") {
            if (window.isEthConn && !window.isWifiConn)
                return window.ethAccent;
            return window.wifiAccent;
        }
        return window.btAccent;
    }
    readonly property color activeGradientSecondary: Qt.darker(window.activeColor, 1.25)
    property string trafficIface: ""
    property string trafficDownRateText: "0 B/s"
    property string trafficUpRateText: "0 B/s"
    readonly property string trafficSummaryText: "↓ " + trafficDownRateText + "  ↑ " + trafficUpRateText
    property bool tailscaleActive: false
    property string tailscaleSummaryText: "Tailscale"
    property string tailscaleDetailText: ""

    function batteryGlyphFor(p, charging) {
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

    property string speedtestState: "idle"
    property string speedtestHeadline: ""
    property string speedtestSubline: ""

    property var busyTasks: ({})
    property var disconnectingDevices: ({})
    property var wifiList: []
    property string strongestWifiSsid: ""
    Timer {
        id: busyTimeout
        interval: 15000
        onTriggered: {
            window.busyTasks = ({});
            window.disconnectingDevices = ({});
        }
    }

    Timer {
        id: wifiPendingReset
        interval: 8000
        onTriggered: {
            window.wifiPowerPending = false;
            window.expectedWifiPower = "";
        }
    }
    Timer {
        id: btPendingReset
        interval: 8000
        onTriggered: {
            window.btPowerPending = false;
            window.expectedBtPower = "";
        }
    }

    property bool showInfoView: false
    property var currentCores: [null, null, null, null, null]
    property var coreVisualIndices: [0, 0, 0, 0, 0]
    property int activeCoreCount: 0
    property real smoothedActiveCoreCount: activeCoreCount
    Behavior on smoothedActiveCoreCount {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.InOutExpo
        }
    }

    function syncCores() {
        let list = [];
        if (activeMode === "wifi") {
            if (isEthConn && ethernetData)
                list = [window.ethernetData];
            else if (isWifiConn && wifiConnected)
                list = [window.wifiConnected];
        } else {
            list = window.btConnected;
        }
        if (!currentPower)
            list = [];
        else {
            if (!Array.isArray(list))
                list = [list];
        }

        let newCores = [window.currentCores[0], window.currentCores[1], window.currentCores[2], window.currentCores[3], window.currentCores[4]];
        let found = [false, false, false, false, false];

        for (let i = 0; i < list.length && i < 5; i++) {
            let dev = list[i];
            let id = window.activeMode === "wifi" ? dev.ssid : dev.mac;
            for (let c = 0; c < 5; c++) {
                if (newCores[c] && (window.activeMode === "wifi" ? newCores[c].ssid : newCores[c].mac) === id) {
                    found[c] = true;
                    newCores[c] = dev;
                    break;
                }
            }
        }
        for (let c = 0; c < 5; c++) {
            if (!found[c])
                newCores[c] = null;
        }
        for (let i = 0; i < list.length && i < 5; i++) {
            let dev = list[i];
            let id = window.activeMode === "wifi" ? dev.ssid : dev.mac;
            let isFound = false;
            for (let c = 0; c < 5; c++) {
                if (newCores[c] && (window.activeMode === "wifi" ? newCores[c].ssid : newCores[c].mac) === id) {
                    isFound = true;
                    break;
                }
            }
            if (!isFound) {
                for (let c = 0; c < 5; c++) {
                    if (!newCores[c]) {
                        newCores[c] = dev;
                        break;
                    }
                }
            }
        }
        window.currentCores = newCores;
        let activeCount = 0;
        let newVis = [0, 0, 0, 0, 0];
        for (let c = 0; c < 5; c++) {
            if (newCores[c]) {
                newVis[c] = activeCount;
                activeCount++;
            }
        }
        window.coreVisualIndices = newVis;
        window.activeCoreCount = activeCount;
    }

    function formatBytesPerSecond(bytesPerSecond) {
        let value = Math.max(0, bytesPerSecond || 0);
        let units = ["B/s", "K/s", "M/s", "G/s"];
        let unitIndex = 0;
        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024;
            unitIndex++;
        }
        let decimals = value >= 100 ? 0 : 1;
        return parseFloat(value.toFixed(decimals)).toString() + units[unitIndex];
    }

    function resetTrafficStats() {
        window.trafficIface = "";
        window.trafficDownRateText = "0 B/s";
        window.trafficUpRateText = "0 B/s";
    }

    function consumeTrafficStatsSample(textData) {
        if (window.activeMode !== "wifi" || !window.currentConn) {
            window.resetTrafficStats();
            return;
        }

        let trimmed = (textData || "").trim();
        if (trimmed === "") {
            if (window.showInfoView)
                window.updateInfoNodes();
            return;
        }

        try {
            let data = JSON.parse(trimmed);
            window.trafficIface = data.iface || "";
            window.trafficDownRateText = window.formatBytesPerSecond(data.down_bps || 0);
            window.trafficUpRateText = window.formatBytesPerSecond(data.up_bps || 0);
        } catch (e) {
            return;
        }

        if (window.showInfoView)
            window.updateInfoNodes();
    }

    function resetSpeedtestState() {
        window.speedtestState = "idle";
        window.speedtestHeadline = "";
        window.speedtestSubline = "";
    }

    function deleteSpeedtestCache() {
        Quickshell.execDetached(["rm", "-f", window.speedtestCacheFile]);
    }

    function consumeSpeedtestStatus(textData) {
        let trimmed = (textData || "").trim();
        if (trimmed === "") {
            window.resetSpeedtestState();
            if (window.showInfoView)
                window.updateInfoNodes();
            return;
        }

        try {
            let data = JSON.parse(trimmed);
            if ((data.connection_id || "") !== window.currentNetworkId) {
                window.resetSpeedtestState();
                if (window.showInfoView)
                    window.updateInfoNodes();
                return;
            }
            if (data.state === window.speedtestState && data.state !== "running") return;

            window.speedtestState = data.state || "idle";
            window.speedtestHeadline = data.headline || "";
            window.speedtestSubline = data.subline || "";

            if (window.speedtestState === "done" || window.speedtestState === "error" || window.speedtestState === "idle") {
                speedtestPollerTimer.stop();
            } else if (window.speedtestState === "running") {
                if (!speedtestPollerTimer.running) speedtestPollerTimer.start();
            }
        } catch (e) {
            window.speedtestState = "error";
            window.speedtestHeadline = "Speedtest failed";
            window.speedtestSubline = trimmed;
            speedtestPollerTimer.stop();
        }

        if (window.showInfoView)
            window.updateInfoNodes();
    }

    function clearSpeedtestSession() {
        speedtestPollerTimer.stop();
        window.resetSpeedtestState();
    }

    function launchNetworkSpeedtest() {
        if (window.activeMode !== "wifi" || !window.currentConn || speedtestPollerTimer.running)
            return;

        window.speedtestState = "running";
        window.speedtestHeadline = "Speedtest running..."
        window.speedtestSubline = "Measuring download and upload";
        
        Quickshell.execDetached(["bash", window.speedtestScriptPath, "--run-detached", window.speedtestCacheFile, window.currentNetworkId]);
        speedtestPollerTimer.start();
        
        if (window.showInfoView)
            window.updateInfoNodes();
    }

    function tailscaleOrbitNode(parentIndex) {
        return {
            id: "tailscale_status",
            ssid: "",
            mac: "",
            name: window.tailscaleSummaryText,
            icon: "󰒍",
            security: "",
            action: window.tailscaleDetailText !== "" ? window.tailscaleDetailText + " | Hold" : "Hold for VPN panel",
            isInfoNode: true,
            isActionable: true,
            cmdStr: "OPEN_VPN",
            parentIndex: parentIndex
        };
    }

    function refreshTailscaleNodes() {
        if (window.activeMode !== "wifi")
            return;
        if (window.showInfoView && window.currentConn)
            window.updateInfoNodes();
        else if (cache.lastWifiJson !== "")
            window.processWifiJson(cache.lastWifiJson);
    }

    function consumeTailscaleStatus(textData) {
        let trimmed = (textData || "").trim();
        let active = false;
        let summary = "Tailscale";
        let detail = "";

        if (trimmed !== "") {
            try {
                let data = JSON.parse(trimmed);
                active = !!data.active;
                summary = data.summary || "Tailscale";
                detail = data.detail || data.ip || "";
            } catch (e) {
                active = false;
            }
        }

        let changed = active !== window.tailscaleActive || summary !== window.tailscaleSummaryText || detail !== window.tailscaleDetailText;
        window.tailscaleActive = active;
        window.tailscaleSummaryText = summary;
        window.tailscaleDetailText = detail;
        if (changed)
            window.refreshTailscaleNodes();
    }

    onCurrentConnChanged: {
        showInfoView = currentConn;
        if (!currentConn) {
            resetTrafficStats();
            clearSpeedtestSession();
        }
        if (currentConn) {
            if (window.activeMode === "wifi" && !speedtestPollerProc.running)
                speedtestPollerProc.running = true;
            updateInfoNodes();
        }
    }

    onActiveModeChanged: {
        if (!window.ignoreNextModeFileUpdate) {
            Quickshell.execDetached(["bash", "-c", "echo '" + window.activeMode + "' > /tmp/qs_network_mode"]);
        }
        window.ignoreNextModeFileUpdate = false;
        infoListModel.clear();
        window.busyTasks = ({});
        window.disconnectingDevices = ({});
        window.currentCores = [null, null, null, null, null];
        window.coreVisualIndices = [0, 0, 0, 0, 0];
        window.activeCoreCount = 0;
        window.resetTrafficStats();
        window.clearSpeedtestSession();
        syncCores();
        window.showInfoView = window.currentConn;
        if (window.showInfoView) {
            if (window.activeMode === "wifi" && !speedtestPollerProc.running)
                speedtestPollerProc.running = true;
            window.updateInfoNodes();
        }
    }

    ListModel {
        id: wifiListModel
    }
    ListModel {
        id: btListModel
    }
    ListModel {
        id: infoListModel
    }

    function syncModel(listModel, dataArray) {
        for (let i = listModel.count - 1; i >= 0; i--) {
            let id = listModel.get(i).id;
            let found = false;
            for (let j = 0; j < dataArray.length; j++) {
                if (id === dataArray[j].id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                listModel.remove(i);
            }
        }
        for (let i = 0; i < dataArray.length && i < 30; i++) {
            let d = dataArray[i];
            let foundIdx = -1;
            for (let j = i; j < listModel.count; j++) {
                if (listModel.get(j).id === d.id) {
                    foundIdx = j;
                    break;
                }
            }
            let obj = {
                id: d.id || "",
                ssid: d.ssid || "",
                mac: d.mac || "",
                name: d.name || d.ssid || "",
                icon: d.icon || "",
                security: d.security || "",
                action: d.action || "",
                isInfoNode: d.isInfoNode || false,
                isActionable: d.isActionable !== undefined ? d.isActionable : false,
                cmdStr: d.cmdStr || "",
                parentIndex: d.parentIndex !== undefined ? d.parentIndex : -1,
                known: d.known !== undefined ? d.known : false
            };
            if (foundIdx === -1) {
                listModel.insert(i, obj);
            } else {
                if (foundIdx !== i) {
                    listModel.move(foundIdx, i, 1);
                }
                for (let key in obj) {
                    if (listModel.get(i)[key] !== obj[key]) {
                        listModel.setProperty(i, key, obj[key]);
                    }
                }
            }
        }
    }

    property int hoveredCardCount: 0
    readonly property bool isListLocked: hoveredCardCount > 0
    property var nextWifiList: null
    property var nextBtList: null
    property var nextInfoList: null

    onIsListLockedChanged: {
        if (!isListLocked) {
            if (nextWifiList !== null) {
                window.syncModel(wifiListModel, nextWifiList);
                window.wifiList = nextWifiList;
                nextWifiList = null;
            }
            if (nextBtList !== null) {
                window.syncModel(btListModel, nextBtList);
                window.btList = nextBtList;
                nextBtList = null;
            }
            if (nextInfoList !== null) {
                window.syncModel(infoListModel, nextInfoList);
                nextInfoList = null;
            }
        }
    }

    property bool wifiPowerPending: false
    property var expectedWifiPower: ""
    property string wifiPower: "off"
    property var wifiConnected: null
    property var ethernetData: null
    readonly property bool isEthConn: !!window.ethernetData

    onEthernetDataChanged: {
        syncCores();
    }

    readonly property bool isWifiConn: !!window.wifiConnected && window.wifiConnected.ssid !== undefined

    readonly property string targetWifiSsid: {
        let found = false;
        if (cache.lastWifiSsid !== "") {
            for (let i = 0; i < wifiList.length; i++) {
                if (wifiList[i].id === cache.lastWifiSsid) {
                    found = true;
                    break;
                }
            }
        }
        return found ? cache.lastWifiSsid : strongestWifiSsid;
    }

    onWifiConnectedChanged: {
        if (window.wifiConnected && window.wifiConnected.ssid) {
            if (cache.lastWifiSsid !== "" && cache.lastWifiSsid !== window.wifiConnected.ssid) {
                window.deleteSpeedtestCache();
                window.clearSpeedtestSession();
            }
            cache.lastWifiSsid = window.wifiConnected.ssid;
        } else {
            if (!window.isEthConn) {
                window.deleteSpeedtestCache();
                window.clearSpeedtestSession();
            }
        }
        syncCores();
        if (window.currentConn && window.activeMode === "wifi")
            updateInfoNodes();
    }

    property bool btPowerPending: false
    property string expectedBtPower: ""
    property string btPower: "off"
    property var btConnected: []
    property var btList: []
    readonly property bool isBtConn: window.btConnected.length > 0

    onBtConnectedChanged: {
        syncCores();
        if (window.currentConn && window.activeMode === "bt")
            updateInfoNodes();
    }

    readonly property bool currentPower: {
        if (activeMode === "wifi")
            return window.wifiPower === "on" || window.isEthConn;
        return window.btPower === "on";
    }
    onCurrentPowerChanged: {
        syncCores();
    }
    readonly property bool currentPowerPending: activeMode === "wifi" ? window.wifiPowerPending : window.btPowerPending
    readonly property bool currentConn: {
        if (activeMode === "wifi")
            return window.isWifiConn || window.isEthConn;
        return window.isBtConn;
    }
    readonly property string currentNetworkId: {
        if (window.isEthConn && window.ethernetData)
            return "ethernet:" + (window.ethernetData.iface || window.ethernetData.ssid || "wired");
        if (window.isWifiConn && window.wifiConnected)
            return "wifi:" + (window.wifiConnected.ssid || "");
        return "";
    }
    property string lastSpeedtestNetworkId: ""
    onCurrentNetworkIdChanged: {
        if (window.lastSpeedtestNetworkId !== "" && window.currentNetworkId !== "" && window.currentNetworkId !== window.lastSpeedtestNetworkId) {
            window.deleteSpeedtestCache();
            window.clearSpeedtestSession();
        }
        if (window.currentNetworkId !== "")
            window.lastSpeedtestNetworkId = window.currentNetworkId;
    }
    readonly property var currentObjList: {
        if (activeMode === "wifi") {
            if (window.isWifiConn)
                return [window.wifiConnected];
            if (window.isEthConn)
                return [window.ethernetData];
            return [];
        }
        return window.btConnected;
    }
    readonly property bool isLogicMultiState: window.activeMode === "bt" && window.activeCoreCount > 1

    property real multiTransitionState: (isLogicMultiState && window.currentPower) ? 1.0 : 0.0
    Behavior on multiTransitionState {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.InOutExpo
        }
    }

    function updateInfoNodes() {
        let nodes = [];
        let wConn = window.wifiConnected;
        if (Array.isArray(wConn))
            wConn = wConn[0];
        let cList;
        if (window.activeMode === "wifi") {
            if (window.isEthConn && window.ethernetData)
                cList = [window.ethernetData];
            else if (window.isWifiConn && wConn)
                cList = [wConn];
            else
                cList = [];
        } else {
            cList = window.btConnected;
        }

        if (window.currentConn && cList.length > 0) {
            for (let i = 0; i < cList.length; i++) {
                let obj = cList[i];
                let cIndex = 0;
                if (window.activeMode === "bt") {
                    for (let c = 0; c < 5; c++) {
                        if (window.currentCores[c] && window.currentCores[c].mac === obj.mac) {
                            cIndex = c;
                            break;
                        }
                    }
                }
                if (window.activeMode === "wifi") {
                    if (obj === window.ethernetData) {
                        nodes.push({
                            id: "eth_iface_" + i,
                            name: obj.iface || "eth0",
                            icon: "󰈀",
                            action: "Interface",
                            isInfoNode: true,
                            isActionable: false,
                            parentIndex: cIndex
                        });
                        if (obj.ip)
                            nodes.push({
                                id: "eth_ip_" + i,
                                name: obj.ip,
                                icon: "󰩟",
                                action: "IP Address",
                                isInfoNode: true,
                                isActionable: false,
                                parentIndex: cIndex
                            });
                        nodes.push({
                            id: "eth_type_" + i,
                            name: "Wired",
                            icon: "󱘖",
                            action: "Connection Type",
                            isInfoNode: true,
                            isActionable: false,
                            parentIndex: cIndex
                        });
                    } else {
                        let sigValue = obj.signal !== undefined ? obj.signal + "%" : "Calculating...";
                        nodes.push({
                            id: "sig_" + i,
                            name: sigValue,
                            icon: obj.icon || "󰤨",
                            action: "Signal Strength",
                            isInfoNode: true,
                            isActionable: false,
                            parentIndex: cIndex
                        });
                        nodes.push({
                            id: "sec_" + i,
                            name: obj.security || "Open",
                            icon: "󰦝",
                            action: "Security",
                            isInfoNode: true,
                            isActionable: false,
                            parentIndex: cIndex
                        });
                        if (obj.ip)
                            nodes.push({
                                id: "ip_" + i,
                                name: obj.ip,
                                icon: "󰩟",
                                action: "IP Address",
                                isInfoNode: true,
                                isActionable: false,
                                parentIndex: cIndex
                            });
                        if (obj.freq)
                            nodes.push({
                                id: "freq_" + i,
                                name: obj.freq,
                                icon: "󰖧",
                                action: "Band",
                                isInfoNode: true,
                                isActionable: false,
                                parentIndex: cIndex
                            });
                    }
                    nodes.push({
                        id: "traffic_" + (obj.id || i),
                        name: window.trafficSummaryText,
                        icon: "󰈀",
                        action: "Live Traffic",
                        isInfoNode: true,
                        isActionable: false,
                        parentIndex: cIndex
                    });
                    nodes.push({
                        id: "speedtest_" + (obj.id || i),
                        name: window.speedtestState === "done" ? window.speedtestSubline : (window.speedtestState === "error" ? window.speedtestHeadline : "Run Speedtest"),
                        icon: "󰓅",
                        action: window.speedtestState === "done" ? window.speedtestHeadline : (window.speedtestState === "running" ? "Running..." : (window.speedtestState === "error" ? "Hold to retry" : "Hold to benchmark")),
                        isInfoNode: true,
                        isActionable: true,
                        cmdStr: "RUN_SPEEDTEST",
                        parentIndex: cIndex
                    });
                    if (window.tailscaleActive)
                        nodes.push(window.tailscaleOrbitNode(cIndex));
                } else {
                    nodes.push({
                        id: "bat_" + obj.mac,
                        name: (obj.battery || "0") + "%",
                        icon: window.batteryGlyphFor(parseInt(obj.battery || 0), false),
                        action: "Battery",
                        isInfoNode: true,
                        isActionable: false,
                        parentIndex: cIndex
                    });
                    if (obj.profile) {
                        nodes.push({
                            id: "prof_" + obj.mac,
                            name: obj.profile,
                            icon: (obj.profile === "Hi-Fi (A2DP)" ? "󰓃" : "󰋎"),
                            action: "Audio Profile",
                            isInfoNode: true,
                            isActionable: false,
                            parentIndex: cIndex
                        });
                    }
                    nodes.push({
                        id: "mac_" + obj.mac,
                        name: obj.mac || "Unknown",
                        icon: "󰒋",
                        action: "MAC Address",
                        isInfoNode: true,
                        isActionable: false,
                        parentIndex: cIndex
                    });
                }
            }
            nodes.push({
                id: "action_scan",
                name: "Scan Devices",
                icon: "󰍉",
                action: "Switch View",
                isInfoNode: true,
                isActionable: true,
                cmdStr: "TOGGLE_VIEW",
                parentIndex: -1
            });
        }
        if (window.isListLocked)
            window.nextInfoList = nodes;
        else {
            window.syncModel(infoListModel, nodes);
            window.nextInfoList = null;
        }
    }

    function processWifiJson(textData) {
        if (textData === "")
            return;
        try {
            let data = JSON.parse(textData);
            let fetchedPower = data.power || "off";
            if (window.wifiPowerPending) {
                window.wifiPower = window.expectedWifiPower;
                if (fetchedPower === window.expectedWifiPower) {
                    window.wifiPowerPending = false;
                    wifiPendingReset.stop();
                }
            } else {
                window.wifiPower = fetchedPower;
                window.expectedWifiPower = "";
            }

            let newConnected = data.connected;
            if (JSON.stringify(window.wifiConnected) !== JSON.stringify(newConnected)) {
                window.wifiConnected = newConnected;
                syncCores();
            }

            let ethData = data.ethernet || null;
            if (ethData) {
                ethData.id = "ethernet_" + (ethData.iface || "eno1");
                ethData.ssid = ethData.name || "Ethernet";
                ethData.icon = "󰈀";
                ethData.signal = "100";
                ethData.security = "Wired";
                ethData.ip = ethData.ip || "No IP";
                ethData.freq = "N/A";
            }
            if (JSON.stringify(window.ethernetData) !== JSON.stringify(ethData)) {
                window.ethernetData = ethData;
                syncCores();
            }

            let newNetworks = data.networks ? data.networks : [];
            if (newNetworks.length > 0) {
                let maxSig = -1;
                let bestSsid = newNetworks[0].id;
                for (let i = 0; i < newNetworks.length; i++) {
                    let sig = parseInt(newNetworks[i].signal || 0);
                    if (sig > maxSig) {
                        maxSig = sig;
                        bestSsid = newNetworks[i].id;
                    }
                }
                window.strongestWifiSsid = bestSsid;
            } else {
                window.strongestWifiSsid = "";
            }
            newNetworks.sort((a, b) => a.id.localeCompare(b.id));

            if (window.tailscaleActive && window.activeMode === "wifi")
                newNetworks.push(window.tailscaleOrbitNode(-1));

            if (window.activeMode === "wifi") {
                newNetworks.push({
                    id: "action_refresh",
                    ssid: "Refresh Scan",
                    mac: "",
                    name: "Refresh Scan",
                    icon: "󰑐",
                    security: "",
                    action: "Rescan",
                    isInfoNode: false,
                    isActionable: true,
                    cmdStr: "RESCAN",
                    parentIndex: -1
                });
            }
            if (window.isWifiConn && window.activeMode === "wifi") {
                newNetworks.push({
                    id: "action_settings",
                    ssid: "Current Device",
                    mac: "",
                    name: "Current Device",
                    icon: "󰒓",
                    security: "",
                    action: "View Info",
                    isInfoNode: false,
                    isActionable: true,
                    cmdStr: "TOGGLE_VIEW",
                    parentIndex: -1
                });
            }
            if (JSON.stringify(window.wifiList) !== JSON.stringify(newNetworks)) {
                if (window.isListLocked)
                    window.nextWifiList = newNetworks;
                else {
                    window.syncModel(wifiListModel, newNetworks);
                    window.wifiList = newNetworks;
                    window.nextWifiList = null;
                }
            }
            if (window.activeMode === "wifi") {
                let dd = window.disconnectingDevices;
                let ddChanged = false;
                for (let ssid in dd) {
                    if (!window.isWifiConn || (window.wifiConnected && window.wifiConnected.ssid !== ssid)) {
                        delete dd[ssid];
                        ddChanged = true;
                    }
                }
                if (ddChanged) {
                    window.disconnectingDevices = Object.assign({}, dd);
                    if (Object.keys(window.disconnectingDevices).length === 0 && Object.keys(window.busyTasks).length === 0)
                        busyTimeout.stop();
                    if (!window.isWifiConn && window.showInfoView) {
                        window.showInfoView = false;
                    }
                }
                let bt = window.busyTasks;
                if (window.isWifiConn && window.wifiConnected && bt[window.wifiConnected.ssid]) {
                    delete bt[window.wifiConnected.ssid];
                    window.busyTasks = Object.assign({}, bt);
                    if (Object.keys(window.busyTasks).length === 0 && Object.keys(window.disconnectingDevices).length === 0)
                        busyTimeout.stop();
                }
                if (window.currentConn)
                    window.updateInfoNodes();
            }
        } catch (e) {}
    }

    function processBtJson(textData) {
        if (textData === "")
            return;
        try {
            let data = JSON.parse(textData);
            let fetchedPower = data.power || "off";
            if (window.btPowerPending) {
                window.btPower = window.expectedBtPower;
                if (fetchedPower === window.expectedBtPower) {
                    window.btPowerPending = false;
                    btPendingReset.stop();
                }
            } else {
                window.btPower = fetchedPower;
                window.expectedBtPower = "";
            }

            let newBtConnected = data.connected || [];
            if (!Array.isArray(newBtConnected))
                newBtConnected = [newBtConnected];
            if (JSON.stringify(window.btConnected) !== JSON.stringify(newBtConnected)) {
                window.btConnected = newBtConnected;
            }

            let newDevices = data.devices ? data.devices : [];
            newDevices.sort((a, b) => a.id.localeCompare(b.id));
            if (window.isBtConn && window.activeMode === "bt") {
                newDevices.push({
                    id: "action_settings",
                    ssid: "",
                    mac: "action_settings",
                    name: "Current Device",
                    icon: "󰒓",
                    action: "View Info",
                    isInfoNode: false,
                    isActionable: true,
                    cmdStr: "TOGGLE_VIEW",
                    parentIndex: -1
                });
            }
            if (JSON.stringify(window.btList) !== JSON.stringify(newDevices)) {
                if (window.isListLocked)
                    window.nextBtList = newDevices;
                else {
                    window.syncModel(btListModel, newDevices);
                    window.btList = newDevices;
                    window.nextBtList = null;
                }
            }
            if (window.activeMode === "bt") {
                if (window.btConnected.length === 0 && window.showInfoView) {
                    window.showInfoView = false;
                }
                let dd = window.disconnectingDevices;
                let ddChanged = false;
                for (let mac in dd) {
                    let stillConnected = false;
                    for (let i = 0; i < window.btConnected.length; i++) {
                        if (window.btConnected[i].mac === mac) {
                            stillConnected = true;
                            break;
                        }
                    }
                    if (!stillConnected) {
                        delete dd[mac];
                        ddChanged = true;
                    }
                }
                if (ddChanged) {
                    window.disconnectingDevices = Object.assign({}, dd);
                    if (Object.keys(window.disconnectingDevices).length === 0 && Object.keys(window.busyTasks).length === 0)
                        busyTimeout.stop();
                }
                let bt = window.busyTasks;
                let newlyConnected = false;
                for (let i = 0; i < window.btConnected.length; i++) {
                    let mac = window.btConnected[i].mac;
                    if (bt[mac]) {
                        newlyConnected = true;
                        delete bt[mac];
                    }
                }
                if (newlyConnected) {
                    window.busyTasks = Object.assign({}, bt);
                    if (Object.keys(window.busyTasks).length === 0 && Object.keys(window.disconnectingDevices).length === 0)
                        busyTimeout.stop();
                }
                if (window.currentConn)
                    window.updateInfoNodes();
            }
        } catch (e) {}
    }

    Process {
        id: wifiPoller
        command: ["bash", window.scriptsDir + "/wifi_panel_logic.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                cache.lastWifiJson = this.text.trim();
                processWifiJson(cache.lastWifiJson);
            }
        }
    }
    Process {
        id: btPoller
        command: ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                cache.lastBtJson = this.text.trim();
                processBtJson(cache.lastBtJson);
            }
        }
    }
    Process {
        id: trafficPoller
        command: ["bash", window.trafficScriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                window.consumeTrafficStatsSample(this.text);
            }
        }
    }
    Process {
        id: tailscalePoller
        command: ["bash", window.tailscaleScriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                window.consumeTailscaleStatus(this.text);
            }
        }
    }
    Process {
        id: speedtestPollerProc
        command: ["bash", "-c", "cat " + window.speedtestCacheFile + " 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.consumeSpeedtestStatus(this.text);
            }
        }
    }
    Timer {
        id: speedtestPollerTimer
        interval: 1500
        repeat: true
        running: false
        onTriggered: {
            if (!speedtestPollerProc.running)
                speedtestPollerProc.running = true;
        }
    }
    property bool recentAction: false
    Timer {
        id: recentActionTimer
        interval: 5000
        onTriggered: window.recentAction = false
    }
    function markRecentAction() {
        recentAction = true;
        recentActionTimer.restart();
    }
    Timer {
        interval: window.recentAction ? 500 : ((Object.keys(window.busyTasks).length > 0 || Object.keys(window.disconnectingDevices).length > 0) ? 1000 : 3000)
        running: true
        repeat: true
        onTriggered: {
            if (!wifiPoller.running)
                wifiPoller.running = true;
            if (!btPoller.running)
                btPoller.running = true;
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (window.activeMode === "wifi" && window.currentConn) {
                if (!trafficPoller.running)
                    trafficPoller.running = true;
            } else if (window.trafficDownRateText !== "0 B/s" || window.trafficUpRateText !== "0 B/s" || window.trafficIface !== "") {
                window.resetTrafficStats();
                if (window.showInfoView)
                    window.updateInfoNodes();
            }
        }
    }
    Timer {
        interval: 7000
        running: true
        repeat: true
        onTriggered: {
            if (!tailscalePoller.running)
                tailscalePoller.running = true;
        }
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 200000
        loops: Animation.Infinite
        running: ThemePkg.Theme.edgeAnimationsEnabled
    }
    property real introState: 0.0
    Behavior on introState {
        NumberAnimation {
            duration: 1500
            easing.type: Easing.OutCubic
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

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth - 18; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight - 18; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: window.popupOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth + 14; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight - 16; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: window.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }

    component LoadingDots: Row {
        spacing: dotSize - 1
        property color dotCol: window.text
        property real dotSize: 6
        Repeater {
            model: 3
            Rectangle {
                width: dotSize
                height: dotSize
                radius: dotSize / 2
                color: dotCol
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: ThemePkg.Theme.edgeAnimationsEnabled
                    PauseAnimation {
                        duration: index * 100
                    }
                    NumberAnimation {
                        from: 0
                        to: -dotSize
                        duration: 250
                        easing.type: Easing.OutSine
                    }
                    NumberAnimation {
                        from: -dotSize
                        to: 0
                        duration: 250
                        easing.type: Easing.InSine
                    }
                    PauseAnimation {
                        duration: (2 - index) * 100
                    }
                }
            }
        }
    }

    Item {
        id: popupShell
        width: window.popupCardWidth
        height: window.popupCardHeight
        opacity: window.popupCardOpacity
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: window.popupCardLift
        anchors.rightMargin: window.panelMargin

        transform: Scale {
            origin.x: popupShell.width / 2
            origin.y: popupShell.height / 2
            xScale: window.popupCardScaleX
            yScale: window.popupCardScaleY
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        Rectangle {
            anchors.fill: parent
            radius: window.popupCardRadius
            color: window.base
            border.color: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
            border.width: 1
            clip: true

            ElectricBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: window.activeColor
            }

            Rectangle {
                width: parent.width * 0.8
                height: width
                radius: width / 2
                x: Math.round((parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * 100)
                y: Math.round((parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * 70)
                opacity: window.currentPower ? 0.08 : 0.02
                color: window.currentConn ? window.activeColor : window.surface2
                Behavior on color {
                    ColorAnimation {
                        duration: 1000
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                    }
                }
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: Math.round((parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -100)
                y: Math.round((parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -70)
                opacity: window.currentPower ? 0.06 : 0.01
                color: window.currentConn ? window.activeGradientSecondary : window.surface1
                Behavior on color {
                    ColorAnimation {
                        duration: 1000
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                    }
                }
            }

            Item {
                id: radarItem
                anchors.fill: parent
                anchors.bottomMargin: 80
                opacity: window.currentPower ? 1.0 : 0.0
                scale: window.currentPower ? 1.0 : 1.05
                Behavior on opacity {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                layer.enabled: opacity > 0 && opacity < 1
                layer.smooth: true

                Repeater {
                    model: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: 280 + (index * 170)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: Object.keys(window.disconnectingDevices).length > 0 ? window.red : window.activeColor
                        border.width: Object.keys(window.disconnectingDevices).length > 0 ? 2 : 1
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                        Behavior on border.width {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                        opacity: Object.keys(window.disconnectingDevices).length > 0 ? 0.2 : (window.currentConn ? 0.08 - (index * 0.02) : 0.03)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                }
            }

            Canvas {
                id: nodeLinesCanvas
                anchors.fill: parent
                anchors.bottomMargin: 80
                z: 0
                opacity: (window.currentConn && window.showInfoView && window.currentPower) ? 1.0 : 0.0
                Behavior on opacity {
                    enabled: ThemePkg.Theme.edgeAnimationsEnabled
                    NumberAnimation {
                        duration: 500
                    }
                }
                onOpacityChanged: {
                    if (opacity > 0.0)
                        requestPaint();
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: ThemePkg.Theme
                    function onEdgeAnimationsEnabledChanged() {
                        nodeLinesCanvas.requestPaint();
                    }
                }
                Connections {
                    target: window
                    function onShowInfoViewChanged() {
                        nodeLinesCanvas.requestPaint();
                    }
                    function onCurrentConnChanged() {
                        nodeLinesCanvas.requestPaint();
                    }
                    function onCurrentPowerChanged() {
                        nodeLinesCanvas.requestPaint();
                    }
                }
                Timer {
                    id: lightningTimer
                    interval: ThemePkg.Theme.edgeAnimationsEnabled ? 60 : 500
                    running: true
                    repeat: true
                    onTriggered: nodeLinesCanvas.requestPaint()
                }
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!window.currentConn || !window.showInfoView || !window.currentPower)
                        return;
                    var time = ThemePkg.Theme.edgeAnimationsEnabled ? (Date.now() / 1000) : 0;
                    var randAmp = ThemePkg.Theme.edgeAnimationsEnabled ? 1 : 0;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    var tWave1 = time * 2.5;
                    var tWave2 = time * -1.5;
                    for (var i = 0; i < orbitRepeater.count; i++) {
                        var item = orbitRepeater.itemAt(i);
                        if (!item || !item.isLoaded)
                            continue;
                        var targetX = item.x + item.width / 2;
                        var targetY = item.y + item.height / 2;
                        function drawStrands(startX, startY, parentFade, parentWidth) {
                            var dx = targetX - startX;
                            var dy = targetY - startY;
                            var fullDist = Math.sqrt(dx * dx + dy * dy);
                            if (fullDist < 10)
                                return;
                            var alpha = Math.atan2(dy, dx);
                            var cosA = Math.cos(alpha);
                            var sinA = Math.sin(alpha);
                            var coreVisualRadius = parentWidth / 2;
                            var startOffset = coreVisualRadius + 5;
                            var endOffset = 35;
                            var drawDist = fullDist - startOffset - endOffset;
                            if (drawDist <= 0)
                                return;
                            var steps = 8;
                            var perpX = -sinA;
                            var perpY = cosA;
                            var sX = startX + cosA * startOffset;
                            var sY = startY + sinA * startOffset;
                            var distanceFactor = Math.max(0, 1.0 - (fullDist / 400.0));
                            var dynamicLineWidthCore = 1.0 + (distanceFactor * 2.0);
                            var dynamicLineWidthGlow = 4.0 + (distanceFactor * 4.0);
                            var dynamicAlpha = (0.2 + (distanceFactor * 0.7)) * parentFade;
                            ctx.beginPath();
                            ctx.moveTo(sX, sY);
                            for (var j = 1; j <= steps; j++) {
                                var t = j / steps;
                                var currentDist = drawDist * t;
                                var envelope = Math.sin(t * Math.PI);
                                var offset = Math.sin(tWave1 + t * 6) * 6 * envelope + ((Math.random() - 0.5) * 5.0 * distanceFactor * randAmp);
                                ctx.lineTo(sX + cosA * currentDist + perpX * offset, sY + sinA * currentDist + perpY * offset);
                            }
                            ctx.lineWidth = dynamicLineWidthGlow;
                            ctx.strokeStyle = window.activeColor;
                            ctx.globalAlpha = dynamicAlpha * 0.15;
                            ctx.stroke();
                            ctx.lineWidth = dynamicLineWidthCore;
                            ctx.strokeStyle = "#ffffff";
                            ctx.globalAlpha = dynamicAlpha;
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(sX, sY);
                            for (var k = 1; k <= steps; k++) {
                                var tk = k / steps;
                                var currentDistK = drawDist * tk;
                                var envelopeK = Math.sin(tk * Math.PI);
                                var offsetK = Math.cos(tWave2 + tk * 8) * 12 * envelopeK + ((Math.random() - 0.5) * 3.0 * distanceFactor * randAmp);
                                ctx.lineTo(sX + cosA * currentDistK + perpX * offsetK, sY + sinA * currentDistK + perpY * offsetK);
                            }
                            ctx.lineWidth = dynamicLineWidthCore * 1.5;
                            ctx.strokeStyle = window.activeColor;
                            ctx.globalAlpha = dynamicAlpha * 0.3;
                            ctx.stroke();
                        }
                        if (item.myParentIdx === -1) {
                            for (var c = 0; c < coreRepeater.count; c++) {
                                var cItem = coreRepeater.itemAt(c);
                                if (cItem && cItem.activeTransition > 0.01) {
                                    drawStrands(cItem.x + cItem.width / 2, cItem.y + cItem.height / 2, cItem.activeTransition, cItem.width);
                                }
                            }
                        } else {
                            var pItem = coreRepeater.itemAt(item.myParentIdx);
                            if (pItem && pItem.activeTransition > 0.01) {
                                drawStrands(pItem.x + pItem.width / 2, pItem.y + pItem.height / 2, pItem.activeTransition, pItem.width);
                            }
                        }
                    }
                }
            }

            Item {
                id: orbitContainer
                anchors.fill: parent
                anchors.bottomMargin: 80
                z: 1

                Repeater {
                    id: coreRepeater
                    model: 5
                    delegate: Item {
                        id: coreContainer
                        property var myDevice: window.currentCores[index]
                        property bool isPrimary: index === 0
                        property bool hasDevice: myDevice !== null
                        property bool isReallyActive: hasDevice || (isPrimary && window.activeCoreCount === 0)
                        property real activeTransition: isReallyActive ? 1.0 : 0.0
                        Behavior on activeTransition {
                            enabled: window.introState >= 1.0
                            NumberAnimation {
                                duration: 1400
                                easing.type: Easing.OutExpo
                            }
                        }
                        property real multiShift: window.activeMode === "wifi" ? 0.0 : window.multiTransitionState
                        width: window.currentPower ? (200 - (30 * multiShift) - (15 * Math.max(0, window.smoothedActiveCoreCount - 2))) : 160
                        height: width
                        property real myBaseAngle: (window.coreVisualIndices[index] / Math.max(1, window.activeCoreCount)) * Math.PI * 2
                        property real animatedBaseAngle: myBaseAngle
                        Behavior on animatedBaseAngle {
                            NumberAnimation {
                                duration: 1000
                                easing.type: Easing.InOutExpo
                            }
                        }
                        property real coreOrbitAngle: window.globalOrbitAngle * 1.5 + animatedBaseAngle
                        property real myOrbitRadiusX: 155 + (window.activeCoreCount > 2 ? 18 : 0)
                        property real myOrbitRadiusY: 100 + (window.activeCoreCount > 2 ? 12 : 0)
                        x: Math.round((orbitContainer.width / 2 - width / 2) + (Math.cos(coreOrbitAngle) * myOrbitRadiusX * multiShift * activeTransition))
                        y: Math.round((orbitContainer.height / 2 - height / 2) + (Math.sin(coreOrbitAngle) * myOrbitRadiusY * multiShift * activeTransition))
                        opacity: activeTransition
                        scale: bumpScale * (0.8 + 0.2 * activeTransition)
                        visible: opacity > 0.01
                        property string myId: myDevice ? (window.activeMode === "wifi" ? myDevice.ssid : myDevice.mac) : "unknown"
                        property bool isMyDisconnecting: !!window.disconnectingDevices[myId]
                        property real bumpScale: 1.0

                        MultiEffect {
                            source: centralCore
                            anchors.fill: centralCore
                            shadowEnabled: true
                            shadowColor: "#000000"
                            shadowOpacity: window.currentPower ? 0.5 : 0.0
                            shadowBlur: 1.2
                            shadowVerticalOffset: 6
                            z: -1
                            Behavior on shadowOpacity {
                                NumberAnimation {
                                    duration: 600
                                }
                            }
                        }

                        Rectangle {
                            id: centralCore
                            anchors.fill: parent
                            radius: width / 2
                            property real disconnectFill: 0.0
                            property bool disconnectTriggered: false
                            property real flashOpacity: 0.0
                            property real bumpScale: 1.0
                            property bool isEthOnly: window.activeMode === "wifi" && coreContainer.myDevice && coreContainer.myDevice.id && coreContainer.myDevice.id.startsWith("ethernet_")
                            property bool isDangerState: !isEthOnly && (coreMa.containsMouse || disconnectFill > 0 || isMyDisconnecting)
                            scale: bumpScale

                            SequentialAnimation on bumpScale {
                                id: coreBumpAnim
                                running: false
                                NumberAnimation {
                                    to: 1.15
                                    duration: 200
                                    easing.type: Easing.OutBack
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: 600
                                    easing.type: Easing.OutQuint
                                }
                            }

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0.0
                                    color: {
                                        if (!window.currentPower)
                                            return window.mantle;
                                        if (isMyDisconnecting)
                                            return window.surface0;
                                        if (centralCore.isDangerState && window.currentConn)
                                            return Qt.lighter(window.red, 1.15);
                                        return window.currentConn ? Qt.lighter(window.activeColor, 1.15) : window.surface0;
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 300
                                        }
                                    }
                                }
                                GradientStop {
                                    position: 1.0
                                    color: {
                                        if (!window.currentPower)
                                            return window.crust;
                                        if (isMyDisconnecting)
                                            return window.base;
                                        if (centralCore.isDangerState && window.currentConn)
                                            return window.red;
                                        return window.currentConn ? window.activeColor : window.base;
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 300
                                        }
                                    }
                                }
                            }
                            border.color: {
                                if (!window.currentPower)
                                    return window.crust;
                                if (isMyDisconnecting)
                                    return window.surface0;
                                if (centralCore.isDangerState && window.currentConn)
                                    return window.maroon;
                                return window.currentConn ? Qt.lighter(window.activeColor, 1.1) : window.surface1;
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "#ffffff"
                                opacity: centralCore.flashOpacity
                                PropertyAnimation on opacity {
                                    id: coreFlashAnim
                                    to: 0
                                    duration: 500
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Canvas {
                                id: coreWave
                                anchors.fill: parent
                                visible: centralCore.disconnectFill > 0
                                opacity: 0.95
                                property real wavePhase: 0.0
                                NumberAnimation on wavePhase {
                                    running: centralCore.disconnectFill > 0.0 && centralCore.disconnectFill < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                                    loops: Animation.Infinite
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 800
                                }
                                onWavePhaseChanged: requestPaint()
                                Connections {
                                    target: centralCore
                                    function onDisconnectFillChanged() {
                                        coreWave.requestPaint();
                                    }
                                }
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (centralCore.disconnectFill <= 0.001)
                                        return;
                                    var r = width / 2;
                                    var fillY = height * (1.0 - centralCore.disconnectFill);
                                    ctx.save();
                                    ctx.beginPath();
                                    ctx.arc(r, r, r, 0, 2 * Math.PI);
                                    ctx.clip();
                                    ctx.beginPath();
                                    ctx.moveTo(0, fillY);
                                    if (centralCore.disconnectFill < 0.99) {
                                        var waveAmp = 10 * Math.sin(centralCore.disconnectFill * Math.PI);
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
                                    grad.addColorStop(0, window.surface1.toString());
                                    grad.addColorStop(1, window.crust.toString());
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    ctx.restore();
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 40
                                height: width
                                radius: width / 2
                                color: centralCore.isDangerState && window.currentConn ? window.red : window.activeColor
                                opacity: window.currentConn && !isMyDisconnecting ? (centralCore.isDangerState ? 0.3 : 0.15) : 0.0
                                z: -1
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
                                    running: window.currentConn && ThemePkg.Theme.edgeAnimationsEnabled
                                    NumberAnimation {
                                        to: coreMa.containsMouse ? 1.15 : 1.1
                                        duration: coreMa.containsMouse ? 800 : 2000
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        to: 1.0
                                        duration: coreMa.containsMouse ? 800 : 2000
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 15
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: centralCore.isDangerState ? window.red : window.activeColor
                                border.width: 3
                                z: -2
                                property real pulseOp: 0.0
                                property real pulseSc: 1.0
                                opacity: (window.currentConn && window.showInfoView && window.currentPower && !isMyDisconnecting) ? pulseOp : 0.0
                                scale: pulseSc
                                Timer {
                                    interval: 45
                                    running: parent.opacity > 0.01 && ThemePkg.Theme.edgeAnimationsEnabled
                                    repeat: true
                                    onTriggered: {
                                        var time = Date.now() / 1000;
                                        parent.pulseOp = 0.3 + Math.sin(time * 2.5) * 0.15;
                                        parent.pulseSc = 1.02 + Math.cos(time * 3.0) * 0.02;
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: !window.currentConn || !window.currentPower
                                opacity: visible ? 1.0 : 0.0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 300
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 48 - (16 * coreContainer.multiShift)
                                    color: window.currentPower ? window.overlay0 : window.surface2
                                    text: window.activeMode === "wifi" ? (window.isEthConn && !window.isWifiConn ? "󰈀" : "󰤮") : "󰂲"
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: window.textFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 14 - (3 * coreContainer.multiShift)
                                    color: window.overlay0
                                    text: window.currentPowerPending ? ((window.activeMode === "wifi" ? window.expectedWifiPower : window.expectedBtPower) === "on" ? "Powering On..." : "Powering Off...") : (!window.currentPower ? "Radio Offline" : "Scanning...")
                                }
                            }

                            Item {
                                anchors.fill: parent
                                visible: window.currentConn && window.currentPower
                                opacity: visible ? 1.0 : 0.0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 300
                                    }
                                }
                                ColumnLayout {
                                    id: baseCoreText
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 48 - (16 * coreContainer.multiShift)
                                        color: isMyDisconnecting ? window.overlay1 : window.crust
                                        text: isMyDisconnecting ? "" : (coreMa.containsMouse && !centralCore.isEthOnly ? (window.activeMode === "wifi" ? "󰖪" : "󰂲") : (coreContainer.myDevice ? coreContainer.myDevice.icon : ""))
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                    LoadingDots {
                                        Layout.alignment: Qt.AlignHCenter
                                        visible: isMyDisconnecting
                                        dotCol: window.overlay1
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: 150 - (50 * coreContainer.multiShift)
                                        horizontalAlignment: Text.AlignHCenter
                                        font.family: window.textFont
                                        font.weight: Font.Black
                                        font.pixelSize: 16 - (4 * coreContainer.multiShift)
                                        color: isMyDisconnecting ? window.overlay1 : window.crust
                                        text: coreContainer.myDevice ? (window.activeMode === "wifi" ? (coreContainer.myDevice.ssid || "Connecting...") : (coreContainer.myDevice.name || "Unknown Device")) : ""
                                        elide: Text.ElideRight
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: window.textFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 11
                                        color: isMyDisconnecting ? window.overlay1 : (coreMa.containsMouse ? window.crust : "#99000000")
                                        text: isMyDisconnecting ? "Disconnecting..." : (centralCore.disconnectFill > 0.01 ? "Hold..." : "Connected")
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }

                                }
                                Item {
                                    id: waveClipItem
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: Math.min(parent.height, Math.max(0, parent.height * centralCore.disconnectFill + 8))
                                    clip: true
                                    visible: centralCore.disconnectFill > 0
                                    ColumnLayout {
                                        spacing: 4
                                        x: waveClipItem.width / 2 - width / 2
                                        y: (centralCore.height / 2) - (height / 2) - (centralCore.height - waveClipItem.height)
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: 48 - (16 * coreContainer.multiShift)
                                            color: window.text
                                            text: isMyDisconnecting ? "" : (coreMa.containsMouse ? (window.activeMode === "wifi" ? "󰖪" : "󰂲") : (coreContainer.myDevice ? coreContainer.myDevice.icon : ""))
                                        }
                                        LoadingDots {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: isMyDisconnecting
                                            dotCol: window.text
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.maximumWidth: 150 - (50 * coreContainer.multiShift)
                                            horizontalAlignment: Text.AlignHCenter
                                            font.family: window.textFont
                                            font.weight: Font.Black
                                            font.pixelSize: 16 - (4 * coreContainer.multiShift)
                                            color: window.text
                                            text: coreContainer.myDevice ? (window.activeMode === "wifi" ? (coreContainer.myDevice.ssid || "Connecting...") : (coreContainer.myDevice.name || "Unknown Device")) : ""
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: window.textFont
                                            font.weight: Font.Bold
                                            font.pixelSize: 11
                                            color: window.text
                                            text: isMyDisconnecting ? "Disconnecting..." : (centralCore.disconnectFill > 0.01 ? "Hold..." : "Connected")
                                        }

                                    }
                                }
                            }

                            MouseArea {
                                id: coreMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: window.currentConn && !isMyDisconnecting && !centralCore.isEthOnly ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: {
                                    if (window.currentConn && !isMyDisconnecting && !centralCore.disconnectTriggered && !centralCore.isEthOnly) {
                                        coreDrainAnim.stop();
                                        coreFillAnim.start();
                                    }
                                }
                                onReleased: {
                                    if (!centralCore.disconnectTriggered && !isMyDisconnecting) {
                                        coreFillAnim.stop();
                                        coreDrainAnim.start();
                                    }
                                }
                            }
                            NumberAnimation {
                                id: coreFillAnim
                                target: centralCore
                                property: "disconnectFill"
                                to: 1.0
                                duration: 700 * (1.0 - centralCore.disconnectFill)
                                easing.type: Easing.InSine
                                onFinished: {
                                    centralCore.disconnectTriggered = true;
                                    centralCore.flashOpacity = 0.6;
                                    coreFlashAnim.start();
                                    coreBumpAnim.start();
                                    let dd = window.disconnectingDevices;
                                    dd[coreContainer.myId] = true;
                                    window.disconnectingDevices = Object.assign({}, dd);
                                    busyTimeout.restart();
                                    let cmd = window.activeMode === "wifi" ? "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE d | grep wifi | cut -d: -f1 | head -n1)" : "bash " + window.scriptsDir + "/bluetooth_panel_logic.sh --disconnect '" + coreContainer.myDevice.mac + "'";
                                    Quickshell.execDetached(["sh", "-c", cmd]);
                                    window.markRecentAction();
                                    centralCore.disconnectFill = 0.0;
                                    centralCore.disconnectTriggered = false;
                                    if (window.activeMode === "wifi")
                                        wifiPoller.running = true;
                                    else
                                        btPoller.running = true;
                                }
                            }
                            NumberAnimation {
                                id: coreDrainAnim
                                target: centralCore
                                property: "disconnectFill"
                                to: 0.0
                                duration: 1000 * centralCore.disconnectFill
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: window.currentPower ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Repeater {
                        id: orbitRepeater
                        model: (window.currentConn && window.showInfoView) ? infoListModel : (window.activeMode === "wifi" ? wifiListModel : btListModel)

                        delegate: Item {
                            id: floatCardDelegateContainer
                            width: 210
                            height: 100
                            property bool isLoaded: false
                            opacity: isLoaded ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutQuint
                                }
                            }
                            property real entryAnim: isLoaded ? 1.0 : 0.0
                            Behavior on entryAnim {
                                NumberAnimation {
                                    duration: 600
                                    easing.type: Easing.OutBack
                                }
                            }
                            layer.enabled: opacity > 0 && opacity < 1 || entryAnim < 1.0 || (floatMa && floatMa.containsMouse)
                            layer.smooth: true
                            Timer {
                                running: true
                                interval: 40 + (index * 30)
                                onTriggered: {
                                    floatCardDelegateContainer.isLoaded = true;
                                    nodeLinesCanvas.requestPaint();
                                }
                            }
                            onXChanged: {
                                if (!ThemePkg.Theme.edgeAnimationsEnabled && isLoaded)
                                    nodeLinesCanvas.requestPaint();
                            }
                            onYChanged: {
                                if (!ThemePkg.Theme.edgeAnimationsEnabled && isLoaded)
                                    nodeLinesCanvas.requestPaint();
                            }
                            onIsLoadedChanged: {
                                if (isLoaded)
                                    nodeLinesCanvas.requestPaint();
                            }

                            property int myParentIdx: model.parentIndex !== undefined ? model.parentIndex : -1
                            property int siblingsCount: {
                                let c = 0;
                                let m = orbitRepeater.model;
                                if (m && m.count !== undefined) {
                                    for (let i = 0; i < m.count; i++) {
                                        let d = m.get(i);
                                        if (d && (d.parentIndex !== undefined ? d.parentIndex : -1) === myParentIdx)
                                            c++;
                                    }
                                }
                                return Math.max(1, c);
                            }
                            property int localIndex: {
                                let idx = 0;
                                let m = orbitRepeater.model;
                                if (m && m.count !== undefined) {
                                    for (let i = 0; i < index; i++) {
                                        let d = m.get(i);
                                        if (d && (d.parentIndex !== undefined ? d.parentIndex : -1) === myParentIdx)
                                            idx++;
                                    }
                                }
                                return idx;
                            }
                            property real unifiedRatio: window.activeMode === "wifi" ? 0.0 : window.multiTransitionState
                            property real activeCount: (unifiedRatio > 0.5 && myParentIdx !== -1) ? siblingsCount : orbitRepeater.count
                            property real dynamicScale: activeCount > 10 ? Math.max(0.6, 12.0 / activeCount) : (unifiedRatio > 0.5 ? (window.activeCoreCount > 2 ? 0.7 : 0.8) : 1.0)
                            property real safeMultiShift: window.activeMode === "wifi" ? 0.0 : window.multiTransitionState
                            property var pItem: myParentIdx !== -1 ? coreRepeater.itemAt(myParentIdx) : null
                            property real parentX: pItem ? (orbitContainer.width / 2) + (Math.cos(parentCoreAngle) * pItem.myOrbitRadiusX * safeMultiShift * pItem.activeTransition) : (orbitContainer.width / 2)
                            property real parentY: pItem ? (orbitContainer.height / 2) + (Math.sin(parentCoreAngle) * pItem.myOrbitRadiusY * safeMultiShift * pItem.activeTransition) : (orbitContainer.height / 2)
                            property real parentBaseAngle: pItem ? pItem.animatedBaseAngle : 0
                            property real targetSingleBaseAngle: (index / Math.max(1, orbitRepeater.count)) * Math.PI * 2
                            property real singleBaseAngle: targetSingleBaseAngle
                            Behavior on singleBaseAngle {
                                NumberAnimation {
                                    duration: 800
                                    easing.type: Easing.OutExpo
                                }
                            }
                            property real singleLiveAngle: (window.globalOrbitAngle * 1.5) + singleBaseAngle
                            property real arcSpread: Math.PI * 0.8
                            property real targetNodeOffset: (siblingsCount > 1) ? ((localIndex / (siblingsCount - 1)) - 0.5) * arcSpread : 0
                            property real nodeOffset: targetNodeOffset
                            Behavior on nodeOffset {
                                NumberAnimation {
                                    duration: 800
                                    easing.type: Easing.OutExpo
                                }
                            }
                            property real parentCoreAngle: (window.globalOrbitAngle * 1.5) + parentBaseAngle
                            property real multiLiveAngle: myParentIdx === -1 ? singleLiveAngle : (parentCoreAngle + nodeOffset)
                            property int ringIndex: isInfoNode ? 0 : index % 2
                            property real targetRingOffset: ringIndex * 30
                            property real ringOffset: targetRingOffset
                            Behavior on ringOffset {
                                NumberAnimation {
                                    duration: 800
                                    easing.type: Easing.OutExpo
                                }
                            }
                            property real singleRadX: isInfoNode ? 240 : 280 + ringOffset
                            property real singleRadY: isInfoNode ? 155 : 175 + ringOffset
                            property real multiRadX: isInfoNode ? (myParentIdx === -1 ? 0 : (window.activeCoreCount > 2 ? 155 : 135)) : 230 + ringOffset
                            property real multiRadY: isInfoNode ? (myParentIdx === -1 ? 0 : (window.activeCoreCount > 2 ? 155 : 135)) : 140 + ringOffset
                            property real currentRadX: (singleRadX * (1 - unifiedRatio)) + (multiRadX * unifiedRatio)
                            property real currentRadY: (singleRadY * (1 - unifiedRatio)) + (multiRadY * unifiedRatio)
                            property real currentAngle: (singleLiveAngle * (1 - unifiedRatio)) + (multiLiveAngle * unifiedRatio)
                            property real pwrDrift: window.currentPower ? 0 : 40
                            Behavior on pwrDrift {
                                NumberAnimation {
                                    duration: 600
                                    easing.type: Easing.OutQuint
                                }
                            }
                            property real animRadX: (currentRadX + pwrDrift) * (0.25 + 0.75 * entryAnim)
                            property real animRadY: (currentRadY + pwrDrift) * (0.25 + 0.75 * entryAnim)
                            property real targetX: myParentIdx === -1 ? (orbitContainer.width / 2) - (width / 2) + Math.cos(currentAngle) * animRadX : parentX - (width / 2) + Math.cos(currentAngle) * animRadX
                            property real targetY: myParentIdx === -1 ? (orbitContainer.height / 2) - (height / 2) + Math.sin(currentAngle) * animRadY : parentY - (height / 2) + Math.sin(currentAngle) * animRadY
                            property real liveBob: myParentIdx === -1 && isInfoNode ? Math.sin(window.globalOrbitAngle * 6) * 12 * (1 - unifiedRatio) : 0
                            x: Math.round(targetX)
                            y: Math.round(targetY + liveBob)
                            scale: (!isLoaded ? 0.0 : (floatMa.pressed ? dynamicScale * 0.95 : (floatCard.locksList ? dynamicScale * 1.08 : dynamicScale))) * floatCard.bumpScale
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutQuart
                                }
                            }
                            z: floatCard.locksList ? 10 : index

                            MultiEffect {
                                source: floatCard
                                anchors.fill: floatCard
                                shadowEnabled: window.currentPower && floatCardDelegateContainer.opacity > 0.05
                                shadowColor: "#000000"
                                shadowOpacity: 0.3
                                shadowBlur: 0.8
                                shadowVerticalOffset: 4
                                z: -1
                            }

                            Rectangle {
                                id: floatCard
                                anchors.centerIn: parent
                                width: 170
                                height: 60
                                radius: 14
                                property string itemId: id
                                property string itemName: name
                                property string mySsid: model.ssid || ""
                                property string mySecurity: model.security || ""
                                property bool isKnownNetwork: model.known || false
                                property bool connectionFailed: false
                                property bool isMyBusy: !!window.busyTasks[itemId]
                                property bool isPairedBT: window.activeMode === "bt" && action === "Connect"
                                property bool isTargetWifi: window.activeMode === "wifi" && !window.isWifiConn && itemId === window.targetWifiSsid
                                property bool isSpecialAction: itemId === "action_scan" || itemId === "action_settings" || itemId === "action_refresh" || cmdStr === "RUN_SPEEDTEST" || cmdStr === "OPEN_VPN"
                                property bool isSpeedtestCard: cmdStr === "RUN_SPEEDTEST"
                                property bool isSpeedtestRunning: isSpeedtestCard && window.speedtestState === "running"
                                property bool isSpeedtestDone: isSpeedtestCard && (window.speedtestState === "done" || window.speedtestState === "error")
                                property bool isTailscaleInfoCard: itemId.indexOf("tailscale_") === 0
                                property bool isHighlighted: isPairedBT || isTargetWifi || isSpecialAction
                                property bool isCurrentlyConnected: {
                                    if (window.activeMode === "wifi")
                                        return (window.wifiConnected && window.wifiConnected.ssid === itemId);
                                    for (let i = 0; i < window.btConnected.length; i++) {
                                        if (window.btConnected[i].mac === itemId)
                                            return true;
                                    }
                                    return false;
                                }
                                property bool isInteractable: !isInfoNode || isActionable
                                property bool isTrafficInfoCard: itemId.indexOf("traffic_") === 0
                                property bool forgetActive: false
                                property bool locksList: isInteractable && (floatMa.containsMouse || floatMa.pressed || forgetActive)
                                onLocksListChanged: {
                                    if (locksList)
                                        window.hoveredCardCount++;
                                    else
                                        window.hoveredCardCount--;
                                }
                                Component.onDestruction: {
                                    if (locksList)
                                        window.hoveredCardCount--;
                                }
                                property real bumpScale: 1.0
                                SequentialAnimation on bumpScale {
                                    id: cardBumpAnim
                                    running: false
                                    NumberAnimation {
                                        to: 1.2
                                        duration: 200
                                        easing.type: Easing.OutBack
                                    }
                                    NumberAnimation {
                                        to: 1.0
                                        duration: 600
                                        easing.type: Easing.OutQuint
                                    }
                                }
                                property real nameImplicitWidth: baseNameText.implicitWidth
                                property real nameContainerWidth: nameContainerBase.width
                                property bool doMarquee: !isTrafficInfoCard && floatMa.containsMouse && nameImplicitWidth > nameContainerWidth
                                property real textOffset: 0
                                SequentialAnimation on textOffset {
                                    running: floatCard.doMarquee && ThemePkg.Theme.edgeAnimationsEnabled
                                    loops: Animation.Infinite
                                    PauseAnimation {
                                        duration: 600
                                    }
                                    NumberAnimation {
                                        from: 0
                                        to: -(floatCard.nameImplicitWidth + 30)
                                        duration: (floatCard.nameImplicitWidth + 30) * 35
                                    }
                                }
                                onDoMarqueeChanged: if (!doMarquee)
                                    textOffset = 0
                                property real fillLevel: 0.0
                                property bool triggered: false
                                property real flashOpacity: 0.0
                                property real renderFill: (isCurrentlyConnected) ? 1.0 : fillLevel
                                onIsMyBusyChanged: {
                                    if (!isMyBusy && triggered) {
                                        triggered = false;
                                        if (connectionFailed)
                                            connectionFailed = false;
                                        if (!floatCard.isCurrentlyConnected)
                                            drainAnim.start();
                                    }
                                }
                                onIsCurrentlyConnectedChanged: {
                                    if (!isCurrentlyConnected && fillLevel > 0)
                                        drainAnim.start();
                                }
                                color: false ? "#2affffff" : "#0effffff"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }

                                property bool askingPassword: false
                                property real pwdAnimOffset: askingPassword ? 1.0 : 0.0
                                Behavior on pwdAnimOffset {
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutBack
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: "transparent"
                                    border.width: 1
                                    border.color: window.panelBorderColor
                                    visible: !cardMa.containsMouse && !false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    opacity: false || cardMa.containsMouse ? 1.0 : 0.0
                                    color: "transparent"
                                    border.width: cardMa.containsMouse && !false ? 1 : 2
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 250
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: cardMa.containsMouse && !false ? 1 : 2
                                        radius: 12
                                        color: window.base
                                        opacity: false ? 0.9 : 1.0
                                    }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop {
                                            position: 0.0
                                            color: Qt.lighter(window.activeColor, 1.15)
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: window.activeColor
                                        }
                                    }
                                    z: -1
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: "#ffffff"
                                    opacity: floatCard.flashOpacity
                                    z: 5
                                    PropertyAnimation on opacity {
                                        id: cardFlashAnim
                                        to: 0
                                        duration: 500
                                        easing.type: Easing.OutExpo
                                    }
                                }

                                Canvas {
                                    id: waveCanvas
                                    anchors.fill: parent
                                    property real wavePhase: 0.0
                                    NumberAnimation on wavePhase {
                                        running: floatCard.renderFill > 0.0 && floatCard.renderFill < 1.0 && ThemePkg.Theme.edgeAnimationsEnabled
                                        loops: Animation.Infinite
                                        from: 0
                                        to: Math.PI * 2
                                        duration: 800
                                    }
                                    onWavePhaseChanged: requestPaint()
                                    Connections {
                                        target: floatCard
                                        function onRenderFillChanged() {
                                            waveCanvas.requestPaint();
                                        }
                                    }
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        if (floatCard.renderFill <= 0.001)
                                            return;
                                        var currentW = width * floatCard.renderFill;
                                        var r = 14;
                                        ctx.save();
                                        ctx.beginPath();
                                        ctx.moveTo(0, 0);
                                        if (floatCard.renderFill < 0.99) {
                                            var waveAmp = 12 * Math.sin(floatCard.renderFill * Math.PI);
                                            if (currentW - waveAmp < 0)
                                                waveAmp = currentW;
                                            var cp1x = currentW + Math.sin(wavePhase) * waveAmp;
                                            var cp2x = currentW + Math.cos(wavePhase + Math.PI) * waveAmp;
                                            ctx.lineTo(currentW, 0);
                                            ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                                            ctx.lineTo(0, height);
                                        } else {
                                            ctx.lineTo(width, 0);
                                            ctx.lineTo(width, height);
                                            ctx.lineTo(0, height);
                                        }
                                        ctx.closePath();
                                        ctx.clip();
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
                                        var grad = ctx.createLinearGradient(0, 0, currentW, 0);
                                        grad.addColorStop(0, Qt.lighter(window.activeColor, 1.15).toString());
                                        grad.addColorStop(1, window.activeColor.toString());
                                        ctx.fillStyle = grad;
                                        ctx.fill();
                                        ctx.restore();
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: window.activeColor
                                    border.width: 2
                                    visible: parent.isHighlighted && !parent.isMyBusy && !parent.isCurrentlyConnected
                                    SequentialAnimation on scale {
                                        loops: Animation.Infinite
                                        running: parent.visible && ThemePkg.Theme.edgeAnimationsEnabled
                                        NumberAnimation {
                                            to: 1.15
                                            duration: 1200
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            to: 1.0
                                            duration: 1200
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: parent.visible && ThemePkg.Theme.edgeAnimationsEnabled
                                        NumberAnimation {
                                            to: 0.0
                                            duration: 1200
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            to: 0.8
                                            duration: 1200
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }

                                RowLayout {
                                    id: baseTextRow
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10
                                    opacity: 1.0 - floatCard.pwdAnimOffset
                                    scale: 1.0 - (floatCard.pwdAnimOffset * 0.1)
                                    visible: opacity > 0.0
                                    Text {
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 20
                                        color: floatCard.isMyBusy ? window.text : window.activeColor
                                        text: icon
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Item {
                                            id: nameContainerBase
                                            Layout.fillWidth: true
                                            height: 18
                                            clip: true
                                            visible: !floatCard.isSpeedtestRunning
                                            Text {
                                                id: baseNameText
                                                anchors.left: parent.left
                                                anchors.leftMargin: floatCard.textOffset
                                                width: parent.width
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: floatCard.itemName
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                font.pixelSize: (floatCard.isTrafficInfoCard || floatCard.isSpeedtestDone || floatCard.isTailscaleInfoCard) ? 11 : 13
                                                color: floatCard.isHighlighted ? window.activeColor : window.text
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                anchors.left: baseNameText.right
                                                anchors.leftMargin: 30
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: floatCard.doMarquee && !floatCard.isTrafficInfoCard
                                                text: floatCard.itemName
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                font.pixelSize: 13
                                                color: floatCard.isHighlighted ? window.activeColor : window.text
                                            }
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                            height: 18
                                            visible: floatCard.isSpeedtestRunning
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 5
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Testing"
                                                    font.family: "JetBrains Mono"
                                                    font.weight: Font.Bold
                                                    font.pixelSize: 13
                                                    color: window.activeColor
                                                }
                                                LoadingDots {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    dotCol: window.activeColor
                                                    dotSize: 4
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 10
                                            color: floatCard.connectionFailed ? window.red : (floatCard.isMyBusy ? window.activeColor : window.overlay0)
                                            text: floatCard.connectionFailed ? "Wrong Password" : (floatCard.isMyBusy ? "Connecting..." : (floatCard.renderFill > 0.1 && floatCard.renderFill < 1.0 ? "Hold..." : action))
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 200
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: floatCard.width * floatCard.renderFill
                                    clip: true
                                    opacity: 1.0 - floatCard.pwdAnimOffset
                                    visible: opacity > 0.0
                                    RowLayout {
                                        x: baseTextRow.x
                                        y: baseTextRow.y
                                        width: baseTextRow.width
                                        height: baseTextRow.height
                                        spacing: 10
                                        Text {
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: 20
                                            color: window.crust
                                            text: icon
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Item {
                                                Layout.fillWidth: true
                                                height: 18
                                                clip: true
                                                visible: !floatCard.isSpeedtestRunning
                                                Text {
                                                    id: filledNameText
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: floatCard.textOffset
                                                    width: parent.width
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: floatCard.itemName
                                                    font.family: "JetBrains Mono"
                                                    font.weight: Font.Bold
                                                    font.pixelSize: (floatCard.isTrafficInfoCard || floatCard.isSpeedtestDone || floatCard.isTailscaleInfoCard) ? 11 : 13
                                                    color: window.crust
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    anchors.left: filledNameText.right
                                                    anchors.leftMargin: 30
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: floatCard.doMarquee && !floatCard.isTrafficInfoCard
                                                    text: floatCard.itemName
                                                    font.family: "JetBrains Mono"
                                                    font.weight: Font.Bold
                                                    font.pixelSize: 13
                                                    color: window.crust
                                                }
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                                height: 18
                                                visible: floatCard.isSpeedtestRunning
                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 5
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Testing"
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Bold
                                                        font.pixelSize: 13
                                                        color: window.crust
                                                    }
                                                    LoadingDots {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        dotCol: window.crust
                                                        dotSize: 4
                                                    }
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 10
                                                color: floatCard.connectionFailed ? window.red : window.crust
                                                text: floatCard.connectionFailed ? "Wrong Password" : (floatCard.isMyBusy ? "Connecting..." : (floatCard.renderFill > 0.1 && floatCard.renderFill < 1.0 ? "Hold..." : action))
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    anchors.rightMargin: 8
                                    spacing: 4
                                    opacity: (floatMa.containsMouse || floatCard.forgetActive) && !floatCard.askingPassword && !floatCard.isSpecialAction && !floatCard.isInfoNode ? 1.0 : 0.0
                                    visible: opacity > 0.0
                                    z: 15
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }

                                    Rectangle {
                                        id: forgetBtnRect
                                        visible: window.activeMode === "wifi" ? floatCard.isKnownNetwork : true
                                        Layout.preferredWidth: 32
                                        Layout.fillHeight: true
                                        radius: 10
                                        property real forgetFill: 0.0
                                        property bool forgetTriggered: false
                                        color: forgetMa.containsMouse ? window.surface1 : "transparent"
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * parent.forgetFill
                                            color: window.red
                                            radius: 10
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: "Iosevka Nerd Font"
                                            text: "󰆴"
                                            color: forgetBtnRect.forgetFill > 0.5 ? window.crust : (forgetMa.containsMouse ? window.red : window.subtext0)
                                            font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: forgetMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: (forgetBtnRect.forgetTriggered) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onContainsMouseChanged: {
                                                if (containsMouse) {
                                                    floatCard.forgetActive = true;
                                                } else if (forgetBtnRect.forgetFill <= 0.0 && !forgetBtnRect.forgetTriggered) {
                                                    floatCard.forgetActive = false;
                                                }
                                            }
                                            onPressed: {
                                                if (!forgetBtnRect.forgetTriggered && forgetBtnRect.forgetFill === 0.0) {
                                                    floatCard.forgetActive = true;
                                                    forgetDrainAnim.stop();
                                                    forgetFillAnim.start();
                                                }
                                            }
                                            onReleased: {
                                                if (!forgetBtnRect.forgetTriggered && forgetBtnRect.forgetFill < 1.0) {
                                                    forgetFillAnim.stop();
                                                    forgetDrainAnim.start();
                                                }
                                            }
                                        }
                                        NumberAnimation {
                                            id: forgetFillAnim
                                            target: forgetBtnRect
                                            property: "forgetFill"
                                            to: 1.0
                                            duration: 600 * (1.0 - forgetBtnRect.forgetFill)
                                            easing.type: Easing.InSine
                                            onFinished: {
                                                forgetBtnRect.forgetTriggered = true;
                                                if (window.activeMode === "wifi") {
                                                    Quickshell.execDetached(["nmcli", "connection", "delete", "id", floatCard.mySsid]);
                                                    wifiPoller.running = true;
                                                } else {
                                                    let cmd = "bash " + window.scriptsDir + "/bluetooth_panel_logic.sh --disconnect " + floatCard.itemId + "; bash " + window.scriptsDir + "/bluetooth_panel_logic.sh --remove " + floatCard.itemId;
                                                    Quickshell.execDetached(["sh", "-c", cmd]);
                                                    btPoller.running = true;
                                                }
                                                forgetDrainAnim.start();
                                            }
                                        }
                                        NumberAnimation {
                                            id: forgetDrainAnim
                                            target: forgetBtnRect
                                            property: "forgetFill"
                                            to: 0.0
                                            duration: 1000 * forgetBtnRect.forgetFill
                                            easing.type: Easing.OutQuad
                                            onFinished: {
                                                forgetBtnRect.forgetTriggered = false;
                                                floatCard.forgetActive = false;
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: pwdInputContainer
                                    anchors.fill: parent
                                    z: 20
                                    opacity: floatCard.pwdAnimOffset
                                    visible: opacity > 0.0
                                    scale: 0.9 + (floatCard.pwdAnimOffset * 0.1)

                                    Process {
                                        id: wifiConnectProcess
                                        property string targetSsid: ""
                                        command: ["echo"]
                                        stderr: StdioCollector {
                                            onStreamFinished: {
                                                let errText = this.text.trim();
                                                if (errText.indexOf("Error") !== -1 || errText.indexOf("Secrets were required") !== -1 || errText.indexOf("No suitable") !== -1) {
                                                    floatCard.connectionFailed = true;
                                                    let bt = window.busyTasks;
                                                    delete bt[floatCard.itemId];
                                                    window.busyTasks = Object.assign({}, bt);
                                                }
                                            }
                                        }
                                    }

                                    function submitPassword() {
                                        if (pwdInput.text.trim() === "") {
                                            floatCard.askingPassword = false;
                                            return;
                                        }
                                        floatCard.askingPassword = false;
                                        floatCard.connectionFailed = false;
                                        let bt = window.busyTasks;
                                        bt[floatCard.itemId] = true;
                                        window.busyTasks = Object.assign({}, bt);
                                        busyTimeout.restart();
                                        let pwd = pwdInput.text;
                                        wifiConnectProcess.command = ["nmcli", "device", "wifi", "connect", floatCard.mySsid, "password", pwd];
                                        wifiConnectProcess.running = true;
                                        window.markRecentAction();
                                        wifiPoller.running = true;
                                        pwdInput.text = "";
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 10
                                            color: window.surface0
                                            border.color: pwdInput.activeFocus ? window.activeColor : window.panelBorderColor
                                            border.width: 1
                                            clip: true
                                            TextInput {
                                                id: pwdInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 13
                                                color: window.text
                                                echoMode: TextInput.Password
                                                passwordCharacter: "•"
                                                clip: true
                                                onAccepted: pwdInputContainer.submitPassword()
                                                Keys.onEscapePressed: {
                                                    floatCard.askingPassword = false;
                                                    text = "";
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.fillHeight: true
                                            radius: 10
                                            color: pwdSubmitMa.containsMouse ? window.activeColor : window.surface1
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 200
                                                }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                font.family: "Iosevka Nerd Font"
                                                text: "󰄾"
                                                color: pwdSubmitMa.containsMouse ? window.crust : window.text
                                                font.pixelSize: 16
                                            }
                                            MouseArea {
                                                id: pwdSubmitMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pwdInputContainer.submitPassword()
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: floatMa
                                    anchors.fill: parent
                                    hoverEnabled: floatCard.isInteractable && !floatCard.askingPassword
                                    cursorShape: (floatCard.triggered || floatCard.isMyBusy || floatCard.renderFill === 1.0 || !floatCard.isInteractable || floatCard.askingPassword) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onPressed: {
                                        if (floatCard.askingPassword)
                                            return;
                                        if (floatCard.isInteractable && !floatCard.triggered && !floatCard.isMyBusy && floatCard.fillLevel === 0.0) {
                                            drainAnim.stop();
                                            fillAnim.start();
                                        }
                                    }
                                    onReleased: {
                                        if (floatCard.askingPassword)
                                            return;
                                        if (floatCard.isInteractable && !floatCard.triggered && !floatCard.isMyBusy && floatCard.fillLevel < 1.0) {
                                            fillAnim.stop();
                                            drainAnim.start();
                                        }
                                    }
                                }
                                NumberAnimation {
                                    id: fillAnim
                                    target: floatCard
                                    property: "fillLevel"
                                    to: 1.0
                                    duration: 600 * (1.0 - floatCard.fillLevel)
                                    easing.type: Easing.InSine
                                    onFinished: {
                                        floatCard.triggered = true;
                                        floatCard.flashOpacity = 0.6;
                                        cardFlashAnim.start();
                                        cardBumpAnim.start();
                                        if (cmdStr === "TOGGLE_VIEW") {
                                            window.showInfoView = !window.showInfoView;
                                            floatCard.triggered = false;
                                            drainAnim.start();
                                        } else if (cmdStr === "RESCAN") {
                                            let cmd = window.activeMode === "wifi" ? "nmcli device wifi rescan" : "bash " + window.scriptsDir + "/bluetooth_panel_logic.sh --scan";
                                            Quickshell.execDetached(["sh", "-c", cmd]);
                                            floatCard.triggered = false;
                                            drainAnim.start();
                                        } else if (cmdStr === "RUN_SPEEDTEST") {
                                            window.launchNetworkSpeedtest();
                                            floatCard.triggered = false;
                                            drainAnim.start();
                                        } else if (cmdStr === "OPEN_VPN") {
                                            if (window.overlaySwitcher)
                                                window.overlaySwitcher.swap("vpn");
                                            floatCard.triggered = false;
                                            drainAnim.start();
                                        } else if (isInfoNode && cmdStr) {
                                            Quickshell.execDetached(["sh", "-c", cmdStr]);
                                            if (window.activeMode === "bt")
                                                btPoller.running = true;
                                            floatCard.triggered = false;
                                            drainAnim.start();
                                        } else {
                                            if (window.activeMode === "wifi" && floatCard.mySecurity !== "Open" && floatCard.mySecurity !== "Wired" && floatCard.mySecurity !== "" && !floatCard.isCurrentlyConnected && !floatCard.isKnownNetwork) {
                                                floatCard.askingPassword = true;
                                                floatCard.triggered = false;
                                                drainAnim.start();
                                                pwdInput.text = "";
                                                pwdInput.forceActiveFocus();
                                            } else {
                                                floatCard.connectionFailed = false;
                                                let bt = window.busyTasks;
                                                bt[floatCard.itemId] = true;
                                                window.busyTasks = Object.assign({}, bt);
                                                busyTimeout.restart();
                                                if (window.activeMode === "wifi") {
                                                    Quickshell.execDetached(["nmcli", "device", "wifi", "connect", floatCard.mySsid]);
                                                } else {
                                                    let cmd = "bash " + window.scriptsDir + "/bluetooth_panel_logic.sh --connect " + mac;
                                                    Quickshell.execDetached(["sh", "-c", cmd]);
                                                }
                                                window.markRecentAction();
                                                if (window.activeMode === "wifi")
                                                    wifiPoller.running = true;
                                                else
                                                    btPoller.running = true;
                                            }
                                        }
                                    }
                                }
                                NumberAnimation {
                                    id: drainAnim
                                    target: floatCard
                                    property: "fillLevel"
                                    to: 0.0
                                    duration: 1500 * floatCard.fillLevel
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 25
                width: 430
                height: 54
                radius: 14
                color: "#1affffff"
                border.color: "#1affffff"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: window.activeMode === "wifi" ? "transparent" : (wifiTabMa.containsMouse ? window.surface1 : "transparent")
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: window.activeMode === "wifi" ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                }
                            }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.lighter(window.isEthConn && !window.isWifiConn ? window.ethAccent : window.wifiAccent, 1.15)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: window.isEthConn && !window.isWifiConn ? window.ethAccent : window.wifiAccent
                                }
                            }
                        }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 18
                                color: window.activeMode === "wifi" ? window.crust : window.text
                                text: "󰛳"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                            Text {
                                font.family: window.textFont
                                font.weight: Font.Black
                                font.pixelSize: 13
                                color: window.activeMode === "wifi" ? window.crust : window.text
                                text: "Network"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: wifiTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.activeMode = "wifi";
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        Layout.margins: 5
                        color: "#33ffffff"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: window.activeMode === "bt" ? "transparent" : (btTabMa.containsMouse ? window.surface1 : "transparent")
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: window.activeMode === "bt" ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                }
                            }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.lighter(window.btAccent, 1.15)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: window.btAccent
                                }
                            }
                        }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 18
                                color: window.activeMode === "bt" ? window.crust : window.text
                                text: "󰂯"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                            Text {
                                font.family: window.textFont
                                font.weight: Font.Black
                                font.pixelSize: 13
                                color: window.activeMode === "bt" ? window.crust : window.text
                                text: "Bluetooth"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: btTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.activeMode = "bt";
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        Layout.margins: 5
                        color: "#33ffffff"
                    }

                    Rectangle {
                        id: pwrBtnContainer
                        Layout.preferredWidth: 42
                        Layout.fillHeight: true
                        radius: 10
                        color: "transparent"

                        property bool buttonDisabled: window.activeMode === "wifi" && window.isEthConn
                        opacity: buttonDisabled ? 0.42 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        ToolTip.visible: pwrMa.containsMouse
                        ToolTip.delay: 250
                        ToolTip.text: buttonDisabled
                             ? "Wi-Fi is disabled while connected to Ethernet"
                             : (window.currentPower ? "Turn off" : "Turn on")

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: window.currentPower ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                }
                            }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.lighter(window.activeColor, 1.15)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: window.activeColor
                                }
                            }
                        }
                        border.width: 2
                        border.color: window.currentPowerPending ? window.activeColor : (window.currentPower ? "transparent" : window.panelBorderColor)
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 300
                            }
                        }
                        scale: pwrMa.pressed ? 0.9 : (pwrMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutBack
                            }
                        }
                        Text {
                            id: pwrIcon
                            anchors.centerIn: parent
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 20
                            color: window.currentPower ? window.crust : window.text
                            text: window.currentPowerPending ? "󰑮" : "󰐥"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                            RotationAnimation {
                                target: pwrIcon
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                                running: window.currentPowerPending && ThemePkg.Theme.edgeAnimationsEnabled
                                onRunningChanged: {
                                    if (!running)
                                        pwrIcon.rotation = 0;
                                }
                            }
                        }
                        MouseArea {
                            id: pwrMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !pwrBtnContainer.buttonDisabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (window.activeMode === "wifi") {
                                    if (window.wifiPowerPending)
                                        return;
                                    window.expectedWifiPower = window.wifiPower === "on" ? "off" : "on";
                                    window.wifiPowerPending = true;
                                    wifiPendingReset.restart();
                                    window.wifiPower = window.expectedWifiPower;
                                    Quickshell.execDetached(["nmcli", "radio", "wifi", window.wifiPower]);
                                    wifiPoller.running = true;
                                } else {
                                    if (window.btPowerPending)
                                        return;
                                    window.expectedBtPower = window.btPower === "on" ? "off" : "on";
                                    window.btPowerPending = true;
                                    btPendingReset.restart();
                                    window.btPower = window.expectedBtPower;
                                    Quickshell.execDetached(["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--toggle"]);
                                    btPoller.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
