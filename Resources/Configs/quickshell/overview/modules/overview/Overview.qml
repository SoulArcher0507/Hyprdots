import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../services"
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
            property bool blurEnabled: Config.options.overview.effects.enableBlur
            property bool popupMounted: false
            property bool popupTargetVisible: false
            property real popupOpacity: 0.0
            property real popupScaleX: 0.91
            property real popupScaleY: 0.79
            property real popupWidthFactor: 0.9
            property real popupHeightFactor: 0.82
            property real popupLift: 18
            screen: modelData
            visible: popupMounted

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
                property bool canBeActive: root.monitorIsFocused
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
                        root.showOverviewPopup();
                        delayedGrabTimer.start();
                    } else {
                        root.hideOverviewPopup();
                        grab.active = false;
                    }
                }
            }

            function showOverviewPopup() {
                popupTargetVisible = true;
                popupMounted = true;
                popupExitAnim.stop();
                if (!popupEnterAnim.running && popupOpacity >= 0.999)
                    return;
                popupEnterAnim.stop();
                popupEnterAnim.start();
            }

            function hideOverviewPopup() {
                popupTargetVisible = false;
                popupEnterAnim.stop();
                if (!popupMounted && popupOpacity <= 0.001)
                    return;
                popupExitAnim.stop();
                popupExitAnim.start();
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
                    NumberAnimation { target: root; property: "popupOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 0.975; duration: 190; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 0.93; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "popupLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
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
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 1.03; duration: 95; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 0.95; duration: 95; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
                    NumberAnimation { target: root; property: "popupOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
                }

                ParallelAnimation {
                    NumberAnimation { target: root; property: "popupOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupWidthFactor"; to: 0.86; duration: 200; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupHeightFactor"; to: 0.74; duration: 210; easing.type: Easing.InCubic }
                    NumberAnimation { target: root; property: "popupLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
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
                        Hyprland.dispatch("workspace " + clampedTarget);
                        event.accepted = true;
                    }
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
                        active: root.popupMounted && (Config?.options.overview.enable ?? true)
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

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
    }
}
