import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../theme" as ThemePkg

PopupWindow {
    id: root

    property var trayItemMenu: null
    property real scaleFactor: 1.0
    property bool popupTargetVisible: false
    property bool finalizingAnimatedClose: false

    readonly property real popupOpenWidth: Math.max(150 * scaleFactor, contentColumn.implicitWidth) + (24 * scaleFactor)
    readonly property real popupOpenHeight: contentColumn.implicitHeight + (24 * scaleFactor)
    readonly property real popupClosedWidth: Math.max(120 * scaleFactor, popupOpenWidth - (28 * scaleFactor))
    readonly property real popupClosedHeight: Math.max(42 * scaleFactor, popupOpenHeight - (20 * scaleFactor))

    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.42
    property real popupCardScaleY: 0.24
    property real popupCardWidth: popupOpenWidth
    property real popupCardHeight: popupOpenHeight
    property real popupCardRadius: 17 * scaleFactor
    property real popupCardLift: 8.5 * scaleFactor

    property var activeSubMenuEntry: null
    property real activeSubMenuY: 0
    property bool isSubmenu: false

    signal closeMenuTree

    onCloseMenuTree: {
        root.beginAnimatedClose();
    }

    onVisibleChanged: {
        if (!visible) {
            if (!finalizingAnimatedClose && popupTargetVisible) {
                Qt.callLater(() => {
                    if (!finalizingAnimatedClose && popupTargetVisible) {
                        root.visible = true;
                        root.beginAnimatedClose();
                    }
                });
                return;
            }

            finalizingAnimatedClose = false;
            popupTargetVisible = false;
            root.activeSubMenuEntry = null;
            resetClosedMorph();
        }
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalCloseAllPopups() {
            if (root.visible && !finalizingAnimatedClose && !root.isSubmenu) {
                root.beginAnimatedClose();
            }
        }
        function onGlobalCloseShellPopups() {
            if (root.visible && !finalizingAnimatedClose && !root.isSubmenu) {
                root.beginAnimatedClose();
            }
        }
    }

    color: "transparent"

    implicitWidth: popupOpenWidth
    implicitHeight: popupOpenHeight

    function resetClosedMorph() {
        popupCardOpacity = 0.0;
        popupCardScaleX = 0.42;
        popupCardScaleY = 0.24;
        popupCardWidth = popupOpenWidth;
        popupCardHeight = popupOpenHeight;
        popupCardRadius = 17 * scaleFactor;
        popupCardLift = 8.5 * scaleFactor;
    }

    function openAnimated() {
        if (!isSubmenu) {
            ThemePkg.Theme.globalCloseAllPopups();
        }

        finalizingAnimatedClose = false;
        popupTargetVisible = true;
        root.visible = true;
        popupExitAnim.stop();
        resetClosedMorph();
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function beginAnimatedClose() {
        if (!root.visible && popupCardOpacity <= 0.001)
            return;

        popupTargetVisible = false;
        root.activeSubMenuEntry = null;
        if (subMenuLoader.item && subMenuLoader.item.beginAnimatedClose)
            subMenuLoader.item.beginAnimatedClose();
        popupEnterAnim.stop();
        if (!popupExitAnim.running)
            popupExitAnim.start();
    }

    function finalizeClose() {
        if (subMenuLoader.item && subMenuLoader.item.visible && subMenuLoader.item.beginAnimatedClose)
            subMenuLoader.item.beginAnimatedClose();
        root.activeSubMenuEntry = null;
        finalizingAnimatedClose = true;
        root.visible = false;
    }

    PanelWindow {
        id: scrim
        visible: root.visible && !root.isSubmenu && !root.finalizingAnimatedClose

        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Component.onCompleted: {
            try {
                if (scrim.WlrLayershell) {
                    scrim.WlrLayershell.layer = WlrLayer.Overlay;
                }
            } catch (e) {}
        }

        MouseArea {
            anchors.fill: parent
            onPressed: root.beginAnimatedClose()
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.visible
        onActivated: root.beginAnimatedClose()
    }

    Rectangle {
        anchors.fill: parent
        radius: popupCardRadius
        color: ThemePkg.Theme.surface(0.10)
        border.color: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
        border.width: 1 * scaleFactor
        opacity: popupCardOpacity
        transform: [
            Scale {
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: popupCardScaleX
                yScale: popupCardScaleY
            },
            Translate { y: popupCardLift }
        ]

        AnimatedBorder {
            anchors.fill: parent
            radius: parent.radius
            borderWidth: parent.border.width
            accentColor: ThemePkg.Theme.accent
            active: root.popupTargetVisible && root.popupCardOpacity > 0.98
        }

        QsMenuOpener {
            id: opener
            menu: root.trayItemMenu
        }

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 4 * scaleFactor

            Repeater {
                model: opener.children

                delegate: Rectangle {
                    id: itemRect
                    Layout.fillWidth: true
                    Layout.preferredHeight: isSeparator ? 1 * scaleFactor : 30 * scaleFactor
                    Layout.minimumWidth: Math.max(150 * scaleFactor, itemText.implicitWidth + 24 * scaleFactor)

                    property bool isSeparator: typeof modelData.isSeparator !== "undefined" ? modelData.isSeparator : false

                    color: {
                        if (isSeparator)
                            return ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35);
                        return ma.containsMouse ? ThemePkg.Theme.accent : "transparent";
                    }

                    radius: 4 * scaleFactor

                    Text {
                        id: itemText
                        text: modelData.text || ""
                        color: ma.containsMouse ? ThemePkg.Theme.background : ThemePkg.Theme.accent
                        font.pixelSize: 13 * scaleFactor
                        font.family: "Fira Sans Semibold"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * scaleFactor
                        visible: !itemRect.isSeparator
                    }

                    Text {
                        text: "▶"
                        color: ma.containsMouse ? ThemePkg.Theme.background : ThemePkg.Theme.accent
                        font.pixelSize: 10 * scaleFactor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * scaleFactor
                        visible: !itemRect.isSeparator && typeof modelData.hasChildren !== "undefined" && modelData.hasChildren
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: !itemRect.isSeparator
                        visible: !itemRect.isSeparator
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            if (!itemRect.isSeparator) {
                                if (typeof modelData.hasChildren !== "undefined" && modelData.hasChildren) {
                                    root.activeSubMenuEntry = modelData;
                                    root.activeSubMenuY = contentColumn.y + itemRect.y;
                                } else {
                                    root.activeSubMenuEntry = null;
                                }
                            }
                        }

                        onClicked: {
                            if (typeof modelData.hasChildren !== "undefined" && modelData.hasChildren) {
                                root.activeSubMenuEntry = modelData;
                                root.activeSubMenuY = contentColumn.y + itemRect.y;
                            } else {
                                modelData.triggered();
                                root.closeMenuTree();
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: subMenuLoader
        active: root.visible && root.activeSubMenuEntry !== null
        source: active ? "TrayMenu.qml" : ""

        onLoaded: {
            item.trayItemMenu = Qt.binding(function () {
                return root.activeSubMenuEntry;
            });
            item.scaleFactor = Qt.binding(function () {
                return root.scaleFactor;
            });
            item.anchor.window = root;
            item.anchor.rect.x = 0;
            item.anchor.rect.y = Qt.binding(function () {
                return root.activeSubMenuY;
            });
            item.anchor.rect.width = Qt.binding(function () {
                return root.width;
            });
            item.anchor.rect.height = Qt.binding(function () {
                return 30 * root.scaleFactor;
            });
            item.anchor.edges = Edges.Right | Edges.Top;
            item.closeMenuTree.connect(root.closeMenuTree);
            item.isSubmenu = true;
            item.openAnimated();
        }
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 14 * root.scaleFactor; duration: 270; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8 * root.scaleFactor; duration: 300; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 10 * root.scaleFactor; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        onStopped: {
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.finalizeClose();
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 15 * root.scaleFactor; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5 * root.scaleFactor; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 17 * root.scaleFactor; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8.5 * root.scaleFactor; duration: 280; easing.type: Easing.InCubic }
        }
    }
}
