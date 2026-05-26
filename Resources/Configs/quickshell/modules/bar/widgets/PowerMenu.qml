import QtQuick
import Quickshell
import "../../theme" as ThemePkg

Item {
    id: root
    anchors.fill: parent

    property color moduleColor
    property color moduleBorderColor
    property color moduleFontColor

    readonly property int panelWidth: 500
    readonly property int panelHeight: 285
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
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity

    readonly property var _theme: ThemePkg.Theme
    readonly property color base: _theme.background
    readonly property color text: _theme.foreground
    readonly property color subtext0: _theme.muted
    readonly property color surface0: _theme.surface(0.1)

    readonly property color red: _theme.danger
    readonly property color green: _theme.success
    readonly property color yellow: _theme.c3
    readonly property color blue: _theme.accent
    readonly property color mauve: _theme.c5
    readonly property color peach: _theme.warning
    readonly property color surface1: _theme.surface(0.2)
    readonly property string lockScript: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/lock/lock_screen.sh"

    property real introMain: 0
    Component.onCompleted: {
        introMain = 1.0;
        popupTargetVisible = true;
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

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 200000
        loops: Animation.Infinite
        running: true
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

    function triggerHibernate() {
        const cmd = "err=\"$(systemctl hibernate 2>&1)\"\n"
            + "status=$?\n"
            + "if [ \"$status\" -ne 0 ]; then\n"
            + "    if [ -z \"$err\" ]; then\n"
            + "        err=\"Hibernate failed.\"\n"
            + "    fi\n"
            + "    notify-send -a \"ArchTools\" -i \"system-suspend-hibernate\" \"Hibernate\" \"$err\"\n"
            + "fi\n"
            + "exit \"$status\"\n";
        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    function triggerPowerAction(actionType) {
        switch (String(actionType || "")) {
        case "lock":
            Quickshell.execDetached(["bash", root.lockScript]);
            break;
        case "logout":
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
            break;
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "hibernate":
            root.triggerHibernate();
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "shutdown":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        default:
            console.warn("PowerMenu.qml: unknown power action:", actionType);
        }
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


    ListModel {
        id: powerModel
        ListElement {
            iconText: ""
            labelText: "Lock"
            actionType: "lock"
            btnColor: "yellow"
        }
        ListElement {
            iconText: ""
            labelText: "Logout"
            actionType: "logout"
            btnColor: "peach"
        }
        ListElement {
            iconText: ""
            labelText: "Suspend"
            actionType: "suspend"
            btnColor: "blue"
        }
        ListElement {
            iconText: ""
            labelText: "Hibernate"
            actionType: "hibernate"
            btnColor: "mauve"
        }
        ListElement {
            iconText: ""
            labelText: "Reboot"
            actionType: "reboot"
            btnColor: "green"
        }
        ListElement {
            iconText: ""
            labelText: "Shutdown"
            actionType: "shutdown"
            btnColor: "red"
        }
    }

    Item {
        id: popupShell
        width: root.popupCardWidth
        height: root.popupCardHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.popupCardLift
        opacity: root.popupCardOpacity

        transform: Scale {
            origin.x: popupShell.width / 2
            origin.y: popupShell.height / 2
            xScale: root.popupCardScaleX
            yScale: root.popupCardScaleY
        }

        Grid {
            anchors.centerIn: parent
            rows: 2
            columns: 3
            rowSpacing: 25
            columnSpacing: 25
            scale: 0.9 + (0.1 * introMain)
            opacity: introMain
            transform: Translate {
                y: 20 * (1 - introMain)
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on transform {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutQuart
                }
            }

            Repeater {
                model: powerModel

                Rectangle {
                    id: actionCapsule
                    width: 150
                    height: 130
                    radius: 16

                    property color brandColor: root[model.btnColor]
                    property color c2: Qt.lighter(brandColor, 1.2)

                    color: btnMa.containsMouse ? Qt.lighter(root.moduleColor, 1.2) : root.moduleColor
                    border.color: btnMa.containsMouse ? brandColor : root.moduleBorderColor
                    border.width: btnMa.containsMouse ? 2 : 1

                    ElectricBorder {
                        anchors.fill: parent
                        radius: parent.radius
                        borderWidth: parent.border.width
                        accentColor: actionCapsule.brandColor
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

                    scale: btnMa.pressed ? 0.95 : (btnMa.containsMouse ? 1.05 : 1.0)
                    Behavior on scale {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutQuart
                        }
                    }

                    property real fillLevel: 0.0
                    property bool triggered: false
                    property real flashOpacity: 0.0

                    Item {
                        anchors.fill: parent
                        clip: true

                        Rectangle {
                            width: parent.width * 0.8
                            height: width
                            radius: width / 2
                            x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 40
                            y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 30
                            opacity: 0.08
                            color: actionCapsule.brandColor
                        }
                        Rectangle {
                            width: parent.width * 0.9
                            height: width
                            radius: width / 2
                            x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -40
                            y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -30
                            opacity: 0.06
                            color: actionCapsule.c2
                        }
                    }

                    Canvas {
                        id: actionWaveCanvas
                        anchors.fill: parent

                        property real wavePhase: 0.0
                        NumberAnimation on wavePhase {
                            running: actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                            loops: Animation.Infinite
                            from: 0
                            to: Math.PI * 2
                            duration: 800
                        }
                        onWavePhaseChanged: requestPaint()
                        Connections {
                            target: actionCapsule
                            function onFillLevelChanged() {
                                actionWaveCanvas.requestPaint();
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (actionCapsule.fillLevel <= 0.001)
                                return;

                            var r = 16;
                            var fillY = height * (1.0 - actionCapsule.fillLevel);
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
                            if (actionCapsule.fillLevel < 0.99) {
                                var waveAmp = 10 * Math.sin(actionCapsule.fillLevel * Math.PI);
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
                            grad.addColorStop(0, actionCapsule.brandColor.toString());
                            grad.addColorStop(1, actionCapsule.c2.toString());
                            ctx.fillStyle = grad;
                            ctx.fill();
                            ctx.restore();
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "#ffffff"
                        opacity: actionCapsule.flashOpacity
                        PropertyAnimation on opacity {
                            id: cardFlashAnim
                            to: 0
                            duration: 500
                            easing.type: Easing.OutExpo
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: model.iconText
                            font.pixelSize: 42
                            font.family: "CaskaydiaMono Nerd Font"
                            color: btnMa.containsMouse ? actionCapsule.brandColor : root.moduleFontColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        Text {
                            text: model.labelText
                            font.pixelSize: 14
                            font.family: "Fira Sans Semibold"
                            color: btnMa.containsMouse ? root.text : root.moduleFontColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: actionCapsule.height * actionCapsule.fillLevel
                        clip: true

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                            spacing: 12

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.family: "CaskaydiaMono Nerd Font"
                                font.pixelSize: 42
                                color: root.base
                                text: model.iconText
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.family: "Fira Sans Semibold"
                                font.pixelSize: 14
                                color: root.base
                                text: model.labelText
                            }
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor

                        onPressed: {
                            if (!actionCapsule.triggered) {
                                drainAnim.stop();
                                fillAnim.start();
                            }
                        }
                        onReleased: {
                            if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) {
                                fillAnim.stop();
                                drainAnim.start();
                            }
                        }
                    }

                    NumberAnimation {
                        id: fillAnim
                        target: actionCapsule
                        property: "fillLevel"
                        to: 1.0
                        duration: 600 * (1.0 - actionCapsule.fillLevel)
                        easing.type: Easing.InSine
                        onFinished: {
                            actionCapsule.triggered = true;
                            actionCapsule.flashOpacity = 0.6;
                            cardFlashAnim.start();
                            exitTimer.start();
                        }
                    }

                    NumberAnimation {
                        id: drainAnim
                        target: actionCapsule
                        property: "fillLevel"
                        to: 0.0
                        duration: 1500 * actionCapsule.fillLevel
                        easing.type: Easing.OutQuad
                    }

                    Timer {
                        id: exitTimer
                        interval: 500
                        onTriggered: {
                            root.triggerPowerAction(model.actionType);
                            _theme.globalTogglePower();
                        }
                    }
                }
            }
        }
    }
}
