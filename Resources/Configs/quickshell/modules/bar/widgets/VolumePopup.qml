import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../theme" as ThemePkg

Item {
    id: root
    anchors.fill: parent

    readonly property int panelWidth: 500
    readonly property int panelHeight: 600
    readonly property int panelMargin: 16
    readonly property real popupOpenWidth: root.panelWidth
    readonly property real popupOpenHeight: root.panelHeight
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2
    readonly property int overlayEnterDuration: 515
    readonly property int overlayExitDuration: 375
    readonly property bool overlayOwnsCloseAnimation: true

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

    readonly property color red: ThemePkg.Theme.danger
    readonly property color green: ThemePkg.Theme.success
    readonly property color yellow: ThemePkg.Theme.c3
    readonly property color blue: ThemePkg.Theme.c4
    readonly property color sapphire: ThemePkg.Theme.c4
    readonly property color mauve: ThemePkg.Theme.c5
    readonly property color peach: ThemePkg.Theme.warning
    readonly property color pink: ThemePkg.Theme.c13
    readonly property string textFont: "Fira Sans"

    property color moduleColor: ThemePkg.Theme.surface(0.10)
    property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    property color moduleFontColor: ThemePkg.Theme.accent

    property var overlaySwitcher: null
    readonly property var liveSinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.42
    property real popupCardScaleY: 0.24
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: popupOriginLift()
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/volume"

    property string activeTab: "outputs" 
    onActiveTabChanged: updateHeroData()

    readonly property color tabColor: {
        if (activeTab === "outputs") return root.blue;
        if (activeTab === "inputs") return root.mauve;
        return root.green;
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    property string activeId: ""
    property string activeName: "No Device"
    property string activeDesc: ""
    property string activePipewireId: ""
    property string activePipewireName: ""
    property int activeVol: 0
    property real activeVolVisual: 0
    property bool activeMute: false
    property string activeIcon: "󰓃"
    readonly property string activeBackgroundIcon: {
        const iconName = String(root.activeIcon || "").toLowerCase();
        const desc = String(root.activeName || "").toLowerCase();
        if (root.activeTab === "inputs") return "󰍬";
        if (root.activeTab === "apps") return "󰎆";
        if (desc.indexOf("headset") !== -1 || desc.indexOf("headphones") !== -1 || iconName.indexOf("headset") !== -1 || iconName.indexOf("headphone") !== -1)
            return "󰋎";
        if (iconName.indexOf("microphone") !== -1 || iconName.indexOf("audio-input-microphone") !== -1)
            return "󰍬";
        if (iconName.indexOf("application") !== -1 || iconName.indexOf("stream") !== -1)
            return "󰎆";
        return "󰓃";
    }
    readonly property real activeFillRatio: Math.max(0, Math.min(1, root.activeVolVisual / 100.0))
    readonly property int activeVolLabel: Math.max(0, Math.round(root.activeVolVisual))
    readonly property var activePipewireNode: root.findPipewireNode(root.activeDesc, root.activeName, root.activePipewireId, root.activePipewireName)
    readonly property real activePeakLevel: activePeakMonitor.enabled ? Math.max(0, Math.min(1, activePeakMonitor.peak * 1.8)) : 0
    property real activePeakVisual: 0
    property real meterGlowPhase: 0
    onActiveVolChanged: activeVolVisual = activeVol
    onActivePeakLevelChanged: activePeakVisual = activePeakLevel
    Behavior on activeVolVisual { NumberAnimation { duration: root.draggingMaster ? 80 : 150; easing.type: Easing.OutQuart } }
    Behavior on activePeakVisual { NumberAnimation { duration: root.activePeakLevel > root.activePeakVisual ? 70 : 260; easing.type: Easing.OutCubic } }

    NumberAnimation on meterGlowPhase {
        from: 0; to: 1; duration: 850; loops: Animation.Infinite; running: true
    }

    ListModel { id: outputsModel }
    ListModel { id: inputsModel }
    ListModel { id: appsModel }

    property var draggingNodes: ({})
    property bool draggingMaster: false
    Timer { id: syncDelay; interval: 600; onTriggered: { root.draggingNodes = ({}); root.draggingMaster = false; } }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource, root.activePipewireNode] }

    PwNodePeakMonitor {
        id: activePeakMonitor
        node: root.activePipewireNode
        enabled: root.popupTargetVisible && root.activePipewireNode !== null && !root.activeMute
    }

    function nodeProp(node, key) {
        if (!node || !node.properties)
            return "";
        let value = node.properties[key];
        if (value === undefined || value === null)
            return "";
        return String(value);
    }

    function findPipewireNode(nodeName, nodeDescription, pipewireId, pipewireName) {
        let nodes = (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : [];
        let wantedId = String(pipewireId || "");

        if (wantedId.length > 0) {
            for (let i = 0; i < nodes.length; i++) {
                let n = nodes[i];
                if (!n)
                    continue;
                if (String(n.id) === wantedId || nodeProp(n, "object.id") === wantedId || nodeProp(n, "object.serial") === wantedId)
                    return n;
            }
        }

        let names = [pipewireName, nodeName, nodeDescription].map(v => String(v || "")).filter(v => v.length > 0);
        for (let i = 0; i < nodes.length; i++) {
            let n = nodes[i];
            if (!n)
                continue;

            let candidates = [
                String(n.name || ""),
                String(n.description || ""),
                nodeProp(n, "node.name"),
                nodeProp(n, "media.name"),
                nodeProp(n, "application.name")
            ];

            for (let c = 0; c < candidates.length; c++) {
                if (candidates[c].length > 0 && names.indexOf(candidates[c]) !== -1)
                    return n;
            }
        }

        return null;
    }

    function processAudioJson(textData) {
        if (!textData) return;
        try {
            let data = JSON.parse(textData);
            syncModel(outputsModel, data.outputs || []);
            syncModel(inputsModel, data.inputs || []);
            syncModel(appsModel, data.apps || []);
            updateHeroData();
        } catch(e) {}
    }

    function updateHeroData() {
        let targetModel = (root.activeTab === "inputs") ? inputsModel : outputsModel;

        let foundDefault = false;

        for (let i = 0; i < targetModel.count; i++) {
            let d = targetModel.get(i);
            if (d.is_default) {
                root.activeId = d.id;
                root.activeName = d.description;
                root.activeDesc = d.name;
                root.activeIcon = d.icon;
                root.activePipewireId = d.pipewire_id || "";
                root.activePipewireName = d.pipewire_name || "";
                if (!root.draggingMaster) {
                    root.activeVol = d.volume;
                    root.activeMute = d.mute;
                }
                foundDefault = true;
                break;
            }
        }

        if (!foundDefault && targetModel.count > 0) {
            let d = targetModel.get(0);
            root.activeId = d.id;
            root.activeName = d.description;
            root.activeDesc = d.name;
            root.activeIcon = d.icon;
            root.activePipewireId = d.pipewire_id || "";
            root.activePipewireName = d.pipewire_name || "";
            if (!root.draggingMaster) {
                root.activeVol = d.volume;
                root.activeMute = d.mute;
            }
        }
    }

    function syncLiveOutputState() {
        if (root.activeTab !== "outputs" || root.draggingMaster || !root.liveSinkAudio)
            return;

        root.activeVol = Math.max(0, Math.round(root.liveSinkAudio.volume * 100));
        root.activeMute = !!root.liveSinkAudio.mute;
    }

    function syncModel(listModel, dataArray) {
        for (let i = listModel.count - 1; i >= 0; i--) {
            let id = listModel.get(i).id;
            let found = false;
            for (let j = 0; j < dataArray.length; j++) {
                if (id === dataArray[j].id) { found = true; break; }
            }
            if (!found) listModel.remove(i);
        }

        for (let i = 0; i < dataArray.length; i++) {
            let d = dataArray[i];
            let foundIdx = -1;
            for (let j = i; j < listModel.count; j++) {
                if (listModel.get(j).id === d.id) { foundIdx = j; break; }
            }

            let obj = {
                id: d.id, name: d.name, description: d.description,
                volume: d.volume, mute: d.mute, is_default: d.is_default, icon: d.icon,
                pipewire_id: d.pipewire_id || "", pipewire_name: d.pipewire_name || ""
            };

            if (foundIdx === -1) {
                listModel.insert(i, obj);
            } else {
                if (foundIdx !== i) listModel.move(foundIdx, i, 1);
                for (let key in obj) {
                    if (key === "volume" && root.draggingNodes[obj.id]) continue;
                    if (listModel.get(i)[key] !== obj[key]) {
                        listModel.setProperty(i, key, obj[key]);
                    }
                }
            }
        }
    }

    Process {
        id: audioPoller
        command: ["python3", root.scriptsDir + "/get_audio_state.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                processAudioJson(this.text.trim());
            }
        }
    }

    Timer {
        interval: 100; running: true; repeat: true; triggeredOnStart: true;
        onTriggered: audioPoller.running = true
    }

    onLiveSinkAudioChanged: syncLiveOutputState()

    Connections {
        target: root.liveSinkAudio
        function onVolumeChanged() { root.syncLiveOutputState() }
        function onMuteChanged() { root.syncLiveOutputState() }
        ignoreUnknownSignals: true
    }

    property real introMain: 0
    property real introHeader: 0
    property real introContent: 0

    Component.onCompleted: {
        popupTargetVisible = true;
        startupAnim.start();
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

    ParallelAnimation {
        id: startupAnim
        running: false
        NumberAnimation { target: root; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: root; property: "introHeader"; from: 0; to: 1.0; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: root; property: "introContent"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        }
    }

    function popupOriginLift() {
        return root.barPanelCenterY - (root.popupClosedHeight / 2);
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth - 18; duration: 285; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 18; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 270; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 300; easing.type: Easing.OutCubic }
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
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: root.popupOriginLift(); duration: 280; easing.type: Easing.InCubic }
        }
    }

    Rectangle {
        id: volumePanel
        width: root.popupCardWidth
        height: root.popupCardHeight
        radius: root.popupCardRadius
        opacity: root.popupCardOpacity
        color: "transparent"
        border.color: "transparent"
        border.width: 0
        anchors {
            top: parent.top
            right: parent.right
            topMargin: root.popupCardLift
            rightMargin: root.panelMargin
        }

        transform: Scale {
            origin.x: volumePanel.width / 2
            origin.y: volumePanel.height / 2
            xScale: root.popupCardScaleX
            yScale: root.popupCardScaleY
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        Item {
            anchors.fill: parent
            scale: 0.95 + (0.05 * root.introMain)
            opacity: root.introMain
            transform: Translate { y: 20 * (1 - root.introMain) }

            Rectangle {
                anchors.fill: parent
                radius: volumePanel.radius
                color: root.base
                border.color: root.moduleBorderColor
                border.width: 1
                clip: true

                AnimatedBorder {
                    anchors.fill: parent
                    radius: parent.radius
                    borderWidth: parent.border.width
                    accentColor: root.tabColor
                }

                Rectangle {
                    width: parent.width * 0.8; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 150
                    y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 100
                    opacity: 0.06
                    color: root.tabColor
                    Behavior on color { ColorAnimation { duration: 800 } }
                }
                Rectangle {
                    width: parent.width * 0.9; height: width; radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150
                    y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100
                    opacity: 0.04
                    color: Qt.lighter(root.tabColor, 1.3)
                    Behavior on color { ColorAnimation { duration: 800 } }
                }

                Text {
                    id: parallaxVolumeIcon
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -30
                    text: root.activeBackgroundIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 360
                    color: root.tabColor
                    opacity: 0.03 + (0.01 * Math.sin(root.globalOrbitAngle * 4))
                    z: 0

                    Behavior on color { ColorAnimation { duration: 800 } }

                    property real drift: 0
                    SequentialAnimation on drift {
                        loops: Animation.Infinite
                        NumberAnimation { to: -10; duration: 6000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                    }

                    transform: Translate { y: parallaxVolumeIcon.drift }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 20

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        opacity: root.introHeader
                        transform: Translate { y: 30 * (1.0 - root.introHeader) }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 25

                            Item {
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 130
                                scale: masterOrbMa.pressed ? 0.95 : (masterOrbMa.containsMouse ? 1.05 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 15
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: root.activeMute ? root.red : root.tabColor
                                    border.width: 3
                                    z: -2

                                    property real pulseOp: 0.0
                                    property real pulseSc: 1.0
                                    opacity: root.activeMute ? 0.0 : pulseOp
                                    scale: pulseSc

                                    Timer {
                                        interval: 45
                                        running: parent.opacity > 0.01 || !root.activeMute
                                        repeat: true
                                        onTriggered: {
                                            var time = Date.now() / 1000;
                                            parent.pulseOp = 0.3 + Math.sin(time * 2.5) * 0.15;
                                            parent.pulseSc = 1.02 + Math.cos(time * 3.0) * 0.02;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 40
                                    height: width
                                    radius: width / 2
                                    color: root.activeMute ? root.red : root.tabColor
                                    opacity: root.activeMute ? 0.3 : 0.15
                                    z: -1
                                    Behavior on color { ColorAnimation { duration: 300 } }

                                    SequentialAnimation on scale {
                                        loops: Animation.Infinite; running: true
                                        NumberAnimation { to: masterOrbMa.containsMouse ? 1.15 : 1.1; duration: masterOrbMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: masterOrbMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                    }
                                }

                                MultiEffect {
                                    source: centralCore
                                    anchors.fill: centralCore
                                    shadowEnabled: true
                                    shadowColor: "#000000"
                                    shadowOpacity: 0.5
                                    shadowBlur: 1.2
                                    shadowVerticalOffset: 6
                                    z: -1
                                }

                                Rectangle {
                                    id: centralCore
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: root.base
                                    border.color: root.activeMute ? root.red : Qt.lighter(root.tabColor, 1.1)
                                    border.width: 2
                                    clip: true
                                    Behavior on border.color { ColorAnimation { duration: 300 } }

                                    Canvas {
                                        id: orbWave
                                        anchors.fill: parent

                                        property real wavePhase: 0.0
                                        NumberAnimation on wavePhase {
                                            running: root.activeFillRatio > 0 && root.activeFillRatio < 0.99
                                            loops: Animation.Infinite
                                            from: 0; to: Math.PI * 2; duration: 1200
                                        }
                                        onWavePhaseChanged: requestPaint()

                                        Connections {
                                            target: root
                                            function onActiveVolChanged() { orbWave.requestPaint() }
                                            function onActiveVolVisualChanged() { orbWave.requestPaint() }
                                            function onActiveMuteChanged() { orbWave.requestPaint() }
                                            function onTabColorChanged() { orbWave.requestPaint() }
                                        }

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            if (root.activeFillRatio <= 0) return;

                                            var fillRatio = root.activeFillRatio;
                                            var r = width / 2;
                                            var fillY = height * (1.0 - fillRatio);

                                            ctx.save();

                                            ctx.beginPath();
                                            ctx.arc(r, r, r, 0, 2 * Math.PI);
                                            ctx.clip();

                                            ctx.beginPath();
                                            ctx.moveTo(0, fillY);

                                            if (fillRatio < 0.99) {
                                                var waveAmp = 8 * Math.sin(fillRatio * Math.PI);
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

                                            if (root.activeMute) {
                                                grad.addColorStop(0, Qt.lighter(root.red, 1.15).toString());
                                                grad.addColorStop(1, root.red.toString());
                                            } else {
                                                grad.addColorStop(0, Qt.lighter(root.tabColor, 1.15).toString());
                                                grad.addColorStop(1, root.tabColor.toString());
                                            }
                                            ctx.fillStyle = grad;
                                            ctx.globalAlpha = 1.0;
                                            ctx.fill();
                                            ctx.restore();
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.textFont
                                        font.weight: Font.Black
                                        font.pixelSize: 32
                                        color: root.activeMute ? root.red : root.text
                                        text: root.activeMute ? "MUTE" : root.activeVolLabel + "%"
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    Item {
                                        id: waveClipItem
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right

                                        property real fillRatio: root.activeFillRatio
                                        property real waveAmp: fillRatio < 0.99 ? 8 * Math.sin(fillRatio * Math.PI) : 0
                                        property real waveCenterOffset: 0.375 * waveAmp * (Math.sin(orbWave.wavePhase) - Math.cos(orbWave.wavePhase))
                                        property real baseClipHeight: parent.height * fillRatio

                                        height: Math.min(parent.height, Math.max(0, baseClipHeight - waveCenterOffset))
                                        clip: true
                                        visible: root.activeFillRatio > 0

                                        Text {
                                            x: waveClipItem.width / 2 - width / 2
                                            y: (centralCore.height / 2) - (height / 2) - (centralCore.height - waveClipItem.height)
                                            font.family: root.textFont
                                            font.weight: Font.Black
                                            font.pixelSize: 32
                                            color: root.crust
                                            text: root.activeMute ? "MUTE" : root.activeVolLabel + "%"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: masterOrbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let type = root.activeTab === "inputs" ? "source" : "sink";
                                        Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "toggle-mute", type, root.activeId]);
                                        audioPoller.running = true;
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 10

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                        font.family: root.textFont; font.weight: Font.Black; font.pixelSize: 20
                                        color: root.text
                                        text: root.activeName
                                    }
                                    Text {
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                        font.family: root.textFont; font.pixelSize: 13
                                        color: root.subtext0
                                        text: root.activeTab === "apps" ? "Master Output Volume" : root.activeDesc
                                    }
                                }

                                Item { Layout.fillHeight: true } 

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: activeMuteMa.containsMouse ? "#1affffff" : "transparent"
                                        border.color: activeMuteMa.containsMouse ? (root.activeMute ? root.overlay0 : root.tabColor) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: "CaskaydiaMono Nerd Font"
                                            font.pixelSize: 18
                                            color: root.activeMute ? root.overlay0 : root.subtext0
                                            text: root.activeMute || root.activeVol === 0 ? "󰖁" : (root.activeVol > 50 ? "󰕾" : "󰖀")
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }

                                        MouseArea {
                                            id: activeMuteMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let type = root.activeTab === "inputs" ? "source" : "sink";
                                                Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "toggle-mute", type, root.activeId]);
                                                audioPoller.running = true;
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 24

                                        Timer {
                                            id: masterCmdThrottle
                                            interval: 50
                                            property int targetPct: -1
                                            onTriggered: {
                                                if (targetPct >= 0) {
                                                    let type = root.activeTab === "inputs" ? "source" : "sink";
                                                    if (targetPct > 0 && root.activeMute) {
                                                        Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "toggle-mute", type, root.activeId]);
                                                    }
                                                    Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "set-volume", type, root.activeId, targetPct]);
                                                    targetPct = -1;
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: masterTrack
                                            anchors.fill: parent; radius: 12
                                            color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                                            clip: true

                                            Rectangle {
                                                height: parent.height
                                                width: parent.width * root.activeFillRatio
                                                radius: 12
                                                opacity: root.activeMute ? 0.3 : (masterSliderMa.containsMouse ? 1.0 : 0.85)
                                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                                Behavior on width { enabled: !root.draggingMaster; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0.0; color: root.activeMute ? root.surface2 : root.tabColor; Behavior on color { ColorAnimation{duration: 300} } }
                                                    GradientStop { position: 1.0; color: root.activeMute ? Qt.lighter(root.surface2, 1.15) : Qt.lighter(root.tabColor, 1.25); Behavior on color { ColorAnimation{duration: 300} } }
                                                }
                                            }

                                            Item {
                                                anchors.fill: parent
                                                clip: true
                                                visible: !root.activeMute && root.activePeakVisual > 0.01

                                                Rectangle {
                                                    id: masterPeakMeter
                                                    height: parent.height
                                                    width: parent.width * root.activePeakVisual
                                                    radius: 12
                                                    opacity: Math.min(1.0, 0.55 + root.activePeakVisual * 0.35)
                                                    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                                                        GradientStop { position: 0.62; color: Qt.rgba(1, 1, 1, 0.18 + root.activePeakVisual * 0.12) }
                                                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.46 + root.activePeakVisual * 0.24) }
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: parent.radius
                                                        opacity: 0.34
                                                        gradient: Gradient {
                                                            orientation: Gradient.Vertical
                                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                            GradientStop { position: 0.52; color: Qt.rgba(1, 1, 1, 0.18) }
                                                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: Math.max(22, masterTrack.width * 0.16)
                                                        height: parent.height
                                                        radius: parent.radius
                                                        x: (masterPeakMeter.width + width) * root.meterGlowPhase - width
                                                        opacity: 0.18 + root.activePeakVisual * 0.22
                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.65) }
                                                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 4
                                                        height: parent.height
                                                        radius: 2
                                                        anchors.right: parent.right
                                                        color: Qt.rgba(1, 1, 1, 0.9)
                                                        opacity: 0.55 + root.activePeakVisual * 0.35
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: masterSliderMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor

                                            onPressed: (mouse) => { syncDelay.stop(); root.draggingMaster = true; updateVol(mouse.x); }
                                            onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x); }
                                            onReleased: { syncDelay.restart(); audioPoller.running = true; }

                                            function updateVol(mx) {
                                                let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                                root.activeVol = pct;

                                                masterCmdThrottle.targetPct = pct;
                                                if (!masterCmdThrottle.running) masterCmdThrottle.start();
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        color: musicBtnMa.containsMouse ? "#1affffff" : "#0dffffff"
                                        border.color: musicBtnMa.containsMouse ? root.mauve : "#1affffff"
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰎆"
                                            color: musicBtnMa.containsMouse ? root.mauve : root.subtext0
                                            font.family: "CaskaydiaMono Nerd Font"
                                            font.pixelSize: 18
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        MouseArea {
                                            id: musicBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.overlaySwitcher) root.overlaySwitcher.close();
                                                Quickshell.execDetached(["bash", "-c", "sleep 0.15 && qs ipc call music toggle"]);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: 14
                        color: "#0dffffff"
                        border.color: "#1affffff"
                        border.width: 1
                        opacity: root.introHeader
                        transform: Translate { y: 20 * (1.0 - root.introHeader) }

                        Rectangle {
                            width: (parent.width - 2) / 3
                            height: parent.height - 2
                            y: 1
                            radius: 10
                            x: {
                                if (root.activeTab === "outputs") return 1;
                                if (root.activeTab === "inputs") return width + 1;
                                return (width * 2) + 1;
                            }
                            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.tabColor; Behavior on color { ColorAnimation { duration: 400 } } }
                                GradientStop { position: 1.0; color: Qt.lighter(root.tabColor, 1.15); Behavior on color { ColorAnimation { duration: 400 } } }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: ListModel {
                                    ListElement { tabId: "outputs"; icon: "󰓃"; label: "Outputs" }
                                    ListElement { tabId: "inputs"; icon: "󰍬"; label: "Inputs" }
                                    ListElement { tabId: "apps"; icon: "󰎆"; label: "Streams" }
                                }

                                delegate: Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 18
                                            color: root.activeTab === tabId ? root.crust : (tabMa.containsMouse ? root.text : root.subtext0)
                                            text: icon
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                        Text {
                                            font.family: root.textFont; font.weight: Font.Black; font.pixelSize: 13
                                            color: root.activeTab === tabId ? root.crust : (tabMa.containsMouse ? root.text : root.subtext0)
                                            text: label
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeTab = tabId;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        opacity: root.introContent
                        transform: Translate { y: 20 * (1.0 - root.introContent) }

                        ListView {
                            id: contentList
                            anchors.fill: parent
                            spacing: 12
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ThemePkg.FastScrollHandler {
                                anchors.fill: parent
                                flickable: contentList
                            }

                            ScrollBar.vertical: ScrollBar {
                                id: vbar
                                policy: contentList.count > 2 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                hoverEnabled: true
                                implicitWidth: 10
                                minimumSize: 0.08
                                active: hovered || pressed || contentList.moving

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
                                    color: root.moduleFontColor
                                }
                            }

                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutQuint }
                                NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 400; easing.type: Easing.OutBack }
                            }
                            displaced: Transition {
                                SpringAnimation { property: "y"; spring: 3; damping: 0.2; mass: 0.2 }
                            }

                            model: {
                                if (root.activeTab === "outputs") return outputsModel;
                                if (root.activeTab === "inputs") return inputsModel;
                                return appsModel;
                            }

                            Item {
                                width: contentList.width; height: contentList.height
                                visible: contentList.count === 0
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Text { Layout.alignment: Qt.AlignHCenter; font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 32; color: root.surface2; text: "󰖁" }
                                    Text { Layout.alignment: Qt.AlignHCenter; font.family: root.textFont; font.pixelSize: 14; color: root.overlay0; text: "No active streams" }
                                }
                            }

                            delegate: Rectangle {
                                id: delegateRoot
                                width: contentList.width - (vbar.visible ? vbar.width + 4 : 0)
                                property var pipewireNode: root.findPipewireNode(model.name, model.description, model.pipewire_id || "", model.pipewire_name || "")
                                property real peakLevel: nodePeakMonitor.enabled ? Math.max(0, Math.min(1, nodePeakMonitor.peak * 1.8)) : 0
                                property real peakVisual: 0
                                onPeakLevelChanged: peakVisual = peakLevel
                                Behavior on peakVisual { NumberAnimation { duration: delegateRoot.peakLevel > delegateRoot.peakVisual ? 70 : 260; easing.type: Easing.OutCubic } }

                                PwNodePeakMonitor {
                                    id: nodePeakMonitor
                                    node: delegateRoot.pipewireNode
                                    enabled: root.popupTargetVisible && delegateRoot.pipewireNode !== null && !model.mute && !delegateRoot.isActiveNode
                                }

                                property bool isLoaded: false
                                Timer {
                                    running: true
                                    interval: 40 + (index * 40)
                                    onTriggered: delegateRoot.isLoaded = true
                                }

                                opacity: isLoaded ? 1.0 : 0.0
                                transform: Translate { y: isLoaded ? 0 : 15 }
                                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                property bool isActiveNode: model.is_default && root.activeTab !== "apps"
                                height: isActiveNode ? 60 : 100
                                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                radius: 14

                                property bool isHovered: cardMa.containsMouse && !isActiveNode

                                color: isActiveNode ? root.tabColor : (isHovered ? "#0affffff" : "#05ffffff")
                                border.color: isActiveNode ? root.tabColor : "#1affffff"

                                border.width: isActiveNode ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration: 300 } }
                                Behavior on color { ColorAnimation { duration: 300 } }

                                MouseArea {
                                    id: cardMa
                                    anchors.fill: parent
                                    hoverEnabled: root.activeTab !== "apps"
                                    cursorShape: root.activeTab !== "apps" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (root.activeTab !== "apps" && !model.is_default) {
                                            let type = root.activeTab === "outputs" ? "sink" : "source";
                                            Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "set-default", type, model.name]);
                                            audioPoller.running = true;
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 12
                                    anchors.bottomMargin: isActiveNode ? 12 : 16
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Text {
                                            font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 22
                                            color: isActiveNode ? root.crust : root.text
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                            text: {
                                                if (root.activeTab === "inputs") return "󰍬";
                                                if (root.activeTab === "apps") return "󰎆";
                                                if (model.description.toLowerCase().indexOf("headset") !== -1 || model.description.toLowerCase().indexOf("headphones") !== -1) return "󰋎";
                                                return "󰓃";
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                                font.family: root.textFont; font.weight: Font.Bold; font.pixelSize: 14
                                                color: isActiveNode ? root.crust : root.text
                                                text: model.description
                                            }
                                            Text {
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                                font.family: root.textFont; font.pixelSize: 11
                                                color: isActiveNode ? Qt.darker(root.crust, 1.5) : root.subtext0
                                                text: isActiveNode ? "Active Default" : model.name
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15
                                        visible: !isActiveNode
                                        opacity: isActiveNode ? 0.0 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }

                                        Rectangle {
                                            Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                                            color: muteMa.containsMouse ? "#1affffff" : "transparent"
                                            border.color: muteMa.containsMouse ? (model.mute ? root.overlay0 : root.tabColor) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 18
                                                color: model.mute ? root.overlay0 : root.subtext0
                                                text: model.mute || model.volume === 0 ? "󰖁" : (model.volume > 50 ? "󰕾" : "󰖀")
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                            MouseArea {
                                                id: muteMa
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    let type = "sink";
                                                    if (root.activeTab === "inputs") type = "source";
                                                    if (root.activeTab === "apps") type = "sink-input";
                                                    Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "toggle-mute", type, model.id]);
                                                    audioPoller.running = true;
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            height: 14

                                            Timer {
                                                id: volCmdThrottle
                                                interval: 50
                                                property int targetPct: -1
                                                onTriggered: {
                                                    if (targetPct >= 0) {
                                                        let type = "sink";
                                                        if (root.activeTab === "inputs") type = "source";
                                                        if (root.activeTab === "apps") type = "sink-input";

                                                        if (targetPct > 0 && model.mute) {
                                                            Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "toggle-mute", type, model.id]);
                                                        }
                                                        Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh", "set-volume", type, model.id, targetPct]);
                                                        targetPct = -1;
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: nodeTrack
                                                anchors.fill: parent; radius: 7
                                                color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                                                clip: true

                                                Rectangle {
                                                    height: parent.height
                                                    width: parent.width * (Math.min(100, model.volume) / 100)
                                                    radius: 7
                                                    opacity: model.mute ? 0.3 : (volSliderMa.containsMouse ? 0.7 : 0.4)
                                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                                    Behavior on width { enabled: !root.draggingNodes[model.id]; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: model.mute ? root.surface2 : root.tabColor; Behavior on color { ColorAnimation { duration: 300 } } }
                                                        GradientStop { position: 1.0; color: model.mute ? Qt.lighter(root.surface2, 1.15) : Qt.lighter(root.tabColor, 1.25); Behavior on color { ColorAnimation { duration: 300 } } }
                                                    }
                                                }

                                                Item {
                                                    anchors.fill: parent
                                                    clip: true
                                                    visible: !model.mute && delegateRoot.peakVisual > 0.01

                                                    Rectangle {
                                                        id: nodePeakMeter
                                                        height: parent.height
                                                        width: parent.width * delegateRoot.peakVisual
                                                        radius: 7
                                                        opacity: Math.min(1.0, 0.52 + delegateRoot.peakVisual * 0.34)
                                                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                                                            GradientStop { position: 0.62; color: Qt.rgba(1, 1, 1, 0.18 + delegateRoot.peakVisual * 0.12) }
                                                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.46 + delegateRoot.peakVisual * 0.22) }
                                                        }

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: parent.radius
                                                            opacity: 0.3
                                                            gradient: Gradient {
                                                                orientation: Gradient.Vertical
                                                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                                GradientStop { position: 0.52; color: Qt.rgba(1, 1, 1, 0.18) }
                                                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                            }
                                                        }

                                                        Rectangle {
                                                            width: Math.max(16, nodeTrack.width * 0.14)
                                                            height: parent.height
                                                            radius: parent.radius
                                                            x: (nodePeakMeter.width + width) * root.meterGlowPhase - width
                                                            opacity: 0.16 + delegateRoot.peakVisual * 0.2
                                                            gradient: Gradient {
                                                                orientation: Gradient.Horizontal
                                                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.62) }
                                                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                                            }
                                                        }

                                                        Rectangle {
                                                            width: 3
                                                            height: parent.height
                                                            radius: 1.5
                                                            anchors.right: parent.right
                                                            color: Qt.rgba(1, 1, 1, 0.9)
                                                            opacity: 0.5 + delegateRoot.peakVisual * 0.35
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: volSliderMa
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { syncDelay.stop(); root.draggingNodes[model.id] = true; updateVol(mouse.x); }
                                                onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x); }
                                                onReleased: { syncDelay.restart(); audioPoller.running = true; }

                                                function updateVol(mx) {
                                                    let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));

                                                    let targetList = root.activeTab === "outputs" ? outputsModel : (root.activeTab === "inputs" ? inputsModel : appsModel);
                                                    for (let i = 0; i < targetList.count; i++) {
                                                        if (targetList.get(i).id === model.id) {
                                                            targetList.setProperty(i, "volume", pct);
                                                            break;
                                                        }
                                                    }

                                                    volCmdThrottle.targetPct = pct;
                                                    if (!volCmdThrottle.running) volCmdThrottle.start();
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth: 35
                                            font.family: root.textFont; font.weight: Font.Bold; font.pixelSize: 12
                                            color: root.subtext0
                                            text: model.volume + "%"
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
