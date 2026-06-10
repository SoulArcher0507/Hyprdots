import "../../theme" as ThemePkg
import QtQuick
import Quickshell

Item {
    id: root

    property color moduleColor
    property color moduleBorderColor
    property color moduleFontColor
    readonly property int panelWidth: 500
    readonly property int panelHeight: 285
    readonly property real popupOpenWidth: panelWidth
    readonly property real popupOpenHeight: panelHeight
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2
    readonly property int overlayEnterDuration: 515
    readonly property int overlayExitDuration: 375
    readonly property bool overlayOwnsOpenAnimation: true
    readonly property bool overlayOwnsCloseAnimation: true
    property bool popupTargetVisible: false
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1
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
    property real globalOrbitAngle: 0

    signal startButtonEnter()
    signal startButtonExit()
    signal startButtonEnterInstant()
    signal startButtonExitInstant()

    function beginOverlayClose() {
        if (!popupTargetVisible)
            return ;

        popupTargetVisible = false;
        if (ThemePkg.Theme.popupAnimationsEnabled)
            root.startButtonExit();
        else
            root.startButtonExitInstant();
    }

    function cancelOverlayClose() {
        popupTargetVisible = true;
        if (ThemePkg.Theme.popupAnimationsEnabled)
            root.startButtonEnter();
        else
            root.startButtonEnterInstant();
    }

    function openInstant() {
        popupTargetVisible = true;
        root.startButtonEnterInstant();
    }

    function closeInstant() {
        popupTargetVisible = false;
        root.startButtonExitInstant();
    }

    function triggerHibernate() {
        const cmd = "err=\"$(systemctl hibernate 2>&1)\"\n" + "status=$?\n" + "if [ \"$status\" -ne 0 ]; then\n" + "    if [ -z \"$err\" ]; then\n" + "        err=\"Hibernate failed.\"\n" + "    fi\n" + "    notify-send -a \"ArchTools\" -i \"system-suspend-hibernate\" \"Hibernate\" \"$err\"\n" + "fi\n" + "exit \"$status\"\n";
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

    anchors.fill: parent
    Component.onCompleted: {
        popupTargetVisible = true;
        Qt.callLater(function() {
            if (ThemePkg.Theme.popupAnimationsEnabled)
                root.startButtonEnter();
            else
                root.startButtonEnterInstant();
        });
    }
    onHostLoaderOpacityChanged: {
        if (hostLoaderOpacity < lastHostLoaderOpacity - 0.001 && popupTargetVisible) {
            popupTargetVisible = false;
            if (ThemePkg.Theme.popupAnimationsEnabled)
                root.startButtonExit();
            else
                root.startButtonExitInstant();
        }
        lastHostLoaderOpacity = hostLoaderOpacity;
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

        width: root.popupOpenWidth
        height: root.popupOpenHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Grid {
            anchors.centerIn: parent
            rows: 2
            columns: 3
            rowSpacing: 25
            columnSpacing: 25

            Repeater {
                model: powerModel

                Item {
                    id: actionSlot

                    width: 150
                    height: 130

                    Rectangle {
                        id: actionCapsule

                        readonly property real buttonOpenWidth: actionSlot.width
                        readonly property real buttonOpenHeight: actionSlot.height
                        readonly property real buttonClosedWidth: 64
                        readonly property real buttonClosedHeight: 30
                        readonly property real buttonOpenRadius: 16
                        readonly property real buttonClosedRadius: 10
                        property real buttonOpacity: 0
                        property real buttonScaleX: 0.42
                        property real buttonScaleY: 0.24
                        property real buttonWidth: buttonClosedWidth
                        property real buttonHeight: buttonClosedHeight
                        property real buttonRadius: buttonClosedRadius
                        property real buttonLift: 8.5
                        property real interactionScale: btnMa.pressed ? 0.95 : (btnMa.containsMouse ? 1.05 : 1)
                        property color brandColor: root[model.btnColor]
                        property color c2: Qt.lighter(brandColor, 1.2)
                        property real fillLevel: 0
                        property bool triggered: false
                        property real flashOpacity: 0

                        width: buttonWidth
                        height: buttonHeight
                        x: (actionSlot.width - width) / 2
                        y: (actionSlot.height - height) / 2
                        radius: buttonRadius
                        opacity: buttonOpacity
                        clip: true
                        color: btnMa.containsMouse ? Qt.lighter(root.moduleColor, 1.2) : root.moduleColor
                        border.color: btnMa.containsMouse ? brandColor : root.moduleBorderColor
                        border.width: btnMa.containsMouse ? 2 : 1
                        transform: [
                            Scale {
                                origin.x: actionCapsule.width / 2
                                origin.y: actionCapsule.height / 2
                                xScale: actionCapsule.buttonScaleX * actionCapsule.interactionScale
                                yScale: actionCapsule.buttonScaleY * actionCapsule.interactionScale
                            },
                            Translate {
                                y: actionCapsule.buttonLift
                            }
                        ]

                        AnimatedBorder {
                            anchors.fill: parent
                            radius: parent.radius
                            borderWidth: parent.border.width
                            accentColor: actionCapsule.brandColor
                        }

                        Connections {
                            function onStartButtonEnter() {
                                buttonExitAnim.stop();
                                buttonEnterAnim.restart();
                            }

                            function onStartButtonEnterInstant() {
                                buttonExitAnim.stop();
                                buttonEnterAnim.stop();
                                actionCapsule.buttonOpacity = 1;
                                actionCapsule.buttonScaleX = 1;
                                actionCapsule.buttonScaleY = 1;
                                actionCapsule.buttonWidth = actionCapsule.buttonOpenWidth;
                                actionCapsule.buttonHeight = actionCapsule.buttonOpenHeight;
                                actionCapsule.buttonRadius = actionCapsule.buttonOpenRadius;
                                actionCapsule.buttonLift = 0;
                            }

                            function onStartButtonExit() {
                                buttonEnterAnim.stop();
                                buttonExitAnim.restart();
                            }

                            function onStartButtonExitInstant() {
                                buttonEnterAnim.stop();
                                buttonExitAnim.stop();
                                actionCapsule.buttonOpacity = 0;
                                actionCapsule.buttonScaleX = 0.42;
                                actionCapsule.buttonScaleY = 0.24;
                                actionCapsule.buttonWidth = actionCapsule.buttonClosedWidth;
                                actionCapsule.buttonHeight = actionCapsule.buttonClosedHeight;
                                actionCapsule.buttonRadius = actionCapsule.buttonClosedRadius;
                                actionCapsule.buttonLift = 8.5;
                            }

                            target: root
                        }

                        SequentialAnimation {
                            id: buttonEnterAnim

                            running: false

                            ParallelAnimation {
                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonOpacity"
                                    to: 0.82
                                    duration: 210
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleX"
                                    to: 0.985
                                    duration: 280
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleY"
                                    to: 0.94
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonWidth"
                                    to: actionCapsule.buttonOpenWidth - 18
                                    duration: 285
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonHeight"
                                    to: actionCapsule.buttonOpenHeight - 18
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonRadius"
                                    to: 28
                                    duration: 270
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonLift"
                                    to: 8
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonOpacity"
                                    to: 1
                                    duration: 175
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleX"
                                    to: 1
                                    duration: 205
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleY"
                                    to: 1
                                    duration: 205
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonWidth"
                                    to: actionCapsule.buttonOpenWidth
                                    duration: 205
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonHeight"
                                    to: actionCapsule.buttonOpenHeight
                                    duration: 215
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonRadius"
                                    to: actionCapsule.buttonOpenRadius
                                    duration: 195
                                    easing.type: Easing.InOutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonLift"
                                    to: 0
                                    duration: 205
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        SequentialAnimation {
                            id: buttonExitAnim

                            running: false

                            ParallelAnimation {
                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleX"
                                    to: 1.04
                                    duration: 85
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleY"
                                    to: 0.95
                                    duration: 85
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonWidth"
                                    to: actionCapsule.buttonOpenWidth + 14
                                    duration: 95
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonHeight"
                                    to: actionCapsule.buttonOpenHeight - 16
                                    duration: 95
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonRadius"
                                    to: 28
                                    duration: 95
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonLift"
                                    to: 5
                                    duration: 95
                                    easing.type: Easing.OutQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonOpacity"
                                    to: 0.88
                                    duration: 80
                                    easing.type: Easing.OutQuad
                                }

                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonOpacity"
                                    to: 0
                                    duration: 180
                                    easing.type: Easing.InCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleX"
                                    to: 0.42
                                    duration: 260
                                    easing.type: Easing.InCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonScaleY"
                                    to: 0.24
                                    duration: 280
                                    easing.type: Easing.InCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonWidth"
                                    to: actionCapsule.buttonClosedWidth
                                    duration: 200
                                    easing.type: Easing.InCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonHeight"
                                    to: actionCapsule.buttonClosedHeight
                                    duration: 210
                                    easing.type: Easing.InCubic
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonRadius"
                                    to: actionCapsule.buttonClosedRadius
                                    duration: 200
                                    easing.type: Easing.InQuad
                                }

                                NumberAnimation {
                                    target: actionCapsule
                                    property: "buttonLift"
                                    to: 8.5
                                    duration: 280
                                    easing.type: Easing.InCubic
                                }

                            }

                        }

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

                            property real wavePhase: 0

                            anchors.fill: parent
                            onWavePhaseChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (actionCapsule.fillLevel <= 0.001)
                                    return ;

                                var r = 16;
                                var fillY = height * (1 - actionCapsule.fillLevel);
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

                            Connections {
                                function onFillLevelChanged() {
                                    actionWaveCanvas.requestPaint();
                                }

                                target: actionCapsule
                            }

                            NumberAnimation on wavePhase {
                                running: actionCapsule.fillLevel > 0 && actionCapsule.fillLevel < 1
                                loops: Animation.Infinite
                                from: 0
                                to: Math.PI * 2
                                duration: 800
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

                        MouseArea {
                            id: btnMa

                            anchors.fill: parent
                            enabled: actionCapsule.buttonOpacity > 0.98
                            hoverEnabled: true
                            cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onPressed: {
                                if (!actionCapsule.triggered) {
                                    drainAnim.stop();
                                    fillAnim.start();
                                }
                            }
                            onReleased: {
                                if (!actionCapsule.triggered && actionCapsule.fillLevel < 1) {
                                    fillAnim.stop();
                                    drainAnim.start();
                                }
                            }
                        }

                        NumberAnimation {
                            id: fillAnim

                            target: actionCapsule
                            property: "fillLevel"
                            to: 1
                            duration: 600 * (1 - actionCapsule.fillLevel)
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
                            to: 0
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

                        Behavior on interactionScale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutQuart
                            }

                        }

                    }

                    Column {
                        x: actionCapsule.x
                        y: actionCapsule.y + actionCapsule.buttonLift + (actionCapsule.height / 2) - (height / 2)
                        width: actionCapsule.width
                        opacity: actionCapsule.buttonOpacity
                        spacing: 12

                        Text {
                            width: parent.width
                            text: model.iconText
                            font.pixelSize: 42
                            font.family: "CaskaydiaMono Nerd Font"
                            color: btnMa.containsMouse ? actionCapsule.brandColor : root.moduleFontColor
                            horizontalAlignment: Text.AlignHCenter
                            renderType: Text.NativeRendering

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: model.labelText
                            font.pixelSize: 14
                            font.family: "Fira Sans Semibold"
                            color: btnMa.containsMouse ? root.text : root.moduleFontColor
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Text.NativeRendering

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }

                    Item {
                        x: actionCapsule.x
                        y: actionCapsule.y + actionCapsule.buttonLift + actionCapsule.height - height
                        width: actionCapsule.width
                        height: actionCapsule.height * actionCapsule.fillLevel
                        opacity: actionCapsule.buttonOpacity
                        clip: true

                        Column {
                            width: parent.width
                            y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                            spacing: 12

                            Text {
                                width: parent.width
                                font.family: "CaskaydiaMono Nerd Font"
                                font.pixelSize: 42
                                color: root.base
                                text: model.iconText
                                horizontalAlignment: Text.AlignHCenter
                                renderType: Text.NativeRendering
                            }

                            Text {
                                width: parent.width
                                font.family: "Fira Sans Semibold"
                                font.pixelSize: 14
                                color: root.base
                                text: model.labelText
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                }

            }

        }

    }

    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 200000
        loops: Animation.Infinite
        running: true
    }

}
