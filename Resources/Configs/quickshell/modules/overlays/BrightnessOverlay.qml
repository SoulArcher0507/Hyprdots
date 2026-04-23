import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../theme" as ThemePkg

Scope {
    id: root
    readonly property string textFont: "Fira Sans"

    readonly property string triggerPath: Quickshell.env("HOME") + "/.cache/quickshell/brightness-overlay.trigger"
    property real globalOrbitAngle: 0
    property bool shouldShowOsd: false
    property bool hasBrightnessSample: false
    property bool lastBrightnessAvailable: false
    property int lastBrightnessPct: 0
    property bool popupMounted: false
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: 146
    property real popupCardHeight: 258
    property real popupCardRadius: 36
    property real popupCardLift: 18
    property var brightnessState: ({
            available: false,
            percent: 0,
            icon: "󰃞",
            label: "No Device"
        })

    function clampPct(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
    }

    function iconFor(pct) {
        if (pct > 66)
            return "󰃠";
        if (pct > 33)
            return "󰃟";
        return "󰃞";
    }

    function labelFor(pct, available) {
        if (!available)
            return "No Device";
        if (pct === 0)
            return "Dark";
        if (pct < 34)
            return "Dim";
        if (pct < 80)
            return "Glow";
        return "Bright";
    }

    function setBrightnessState(available, pct, icon, label) {
        const safePct = clampPct(pct);
        brightnessState = {
            available: !!available,
            percent: safePct,
            icon: icon || iconFor(safePct),
            label: label || labelFor(safePct, !!available)
        };
    }

    function refreshBrightness() {
        brightnessPoller.running = true;
    }

    function revealWithRefresh() {
        reveal();
        refreshBrightness();
    }

    function applyBrightnessSample(text) {
        const pctText = (text || "").trim();
        const available = pctText !== "";
        const pct = available ? clampPct(pctText) : 0;
        const changed = hasBrightnessSample && (available !== lastBrightnessAvailable || pct !== lastBrightnessPct);

        hasBrightnessSample = true;
        lastBrightnessAvailable = available;
        lastBrightnessPct = pct;
        setBrightnessState(available, pct, "", "");

        if (changed)
            reveal();
    }

    function reveal() {
        shouldShowOsd = true;
        showPopup();
        hideTimer.restart();
    }

    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: root.popupMounted
    }

    function showPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999)
            return;
        popupEnterAnim.stop();
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
            NumberAnimation { target: root; property: "popupCardWidth"; to: 158; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: 292; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: 164; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: 314; duration: 215; easing.type: Easing.OutCubic }
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
            NumberAnimation { target: root; property: "popupCardWidth"; to: 172; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardHeight"; to: 300; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 30; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: 146; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: 258; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 36; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }

    Process {
        id: brightnessPoller
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/, \"\", $4); print int($4)}'"]
        stdout: StdioCollector {
            onStreamFinished: root.applyBrightnessSample(this.text)
        }
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalShowBrightnessOverlay() { root.revealWithRefresh() }
    }

    FileView {
        id: triggerFile
        path: root.triggerPath
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: {
            this.reload();
            root.revealWithRefresh();
        }
    }

    Timer {
        id: overlayPollTimer
        interval: 100
        running: root.shouldShowOsd
        repeat: true
        triggeredOnStart: true
        onTriggered: brightnessPoller.running = true
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

            readonly property bool available: !!root.brightnessState.available
            readonly property int brightnessPct: root.clampPct(root.brightnessState.percent)
            readonly property real brightnessFrac: brightnessPct / 100.0
            readonly property string brightnessIcon: root.brightnessState.icon || root.iconFor(brightnessPct)
            readonly property string stateLabel: root.brightnessState.label || root.labelFor(brightnessPct, available)

            readonly property color base: ThemePkg.Theme.surface(0.10)
            readonly property color crust: ThemePkg.Theme.background
            readonly property color text: ThemePkg.Theme.foreground
            readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
            readonly property color gold: ThemePkg.Theme.warning
            readonly property color yellow: ThemePkg.Theme.c3
            readonly property color tabColor: available ? gold : ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
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
                    opacity: 0.07
                    Behavior on color { ColorAnimation { duration: 800 } }
                }

                    Rectangle {
                    width: parent.width * 0.9
                    height: width
                    radius: width / 2
                    x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150
                    y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100
                    color: Qt.lighter(win.yellow, 1.2)
                    opacity: 0.05
                    Behavior on color { ColorAnimation { duration: 800 } }
                }

                    Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    Rectangle {
                        width: 88
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
                                opacity: win.available ? 0.36 : 0.2
                                scale: 1.0

                                Behavior on border.color { ColorAnimation { duration: 250 } }

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: true
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
                                opacity: win.available ? 0.13 : 0.08
                                z: -1
                                Behavior on color { ColorAnimation { duration: 250 } }

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: true
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
                                border.color: Qt.lighter(win.tabColor, 1.1)
                                border.width: 2
                                clip: true
                                antialiasing: true

                                Behavior on border.color { ColorAnimation { duration: 250 } }

                                Canvas {
                                    id: orbWave
                                    anchors.fill: parent

                                    property real wavePhase: 0.0

                                    NumberAnimation on wavePhase {
                                        running: win.available && win.brightnessPct > 0 && win.brightnessPct < 100
                                        loops: Animation.Infinite
                                        from: 0
                                        to: Math.PI * 2
                                        duration: 1400
                                    }

                                    onWavePhaseChanged: requestPaint()

                                    Connections {
                                        target: win
                                        function onBrightnessPctChanged() { orbWave.requestPaint() }
                                        function onAvailableChanged() { orbWave.requestPaint() }
                                        function onTabColorChanged() { orbWave.requestPaint() }
                                    }

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        if (!win.available || win.brightnessPct <= 0)
                                            return;

                                        const fillRatio = win.brightnessFrac;
                                        const radius = width / 2;
                                        const fillY = height * (1.0 - fillRatio);

                                        ctx.save();
                                        ctx.beginPath();
                                        ctx.arc(radius, radius, radius, 0, 2 * Math.PI);
                                        ctx.clip();

                                        ctx.beginPath();
                                        ctx.moveTo(0, fillY);

                                        if (fillRatio < 0.99) {
                                            const waveAmp = 5 * Math.sin(fillRatio * Math.PI);
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
                                        grad.addColorStop(0, Qt.lighter(win.yellow, 1.15).toString());
                                        grad.addColorStop(1, win.gold.toString());
                                        ctx.fillStyle = grad;
                                        ctx.fill();
                                        ctx.restore();
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 16
                                    text: win.brightnessIcon
                                    color: Qt.lighter(win.tabColor, 1.08)
                                    font.family: "CaskaydiaMono Nerd Font"
                                    font.pixelSize: 18
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 46
                                    text: win.available ? (win.brightnessPct + "%") : "--"
                                    color: win.available ? win.text : win.subtext0
                                    font.family: root.textFont
                                    font.pixelSize: 24
                                    font.weight: Font.Black
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                Item {
                                    id: waveClipItem
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: parent.height * win.brightnessFrac
                                    clip: true
                                    visible: win.available && win.brightnessPct > 0

                                    Text {
                                        x: (waveClipItem.width - width) / 2
                                        y: 46 - (core.height - waveClipItem.height)
                                        text: win.brightnessPct + "%"
                                        color: win.crust
                                        font.family: root.textFont
                                        font.pixelSize: 24
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
                                height: parent.innerHeight * win.brightnessFrac
                                radius: width / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.inset
                                opacity: win.available ? 0.94 : 0.2

                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: Qt.lighter(win.yellow, 1.18) }
                                    GradientStop { position: 1.0; color: win.gold }
                                }

                                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                        }
                        }
                    }
                }
            }
        }
    }
}
