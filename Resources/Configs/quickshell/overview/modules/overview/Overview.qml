import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../services"
import "../../../modules/theme" as ThemePkg
import "."

Scope {
    id: overviewScope
    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            property bool isOverviewTarget: {
                if (!monitor)
                    return false;

                if (GlobalStates.overviewTargetMonitorId >= 0)
                    return monitor.id === GlobalStates.overviewTargetMonitorId;

                if (GlobalStates.overviewTargetMonitorName.length > 0)
                    return monitor.name === GlobalStates.overviewTargetMonitorName;

                return monitorIsFocused;
            }
            property bool blurEnabled: Config.options.overview.effects.enableBlur
            property bool popupMounted: false
            property bool popupTargetVisible: false
            property real popupOpacity: 0.0
            property real popupScaleX: 0.42
            property real popupScaleY: 0.24
            property real popupWidthFactor: 0.42
            property real popupHeightFactor: 0.24
            property real popupLift: 8.5
            screen: modelData
            visible: popupMounted && isOverviewTarget

            WlrLayershell.namespace: blurEnabled ? "quickshell:overview-blur" : "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.isOverviewTarget
                active: false
                onCleared: () => {
                    if (!active)
                        GlobalStates.overviewOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (GlobalStates.overviewOpen) {
                        if (root.isOverviewTarget) {
                            root.showOverviewPopup();
                            delayedGrabTimer.start();
                        } else {
                            root.closeInstant();
                        }
                    } else {
                        root.hideOverviewPopup();
                        grab.active = false;
                    }
                }
            }

            onIsOverviewTargetChanged: {
                if (!GlobalStates.overviewOpen)
                    return;

                if (isOverviewTarget) {
                    root.showOverviewPopup();
                    delayedGrabTimer.start();
                } else {
                    grab.active = false;
                    root.closeInstant();
                }
            }

            function showOverviewPopup() {
                popupTargetVisible = true;
                popupMounted = true;
                popupExitAnim.stop();
                if (!popupEnterAnim.running && popupOpacity >= 0.999)
                    return;
                popupEnterAnim.stop();
                if (ThemePkg.Theme.popupAnimationsEnabled)
                    popupEnterAnim.start();
                else
                    root.openInstant();
            }

            function hideOverviewPopup() {
                popupTargetVisible = false;
                popupEnterAnim.stop();
                if (!popupMounted && popupOpacity <= 0.001)
                    return;
                popupExitAnim.stop();
                if (ThemePkg.Theme.popupAnimationsEnabled)
                    popupExitAnim.start();
                else
                    root.closeInstant();
            }

            function openInstant() {
                popupExitAnim.stop();
                popupEnterAnim.stop();
                popupTargetVisible = true;
                popupMounted = true;
                popupOpacity = 1.0;
                popupScaleX = 1.0;
                popupScaleY = 1.0;
                popupWidthFactor = 1.0;
                popupHeightFactor = 1.0;
                popupLift = 0;
            }

            function closeInstant() {
                popupEnterAnim.stop();
                popupExitAnim.stop();
                popupTargetVisible = false;
                popupMounted = false;
                popupOpacity = 0.0;
                popupScaleX = 0.42;
                popupScaleY = 0.24;
                popupWidthFactor = 0.42;
                popupHeightFactor = 0.24;
                popupLift = 8.5;
            }

            function dispatchWorkspace(workspaceId) {
                Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${workspaceId} })`]);
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return;
                    grab.active = root.popupTargetVisible;
                }
            }

            SequentialAnimation {
                id: popupEnterAnim
                running: false

                onStopped: {
                    if (!root.popupTargetVisible && root.popupOpacity <= 0.001)
                        root.popupMounted = false;
                }

                ParallelAnimation {
                    NumberAnimation { target: root; property: "popupOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 0.985; duration: 285; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupLift"; to: 8; duration: 300; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    NumberAnimation { target: root; property: "popupOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 1.0; duration: 215; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
                }
            }

            SequentialAnimation {
                id: popupExitAnim
                running: false

                onStopped: {
                    if (!root.popupTargetVisible && root.popupOpacity <= 0.001)
                        root.popupMounted = false;
                }

                ParallelAnimation {
                    NumberAnimation { target: root; property: "popupScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 1.04; duration: 95; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 0.95; duration: 95; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
                }

                ParallelAnimation {
                    NumberAnimation { target: root; property: "popupOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 0.42; duration: 200; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 0.24; duration: 210; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupLift"; to: 8.5; duration: 280; easing.type: Easing.InCubic }
                }
            }

            implicitWidth: screen.width
            implicitHeight: screen.height

            Item {
                id: keyHandler
                anchors.fill: parent
                visible: root.popupMounted
                focus: root.popupMounted
                z: 0


                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
                        GlobalStates.overviewOpen = false;
                        event.accepted = true;
                        return;
                    }

                    const workspacesPerGroup = Config.options.overview.rows * Config.options.overview.columns;
                    const currentId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
                    const useWorkspaceMap = Config.options.overview.useWorkspaceMap;
                    const workspaceMap = Config.options.overview.workspaceMap ?? [];
                    const focusedMonitorId = Hyprland.focusedMonitor?.id ?? root.monitor?.id ?? 0;
                    const workspaceOffset = useWorkspaceMap ? Number(workspaceMap[focusedMonitorId] ?? 0) : 0;
                    const currentGroup = Math.floor((currentId - workspaceOffset - 1) / workspacesPerGroup);
                    const minWorkspaceId = currentGroup * workspacesPerGroup + 1 + workspaceOffset;
                    const maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1;

                    const rows = Config.options.overview.rows;
                    const columns = Config.options.overview.columns;
                    const reverseColumns = Config.options.overview.orderRightLeft;
                    const reverseRows = Config.options.overview.orderBottomUp;

                    const clampedIndex = Math.max(0, Math.min(workspacesPerGroup - 1, currentId - minWorkspaceId));
                    const currentNormalRow = Math.floor(clampedIndex / columns);
                    const currentNormalColumn = clampedIndex % columns;

                    function toVisualRow(normalRow) {
                        return reverseRows ? (rows - normalRow - 1) : normalRow;
                    }

                    function toVisualColumn(normalColumn) {
                        return reverseColumns ? (columns - normalColumn - 1) : normalColumn;
                    }

                    function toNormalRow(visualRow) {
                        return reverseRows ? (rows - visualRow - 1) : visualRow;
                    }

                    function toNormalColumn(visualColumn) {
                        return reverseColumns ? (columns - visualColumn - 1) : visualColumn;
                    }

                    let targetVisualRow = toVisualRow(currentNormalRow);
                    let targetVisualColumn = toVisualColumn(currentNormalColumn);

                    let targetId = null;

                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        targetVisualColumn = (targetVisualColumn - 1 + columns) % columns;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        targetVisualColumn = (targetVisualColumn + 1) % columns;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        targetVisualRow = (targetVisualRow - 1 + rows) % rows;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        targetVisualRow = (targetVisualRow + 1) % rows;
                    }

                    else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const position = event.key - Qt.Key_0; 
                        if (position <= workspacesPerGroup) {
                            targetId = minWorkspaceId + position - 1;
                        }
                    } else if (event.key === Qt.Key_0) {
                        if (workspacesPerGroup >= 10) {
                            targetId = minWorkspaceId + 9; 
                        }
                    }

                    if (targetId === null && (
                        event.key === Qt.Key_Left || event.key === Qt.Key_H ||
                        event.key === Qt.Key_Right || event.key === Qt.Key_L ||
                        event.key === Qt.Key_Up || event.key === Qt.Key_K ||
                        event.key === Qt.Key_Down || event.key === Qt.Key_J
                    )) {
                        const targetNormalRow = toNormalRow(targetVisualRow);
                        const targetNormalColumn = toNormalColumn(targetVisualColumn);
                        targetId = minWorkspaceId + targetNormalRow * columns + targetNormalColumn;
                    }

                    if (targetId !== null) {
                        const clampedTarget = Math.max(minWorkspaceId, Math.min(maxWorkspaceId, targetId));
                        root.dispatchWorkspace(clampedTarget);
                        event.accepted = true;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: GlobalStates.overviewOpen = false
                }
            }

            ColumnLayout {
                id: columnLayout
                visible: root.popupMounted
                opacity: root.popupOpacity
                transform: [
                    Scale {
                        origin.x: columnLayout.width / 2
                        origin.y: columnLayout.height / 2
                        xScale: root.popupScaleX
                        yScale: root.popupScaleY
                    },
                    Translate { y: root.popupLift }
                ]
                z: 1
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: Config.options.position.topMargin
                }

                Item {
                    id: overviewShell
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: overviewLoader.implicitWidth
                    implicitHeight: overviewLoader.implicitHeight
                    width: implicitWidth * root.popupWidthFactor
                    height: implicitHeight * root.popupHeightFactor

                    Loader {
                        id: overviewLoader
                        anchors.fill: parent
                        active: root.popupMounted && root.isOverviewTarget && (Config?.options.overview.enable ?? true)
                        sourceComponent: OverviewWidget {
                            panelWindow: root
                            visible: true
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "overview"

        function setTargetMonitorFromFocus() {
            const monitor = Hyprland.focusedMonitor;
            GlobalStates.overviewTargetMonitorId = monitor?.id ?? -1;
            GlobalStates.overviewTargetMonitorName = monitor?.name ?? "";
        }

        function toggle() {
            if (GlobalStates.overviewOpen) {
                GlobalStates.overviewOpen = false;
            } else {
                setTargetMonitorFromFocus();
                GlobalStates.overviewOpen = true;
            }
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            setTargetMonitorFromFocus();
            GlobalStates.overviewOpen = true;
        }
    }
}
