import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../theme" as ThemePkg

Item {
    id: root
    anchors.fill: parent

    readonly property int panelWidth: 760
    readonly property int panelHeight: 610
    readonly property int panelMargin: 16
    readonly property real popupOpenWidth: root.panelWidth
    readonly property real popupOpenHeight: root.panelHeight
    readonly property real popupClosedWidth: root.panelWidth - 44
    readonly property real popupClosedHeight: root.panelHeight - 28
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 34
    readonly property int overlayEnterDuration: 405
    readonly property int overlayExitDuration: 305
    readonly property bool overlayOwnsCloseAnimation: true

    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color mantle: ThemePkg.Theme.surface(0.05)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    readonly property color accent: Qt.lighter(ThemePkg.Theme.c4, 1.12)
    readonly property color green: ThemePkg.Theme.success
    readonly property color red: ThemePkg.Theme.danger
    readonly property color yellow: ThemePkg.Theme.warning
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property string textFont: "Fira Sans"
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/network"
    readonly property string vpnScriptPath: root.scriptsDir + "/vpn_panel_logic.sh"

    property var overlaySwitcher: null
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity
    property real introMain: 0.0
    property real globalOrbitAngle: 0.0

    property bool vpnActive: false
    property string backendState: "Unknown"
    property string selfName: "Tailscale"
    property string selfIp: ""
    property string selfOs: ""
    property int onlineCount: 0
    property int offlineCount: 0
    property int totalCount: 0
    property string exitNode: ""
    property string rxText: "0 B"
    property string txText: "0 B"
    property string messageText: ""
    property string actionHeadline: ""
    property string actionDetail: ""
    property bool showOffline: true
    property string selectedId: ""
    property string selectedName: ""
    property string selectedIp: ""
    property string selectedDns: ""
    property bool selectedOnline: false
    property bool selectedExitOption: false
    property bool selectedIsExitNode: false

    readonly property color stateColor: vpnActive ? accent : red
    readonly property string selectedTarget: selectedDns !== "" ? selectedDns : (selectedIp !== "" ? selectedIp : selectedId)
    readonly property bool hasSelectedPeer: selectedId !== ""
    readonly property int visiblePeerCount: {
        if (showOffline)
            return peersModel.count;
        let count = 0;
        for (let i = 0; i < peersModel.count; i++) {
            if (peersModel.get(i).online)
                count++;
        }
        return count;
    }

    ListModel {
        id: peersModel
    }

    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 140000
        loops: Animation.Infinite
        running: ThemePkg.Theme.edgeAnimationsEnabled
    }

    function osIcon(os) {
        let s = String(os || "").toLowerCase();
        if (s.indexOf("linux") !== -1)
            return "󰌽";
        if (s.indexOf("windows") !== -1)
            return "󰖳";
        if (s.indexOf("darwin") !== -1 || s.indexOf("mac") !== -1 || s.indexOf("ios") !== -1)
            return "󰀵";
        if (s.indexOf("android") !== -1)
            return "󰀲";
        return "󰌘";
    }

    function cleanLastSeen(value) {
        let text = String(value || "");
        if (text === "" || text === "0001-01-01T00:00:00Z")
            return "Never seen";
        return text.replace("T", " ").replace("Z", "");
    }

    function selectPeer(peer) {
        root.selectedId = peer.id || "";
        root.selectedName = peer.name || peer.dns || peer.ip || "Device";
        root.selectedIp = peer.ip || "";
        root.selectedDns = peer.dns || "";
        root.selectedOnline = !!peer.online;
        root.selectedExitOption = !!peer.exit_node_option;
        root.selectedIsExitNode = !!peer.exit_node;
    }

    function syncPeers(dataArray) {
        for (let i = peersModel.count - 1; i >= 0; i--) {
            let id = peersModel.get(i).id;
            let found = false;
            for (let j = 0; j < dataArray.length; j++) {
                if (id === dataArray[j].id) {
                    found = true;
                    break;
                }
            }
            if (!found)
                peersModel.remove(i);
        }

        for (let i = 0; i < dataArray.length; i++) {
            let d = dataArray[i];
            let obj = {
                id: d.id || "",
                name: d.name || d.dns || d.ip || "Device",
                dns: d.dns || "",
                ip: d.ip || "",
                os: d.os || "",
                online: !!d.online,
                active: !!d.active,
                last_seen: d.last_seen || "",
                relay: d.relay || "",
                rx_bytes: d.rx_bytes || 0,
                tx_bytes: d.tx_bytes || 0,
                exit_node: !!d.exit_node,
                exit_node_option: !!d.exit_node_option,
                tags: d.tags || ""
            };
            let foundIdx = -1;
            for (let j = i; j < peersModel.count; j++) {
                if (peersModel.get(j).id === obj.id) {
                    foundIdx = j;
                    break;
                }
            }
            if (foundIdx === -1) {
                peersModel.insert(i, obj);
            } else {
                if (foundIdx !== i)
                    peersModel.move(foundIdx, i, 1);
                for (let key in obj) {
                    if (peersModel.get(i)[key] !== obj[key])
                        peersModel.setProperty(i, key, obj[key]);
                }
            }
        }

        if (root.selectedId !== "") {
            for (let k = 0; k < peersModel.count; k++) {
                let p = peersModel.get(k);
                if (p.id === root.selectedId) {
                    root.selectPeer(p);
                    return;
                }
            }
            root.selectedId = "";
        }

        for (let firstOnline = 0; firstOnline < peersModel.count; firstOnline++) {
            let candidate = peersModel.get(firstOnline);
            if (candidate.online) {
                root.selectPeer(candidate);
                return;
            }
        }
    }

    function processStatus(textData) {
        let raw = (textData || "").trim();
        if (raw === "")
            return;
        try {
            let data = JSON.parse(raw);
            root.vpnActive = !!data.active;
            root.backendState = data.backend || "Unknown";
            root.selfName = data.self ? (data.self.hostname || "This device") : "This device";
            root.selfIp = data.self ? (data.self.ip || "") : "";
            root.selfOs = data.self ? (data.self.os || "") : "";
            root.onlineCount = data.online_count || 0;
            root.offlineCount = data.offline_count || 0;
            root.totalCount = data.total_count || 0;
            root.exitNode = data.exit_node || "";
            root.rxText = data.rx_text || "0 B";
            root.txText = data.tx_text || "0 B";
            root.messageText = data.message || "";
            root.syncPeers(data.peers || []);
        } catch (e) {
            root.messageText = "Unable to parse Tailscale status";
        }
    }

    function runAction(args) {
        if (actionRunner.running)
            return;
        let cmd = ["bash", root.vpnScriptPath];
        for (let i = 0; i < args.length; i++)
            cmd.push(args[i]);
        root.actionHeadline = "Working...";
        root.actionDetail = cmd.slice(2).join(" ");
        actionRunner.command = cmd;
        actionStartTimer.restart();
    }

    Process {
        id: statusPoller
        command: ["bash", root.vpnScriptPath, "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.processStatus(this.text)
        }
    }

    Process {
        id: actionRunner
        command: ["bash", root.vpnScriptPath, "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = (this.text || "").trim();
                try {
                    let data = JSON.parse(raw);
                    root.actionHeadline = data.summary || "";
                    root.actionDetail = data.detail || "";
                } catch (e) {
                    root.actionHeadline = raw === "" ? "Action finished" : raw;
                    root.actionDetail = "";
                }
                statusPoller.running = true;
            }
        }
    }

    Timer {
        id: actionStartTimer
        interval: 1
        onTriggered: actionRunner.running = true
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: if (!statusPoller.running && !actionRunner.running)
            statusPoller.running = true
    }

    Component.onCompleted: {
        popupTargetVisible = true;
        introMain = 1.0;
        popupEnterAnim.start();
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
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth - 18; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 18; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth + 14; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 16; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }

    Rectangle {
        id: vpnPanel
        width: root.popupCardWidth
        height: root.popupCardHeight
        radius: root.popupCardRadius
        opacity: root.popupCardOpacity
        color: "transparent"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.popupCardLift
        anchors.rightMargin: root.panelMargin

        transform: Scale {
            origin.x: vpnPanel.width / 2
            origin.y: vpnPanel.height / 2
            xScale: root.popupCardScaleX
            yScale: root.popupCardScaleY
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        Rectangle {
            anchors.fill: parent
            radius: vpnPanel.radius
            color: root.base
            border.color: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
            border.width: 1
            clip: true

            ElectricBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: root.stateColor
            }

            Rectangle {
                width: parent.width * 0.78
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 120
                y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 70
                opacity: root.vpnActive ? 0.07 : 0.03
                color: root.stateColor
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 18
                text: "󰒍"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 390
                color: root.stateColor
                opacity: 0.035
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16
                opacity: root.introMain
                transform: Translate { y: 20 * (1.0 - root.introMain) }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: root.vpnActive ? "󰖂" : "󰖪"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 22
                                color: root.stateColor
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.vpnActive ? root.selfName : "Tailscale"
                                font.family: root.textFont
                                font.weight: Font.Black
                                font.pixelSize: 19
                                color: root.text
                                elide: Text.ElideRight
                            }
                            VpnSwitch {
                                Layout.preferredWidth: 104
                                Layout.preferredHeight: 32
                            }
                            ActionButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                icon: "󰑓"
                                label: ""
                                enabled: !statusPoller.running
                                onActivated: statusPoller.running = true
                            }
                            ActionButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                icon: "󰅖"
                                label: ""
                                onActivated: if (root.overlaySwitcher) root.overlaySwitcher.close()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.vpnActive ? (root.selfIp + (root.exitNode !== "" ? " | Exit: " + root.exitNode : "")) : (root.messageText !== "" ? root.messageText : root.backendState)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: root.subtext0
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    spacing: 8
                    StatTile { label: "Online"; value: String(root.onlineCount); accentColor: root.green }
                    StatTile { label: "Offline"; value: String(root.offlineCount); accentColor: root.overlay0 }
                    StatTile { label: "RX"; value: root.rxText; accentColor: root.accent }
                    StatTile { label: "TX"; value: root.txText; accentColor: root.yellow }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: 8

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰅧"
                        label: root.selfIp !== "" ? "Copy IP" : "Copy"
                        enabled: root.selfIp !== "" && !actionRunner.running
                        onActivated: root.runAction(["--copy", root.selfIp])
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰓅"
                        label: root.hasSelectedPeer ? "Ping " + root.selectedName : "Ping Device"
                        enabled: root.hasSelectedPeer && root.selectedOnline && !actionRunner.running
                        busy: actionRunner.running
                        onActivated: root.runAction(["--ping", root.selectedTarget])
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        icon: root.selectedIsExitNode ? "󰌙" : "󰈀"
                        label: root.selectedIsExitNode ? "Clear Exit" : "Use Exit Node"
                        enabled: (root.selectedIsExitNode || root.selectedExitOption) && !actionRunner.running
                        onActivated: root.runAction([root.selectedIsExitNode ? "--clear-exit-node" : "--set-exit-node", root.selectedTarget])
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰀂"
                        label: "Netcheck"
                        enabled: root.vpnActive && !actionRunner.running
                        busy: actionRunner.running
                        onActivated: root.runAction(["--netcheck"])
                    }
                    ActionButton {
                        Layout.preferredWidth: 118
                        icon: root.showOffline ? "󰖭" : "󰖯"
                        label: root.showOffline ? "All" : "Online"
                        onActivated: root.showOffline = !root.showOffline
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: (root.actionHeadline !== "" || actionRunner.running) ? 52 : 0
                    radius: 14
                    color: "#10ffffff"
                    border.color: actionRunner.running ? root.accent : root.panelBorderColor
                    border.width: 1
                    opacity: height > 0 ? 1.0 : 0.0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        Text {
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 18
                            color: root.accent
                            text: actionRunner.running ? "󰑮" : "󰒟"
                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: actionRunner.running && ThemePkg.Theme.edgeAnimationsEnabled
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: actionRunner.running ? "Working..." : root.actionHeadline
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: 12
                                color: root.text
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.actionDetail
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: root.subtext0
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                ListView {
                    id: devicesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rightMargin: 16
                    clip: true
                    spacing: 10
                    boundsBehavior: Flickable.StopAtBounds
                    model: peersModel

                    ThemePkg.FastScrollHandler {
                        anchors.fill: parent
                        flickable: devicesList
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: deviceScrollBar
                        policy: root.visiblePeerCount > 4 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        interactive: true
                        hoverEnabled: true
                        active: policy === ScrollBar.AlwaysOn
                        width: 10
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        background: Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#12ffffff"
                            border.color: "#1affffff"
                            border.width: 1
                        }

                        contentItem: Rectangle {
                            implicitWidth: 10
                            radius: width / 2
                            color: deviceScrollBar.pressed || deviceScrollBar.hovered ? root.accent : root.overlay0
                            border.color: root.panelBorderColor
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    delegate: Rectangle {
                        id: deviceCard
                        width: ListView.view.width
                        height: (!root.showOffline && !online) ? 0 : 82
                        visible: height > 0
                        radius: 14
                        color: cardMa.containsMouse || root.selectedId === id ? "#18ffffff" : "#0dffffff"
                        border.color: root.selectedId === id ? root.accent : "#1affffff"
                        border.width: 1
                        clip: true
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        RowLayout {
                            z: 1
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                radius: 24
                                color: online ? Qt.rgba(root.green.r, root.green.g, root.green.b, 0.18) : "#10ffffff"
                                border.color: online ? root.green : root.overlay0
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 22
                                    color: online ? root.green : root.overlay0
                                    text: root.osIcon(os)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        Layout.fillWidth: true
                                        text: name
                                        font.family: root.textFont
                                        font.weight: Font.Black
                                        font.pixelSize: 14
                                        color: online ? root.text : root.subtext0
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: exit_node ? "EXIT" : (exit_node_option ? "EXIT READY" : (active ? "ACTIVE" : (online ? "ONLINE" : "OFFLINE")))
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: 10
                                        color: exit_node ? root.yellow : (online ? root.green : root.overlay0)
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (ip !== "" ? ip : "No IP") + (relay !== "" ? " | " + relay : "") + (!online ? " | " + root.cleanLastSeen(last_seen) : "")
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    color: root.subtext0
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: dns !== "" ? dns : (tags !== "" ? tags : os)
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    color: root.overlay0
                                    elide: Text.ElideRight
                                }
                            }

                            ActionButton {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                icon: "󰓅"
                                label: ""
                                enabled: online && !actionRunner.running
                                onActivated: {
                                    root.selectPeer(peersModel.get(index));
                                    root.runAction(["--ping", root.selectedTarget]);
                                }
                            }
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 0
                            onClicked: root.selectPeer(peersModel.get(index))
                        }
                    }
                }
            }
        }
    }

    component StatTile: Rectangle {
        property string label: ""
        property string value: ""
        property color accentColor: root.accent
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 10
        color: "#0dffffff"
        border.color: "#1affffff"
        border.width: 1
        RowLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 7
            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 17
                radius: 4
                color: accentColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: value
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    color: root.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: label
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    color: root.subtext0
                    elide: Text.ElideRight
                }
            }
        }
    }

    component VpnSwitch: Rectangle {
        id: vpnSwitch
        radius: 16
        color: "#10ffffff"
        border.color: switchMa.containsMouse ? root.stateColor : "#24ffffff"
        border.width: 1
        opacity: actionRunner.running ? 0.72 : 1.0
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            id: switchFill
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            x: 3
            width: root.vpnActive ? parent.width - 6 : 30
            radius: 13
            color: root.stateColor
            opacity: root.vpnActive ? 0.95 : 0.35
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
            width: 26
            height: 26
            radius: 13
            x: root.vpnActive ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            color: root.vpnActive ? root.crust : root.text
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 180 } }
            Text {
                anchors.centerIn: parent
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 13
                color: root.vpnActive ? root.stateColor : root.crust
                text: actionRunner.running ? "󰑮" : (root.vpnActive ? "󰄬" : "󰅖")
                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: actionRunner.running && ThemePkg.Theme.edgeAnimationsEnabled
                }
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.vpnActive ? -10 : 12
            text: root.vpnActive ? "ON" : "OFF"
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: 10
            color: root.vpnActive ? root.crust : root.subtext0
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            id: switchMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !actionRunner.running
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.runAction([root.vpnActive ? "--down" : "--up"])
        }
    }

    component ActionButton: Rectangle {
        id: actionBtn
        property string icon: ""
        property string label: ""
        property bool busy: false
        signal activated()
        radius: 12
        color: enabled ? (btnMa.containsMouse ? "#20ffffff" : "#10ffffff") : "#08ffffff"
        border.color: enabled ? (btnMa.containsMouse ? root.accent : "#24ffffff") : "#12ffffff"
        border.width: 1
        opacity: enabled ? 1.0 : 0.45
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        scale: btnMa.pressed && enabled ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        RowLayout {
            anchors.centerIn: parent
            spacing: label === "" ? 0 : 7
            Text {
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 16
                color: btnMa.containsMouse && actionBtn.enabled ? root.accent : root.text
                text: busy ? "󰑮" : icon
                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: busy && ThemePkg.Theme.edgeAnimationsEnabled
                }
            }
            Text {
                visible: label !== ""
                text: label
                font.family: root.textFont
                font.weight: Font.Black
                font.pixelSize: 12
                color: btnMa.containsMouse && actionBtn.enabled ? root.accent : root.text
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: actionBtn.enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: actionBtn.activated()
        }
    }
}
