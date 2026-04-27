import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../theme" as ThemePkg

Scope {
    id: root

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/volume"
    readonly property string textFont: "Fira Sans"

    function reveal() {
        shouldShowOsd = true;
        showPopup();
        hideTimer.restart();
        overlayVolPoller.running = true;
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    property real globalOrbitAngle: 0
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property string triggerPath: Quickshell.env("HOME") + "/.cache/quickshell/volume-overlay.trigger"
    readonly property real audioVolRaw: sinkAudio ? sinkAudio.volume : 0
    property bool audioMuted: false
    property bool shouldShowOsd: false
    property bool popupMounted: false
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: 164
    property real popupCardHeight: 314
    property real popupCardRadius: 36
    property real popupCardLift: 18
    readonly property bool richAnimationsActive: popupMounted && popupTargetVisible && popupCardOpacity > 0.98 && ThemePkg.Theme.edgeAnimationsEnabled


    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: root.richAnimationsActive
    }

    function showPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        if (popupEnterAnim.running)
            return;
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999)
            return;
        popupEnterAnim.start();
    }

    function hidePopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        popupExitAnim.start();
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: {
            root.shouldShowOsd = false;
            root.hidePopup();
        }
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        onStopped: {
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.popupMounted = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 24; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        onStopped: {
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.popupMounted = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 30; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 36; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }

    Process {
        id: overlayVolPoller
        command: ["python3", root.scriptsDir + "/get_audio_state.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    var outputs = data.outputs || [];
                    for (var i = 0; i < outputs.length; i++) {
                        if (outputs[i].is_default) {
                            root.audioMuted = !!outputs[i].mute;
                            break;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: overlayPollTimer
        interval: 100
        running: root.shouldShowOsd
        repeat: true
        triggeredOnStart: true
        onTriggered: overlayVolPoller.running = true
    }

    Connections {
        target: root.sinkAudio
        function onVolumeChanged() { root.reveal() }
        function onMuteChanged() { root.reveal() }
        ignoreUnknownSignals: true
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalShowVolumeOverlay() { root.reveal() }
    }

    FileView {
        id: triggerFile
        path: root.triggerPath
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: {
            this.reload();
            root.reveal();
        }
    }

    LazyLoader {
        active: root.popupMounted

        PanelWindow {
            id: win

            anchors.right: true
            anchors.top: true
            anchors.bottom: true
            exclusiveZone: 0
            color: "transparent"
            mask: Region {}
            margins.right: 14
            implicitWidth: cardShell.width + 20

            readonly property real volRaw: root.audioVolRaw
            readonly property bool muted: root.audioMuted
            readonly property real displayVol: Math.max(0, muted ? 0 : volRaw)
            readonly property real volFrac: Math.max(0, Math.min(1, displayVol))
            readonly property int volumePct: Math.round(displayVol * 100)
            readonly property string stateLabel: muted ? "Muted" : (volumePct === 0 ? "Silent" : (volumePct > 100 ? "Boost" : "Output"))

            readonly property color base: ThemePkg.Theme.surface(0.10)
            readonly property color crust: ThemePkg.Theme.background
            readonly property color text: ThemePkg.Theme.foreground
            readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
            readonly property color blue: ThemePkg.Theme.c4
            readonly property color red: ThemePkg.Theme.danger
            readonly property color tabColor: muted ? red : blue
            readonly property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)

            Item {
                id: cardShell
                width: root.popupCardWidth
                height: root.popupCardHeight
                opacity: root.popupCardOpacity
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                transform: [
                    Scale {
                        origin.x: cardShell.width / 2
                        origin.y: cardShell.height / 2
                        xScale: root.popupCardScaleX
                        yScale: root.popupCardScaleY
                    },
                    Translate { y: root.popupCardLift }
                ]

                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: root.popupCardRadius
                    color: win.base
                    border.color: win.moduleBorderColor
                    border.width: 1
                    clip: true
                    antialiasing: true

                    Rectangle {
                    width: parent.width * 0.82
                    height: width
                    radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 150
                    y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 100
                    color: win.tabColor
                    opacity: 0.06
                    Behavior on color { ColorAnimation { duration: 800 } }
                }

                    Rectangle {
                    width: parent.width * 0.9
                    height: width
                    radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150
                    y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100
                    color: Qt.lighter(win.tabColor, 1.3)
                    opacity: 0.04
                    Behavior on color { ColorAnimation { duration: 800 } }
                }

                    Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    Rectangle {
                        width: 76
                        height: 28
                        radius: 14
                        color: "#0dffffff"
                        border.color: "#1affffff"
                        border.width: 1
                        x: (parent.width - width) / 2

                        Text {
                            anchors.centerIn: parent
                            text: win.stateLabel
                            color: win.subtext0
                            font.family: root.textFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                        Item {
                        width: parent.width
                        height: 112

                        Item {
                            id: orbWrap
                            anchors.centerIn: parent
                            width: 96
                            height: 96

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 14
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: win.tabColor
                                border.width: 3
                                opacity: win.muted ? 0.22 : 0.36
                                scale: 1.0

                                Behavior on border.color { ColorAnimation { duration: 250 } }

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: root.richAnimationsActive
                                    NumberAnimation { to: 1.05; duration: 1600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 30
                                height: width
                                radius: width / 2
                                color: win.tabColor
                                opacity: win.muted ? 0.18 : 0.11
                                z: -1
                                Behavior on color { ColorAnimation { duration: 250 } }

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: root.richAnimationsActive
                                    NumberAnimation { to: 1.08; duration: 2200; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 2200; easing.type: Easing.InOutSine }
                                }
                            }

                            MultiEffect {
                                source: core
                                anchors.fill: core
                                shadowEnabled: true
                                shadowColor: "#000000"
                                shadowOpacity: 0.42
                                shadowBlur: 1.0
                                shadowVerticalOffset: 5
                                z: -1
                            }

                            Rectangle {
                                id: core
                                anchors.fill: parent
                                radius: width / 2
                                color: win.base
                                border.color: win.muted ? win.red : Qt.lighter(win.tabColor, 1.1)
                                border.width: 2
                                clip: true
                                antialiasing: true

                                Behavior on border.color { ColorAnimation { duration: 250 } }

                                Canvas {
                                    id: orbWave
                                    anchors.fill: parent

                                    property real wavePhase: 0.0

                                    NumberAnimation on wavePhase {
                                        running: root.richAnimationsActive && !win.muted && win.volumePct > 0 && win.volumePct < 100
                                        loops: Animation.Infinite
                                        from: 0
                                        to: Math.PI * 2
                                        duration: 1200
                                    }

                                    onWavePhaseChanged: requestPaint()

                                    Connections {
                                        target: win
                                        function onVolumePctChanged() { orbWave.requestPaint() }
                                        function onMutedChanged() { orbWave.requestPaint() }
                                        function onTabColorChanged() { orbWave.requestPaint() }
                                    }

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        if (win.muted || win.volumePct <= 0)
                                            return;

                                        const fillRatio = win.volumePct / 100.0;
                                        const radius = width / 2;
                                        const fillY = height * (1.0 - fillRatio);

                                        ctx.save();
                                        ctx.beginPath();
                                        ctx.arc(radius, radius, radius, 0, 2 * Math.PI);
                                        ctx.clip();

                                        ctx.beginPath();
                                        ctx.moveTo(0, fillY);

                                        if (fillRatio < 0.99) {
                                            const waveAmp = 6 * Math.sin(fillRatio * Math.PI);
                                            const cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                                            const cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                                            ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                                            ctx.lineTo(width, height);
                                            ctx.lineTo(0, height);
                                        } else {
                                            ctx.lineTo(width, 0);
                                            ctx.lineTo(width, height);
                                            ctx.lineTo(0, height);
                                        }

                                        ctx.closePath();

                                        const grad = ctx.createLinearGradient(0, 0, 0, height);
                                        grad.addColorStop(0, Qt.lighter(win.tabColor, 1.15).toString());
                                        grad.addColorStop(1, win.tabColor.toString());
                                        ctx.fillStyle = grad;
                                        ctx.fill();
                                        ctx.restore();
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: win.muted ? "MUTE" : win.volumePct + "%"
                                    color: win.muted ? win.red : win.text
                                    font.family: root.textFont
                                    font.pixelSize: win.muted ? 20 : 28
                                    font.weight: Font.Black
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                Item {
                                    id: waveClipItem
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: parent.height * (win.volumePct / 100.0)
                                    clip: true
                                    visible: !win.muted && win.volumePct > 0

                                    Text {
                                        x: (waveClipItem.width - width) / 2
                                        y: (core.height / 2) - (height / 2) - (core.height - waveClipItem.height)
                                        text: win.volumePct + "%"
                                        color: win.crust
                                        font.family: root.textFont
                                        font.pixelSize: 28
                                        font.weight: Font.Black
                                    }
                                }
                            }
                        }
                    }

                        Item {
                        width: parent.width
                        height: 102

                        Rectangle {
                            id: sliderTrack
                            anchors.centerIn: parent
                            width: 34
                            height: parent.height
                            radius: 17
                            color: "#0dffffff"
                            border.color: "#1affffff"
                            border.width: 1
                            clip: true

                            readonly property int inset: 5
                            readonly property real innerHeight: height - (inset * 2)

                            Rectangle {
                                width: parent.width - (parent.inset * 2)
                                height: parent.innerHeight * win.volFrac
                                radius: width / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.inset
                                opacity: win.muted ? 0.3 : 0.92

                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: Qt.lighter(win.tabColor, 1.2) }
                                    GradientStop { position: 1.0; color: win.tabColor }
                                }

                                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuart } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                        }
                        }
                    }
                }
            }
        }
    }
}
