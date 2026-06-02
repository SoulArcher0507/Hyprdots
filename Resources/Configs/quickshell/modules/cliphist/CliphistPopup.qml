import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io as Io
import "../theme" as ThemePkg
import Quickshell.Io
import "../bar/widgets" as BarWidgets

/* Popup Cliphist: overlay top-right, click fuori = chiudi */
Item {
    id: root

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
    readonly property color accent: ThemePkg.Theme.accent
    readonly property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color moduleFontColor: ThemePkg.Theme.accent

    property int defaultTopMarginPx: 0   
    property int topMarginPx: 0
    property int minListHeight: 180
    property int maxListHeight: 420
    property int minCardWidth: 400
    property int maxCardWidth: 600
    property int maxCardHeight: 680

    property bool isOpen: popupTargetVisible
    property int contentMaxHeight: 420
    readonly property real popupOpenWidth: Math.max(minCardWidth, Math.min(maxCardWidth, content.implicitWidth + 50))
    readonly property real popupOpenHeight: Math.min(maxCardHeight, content.implicitHeight + 50)
    readonly property real popupClosedWidth: Math.max(320, popupOpenWidth - 44)
    readonly property real popupClosedHeight: Math.max(180, popupOpenHeight - 28)
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 34

    property bool popupMounted: false
    property bool popupTargetVisible: false
    property bool suppressOutsideClose: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18

    Component.onCompleted: {
        root._resetPopupMorphState();
        listModel.reload();
    }

    function _resetPopupMorphState() {
        popupCardOpacity = 0.0;
        popupCardScaleX = 0.91;
        popupCardScaleY = 0.79;
        popupCardWidth = popupClosedWidth;
        popupCardHeight = popupClosedHeight;
        popupCardRadius = popupClosedRadius;
        popupCardLift = 18;
    }

    function _syncPopupOpenGeometry() {
        popupCardWidth = popupOpenWidth;
        popupCardHeight = popupOpenHeight;
        popupCardRadius = popupOpenRadius;
    }

    function _preparePopupOpen(px) {
        ThemePkg.Theme.globalCloseAllPopups();
        topMarginPx = px;
        search.text = "";
        listModel.reload();
        _showPopup();
        search.forceActiveFocus();
    }

    function _showPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        suppressOutsideClose = true;
        outsideCloseGuard.restart();
        root._resetPopupMorphState();
        popupExitAnim.stop();
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function _hidePopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        popupExitAnim.start();
    }

    Io.IpcHandler {
        target: "cliphist"

        function show(): void {
            root._preparePopupOpen(root.defaultTopMarginPx);
        }

        function showAt(px: int): void {
            root._preparePopupOpen(px);
        }

        function toggle(): void {
            if (root.popupTargetVisible) {
                root._hidePopup();
                return;
            }
            root._preparePopupOpen(root.defaultTopMarginPx);
        }

        function hide(): void {
            root._hidePopup();
        }
        function opened(): bool {
            return root.popupTargetVisible;
        }
    }

    Timer {
        id: outsideCloseGuard
        interval: 350
        repeat: false
        onTriggered: root.suppressOutsideClose = false
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalCloseShellPopups() {
            if (root.suppressOutsideClose)
                return;
            root._hidePopup();
        }
        function onGlobalCloseAllPopups() {
            root._hidePopup();
        }
    }

    function stripIdPrefix(s) {
        return String(s || "").replace(/^\s*\d+\s+/, "").trim();
    }

    PanelWindow {
        id: win
        visible: root.popupMounted
        focusable: root.popupMounted

        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Component.onCompleted: {
            try {
                if (win.WlrLayershell) {
                    win.WlrLayershell.layer = WlrLayer.Overlay;
                }
            } catch (e) {}
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.suppressOutsideClose)
                    return;
                root._hidePopup();
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

        Item {
            id: cardShell
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: root.topMarginPx
            anchors.rightMargin: 16
            width: root.popupCardWidth
            height: root.popupCardHeight
            opacity: root.popupCardOpacity
            transform: [
                Scale {
                    origin.x: cardShell.width / 2
                    origin.y: cardShell.height / 2
                    xScale: root.popupCardScaleX
                    yScale: root.popupCardScaleY
                },
                Translate { y: root.popupCardLift }
            ]

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: root.popupCardRadius
                color: root.base
                border.color: root.moduleBorderColor
                border.width: 1
                clip: true

                BarWidgets.AnimatedBorder {
                    anchors.fill: parent
                    radius: parent.radius
                    borderWidth: parent.border.width
                    accentColor: root.moduleFontColor
                }

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: root.popupMounted
                }

                Rectangle {
                    width: parent.width * 0.8; height: width; radius: width / 2
                    x: (parent.width * 0.5 - width / 2) + Math.cos(card.globalOrbitAngle * 1.5) * 80
                    y: (parent.height * 0.1 - height / 2) + Math.sin(card.globalOrbitAngle * 1.5) * 100
                    opacity: 0.04
                    color: root.accent
                    z: 0
                }

                Rectangle {
                    width: parent.width * 0.6; height: width; radius: width / 2
                    x: (parent.width * 0.2 - width / 2) + Math.sin(card.globalOrbitAngle * 1.2) * -60
                    y: (parent.height * 0.8 - height / 2) + Math.cos(card.globalOrbitAngle * 1.2) * -80
                    opacity: 0.03
                    color: ThemePkg.Theme.c5 
                    z: 0
                }

                Text {
                    id: parallaxIcon
                    anchors.centerIn: parent
                    property real drift: 0
                    SequentialAnimation on drift {
                        loops: Animation.Infinite; running: root.popupMounted
                        NumberAnimation { to: -15; duration: 6000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                    }
                    transform: Translate { y: parallaxIcon.drift }

                    text: "󰅌" 
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 320
                    color: root.accent
                    opacity: 0.03 + (0.01 * Math.sin(card.globalOrbitAngle * 4))
                    z: 0
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    z: 1
                    anchors.margins: 25
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: search
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            placeholderText: "Search Clipboard…"
                            color: root.text
                            placeholderTextColor: root.overlay1

                            background: Rectangle {
                                color: "#0dffffff"
                                border.color: search.activeFocus ? root.accent : "#1affffff"
                                border.width: 1
                                radius: 10
                            }

                            onTextChanged: listModel.applyFilter(text)
                            Keys.onReturnPressed: {
                                if (cliphistModel.count > 0) {
                                    const first = cliphistModel.get(0);
                                    if (first && first.line)
                                        actions.copyItem(first.line);
                                }
                            }
                            Keys.onEscapePressed: root._hidePopup()
                        }

                        Rectangle {
                            id: clearAllBtn
                            Layout.alignment: Qt.AlignRight
                            visible: cliphistModel.count > 0
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: clearText.implicitWidth + 24
                            radius: 10
                            color: btnMouse.containsMouse ? root.accent : "#0dffffff"
                            border.color: btnMouse.containsMouse ? root.accent : "#1affffff"
                            border.width: 1

                            property bool confirmMode: false

                            Text {
                                id: clearText
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: clearAllBtn.confirmMode ? "Are you sure?" : "Clear all"
                                color: btnMouse.containsMouse ? root.base : root.accent
                                font.pixelSize: 12
                                font.family: "Fira Sans Semibold"
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (clearAllBtn.confirmMode) {
                                        actions.wipeAll();
                                        clearAllBtn.confirmMode = false;
                                    } else {
                                        clearAllBtn.confirmMode = true;
                                        cancelTimer.restart();
                                    }
                                }
                            }

                            Timer {
                                id: cancelTimer
                                interval: 3000
                                onTriggered: clearAllBtn.confirmMode = false
                            }
                        }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        implicitHeight: Math.min(contentHeight, root.contentMaxHeight)
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: cliphistModel

                        ThemePkg.FastScrollHandler {
                            anchors.fill: parent
                            flickable: list
                        }

                        delegate: Rectangle {
                            id: row
                            width: list.width - 16
                            color: hovered ? "#0affffff" : "#05ffffff"
                            radius: 14
                            border.width: 1
                            border.color: hovered ? root.accent : "#1affffff"
                            implicitHeight: Math.max(40, mainRow.implicitHeight + 20)

                            property bool hovered: false

                            RowLayout {
                                id: mainRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 12

                                Rectangle {
                                    id: badge
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: Math.max(28, badgeText.implicitWidth + 12)
                                    Layout.preferredHeight: 24
                                    radius: 8
                                    color: "#0dffffff"
                                    border.color: "#1affffff"
                                    border.width: 1

                                    Text {
                                        id: badgeText
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        bottomPadding: 1
                                        text: (cliphistModel ? (cliphistModel.count - index) : 0)
                                        color: moduleFontColor
                                        font.pixelSize: 12
                                        font.family: "Fira Sans Semibold"
                                    }
                                }

                                Text {
                                    id: textItem
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: stripIdPrefix(model.line)
                                    color: root.text
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font.pixelSize: 13
                                    lineHeight: 1.2
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: row.hovered = true
                                onExited: row.hovered = false
                                onClicked: actions.copyItem(model.line)
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: vbar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || list.moving

                            background: Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: moduleBorderColor
                                border.color: moduleBorderColor
                                opacity: vbar.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: moduleBorderColor
                                color: moduleFontColor
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: cliphistModel
    }

    QtObject {
        id: listModel
        property var all: []

        function lineToEntry(line) {
            if (!line || !line.trim())
                return null;
            const tab = line.indexOf("\t");
            const id = tab > 0 ? line.slice(0, tab) : line.split(/\s+/)[0];
            const preview = tab > 0 ? line.slice(tab + 1) : line;
            return {
                id,
                preview,
                line
            };
        }
        function applyFilter(q) {
            cliphistModel.clear();
            const needle = String(q || "").toLowerCase();
            let itemsToAppend = [];

            if (!needle) {
                itemsToAppend = all;
            } else {
                for (let i = 0; i < all.length; i++) {
                    const entry = all[i];
                    const preview = entry.preview.toLowerCase();

                    let score = -1;
                    if (preview === needle) {
                        score = 100;
                    } else if (preview.startsWith(needle)) {
                        score = 50;
                    } else if (preview.includes(needle)) {
                        score = 10;
                    } else {
                        let subIdx = 0;
                        for (let j = 0; j < preview.length && subIdx < needle.length; j++) {
                            if (needle[subIdx] === preview[j])
                                subIdx++;
                        }

                        if (subIdx === needle.length) {
                            score = 8;
                        } else if (needle.length >= 3) {
                            let matches = 0;
                            let previewArray = preview.split("");
                            for (let k = 0; k < needle.length; k++) {
                                let idx = previewArray.indexOf(needle[k]);
                                if (idx !== -1) {
                                    matches++;
                                    previewArray[idx] = null;
                                }
                            }

                            let matchRatio = matches / needle.length;
                            if (matchRatio >= 0.75) {
                                let lengthPenalty = Math.abs(needle.length - preview.length) / Math.max(preview.length, 1);
                                let firstLetterPenalty = (preview[0] !== needle[0]) ? 1.0 : 0.0;
                                let fuzzyScore = (5 * matchRatio) - lengthPenalty - firstLetterPenalty;
                                if (fuzzyScore > 0)
                                    score = fuzzyScore;
                            }
                        }
                    }

                    if (score > 0) {
                        itemsToAppend.push({
                            entry: entry,
                            score: score
                        });
                    }
                }

                itemsToAppend.sort(function(a, b) {
                    if (a.score !== b.score)
                        return b.score - a.score;
                    return a.entry.preview.toLowerCase().localeCompare(b.entry.preview.toLowerCase());
                });

                itemsToAppend = itemsToAppend.map(function(item) {
                    return item.entry;
                });
            }

            if (itemsToAppend.length > 0) {
                cliphistModel.append(itemsToAppend);
            }

            if (list.count > 0) {
                list.positionViewAtBeginning();
            }

            if (root.popupMounted && root.popupTargetVisible && !popupEnterAnim.running && !popupExitAnim.running) {
                root._syncPopupOpenGeometry();
            }
        }

        function reload() {
            procList.exec(["cliphist", "list"]);
        }
    }

    Io.Process {
        id: procList
        stdout: Io.StdioCollector {
            id: collector
            waitForEnd: true
            onStreamFinished: {
                const lines = String(text || "").split("\n").filter(l => l.trim().length);
                const items = [];
                for (let i = 0; i < lines.length; i++) {
                    const e = listModel.lineToEntry(lines[i]);
                    if (e)
                        items.push(e);
                }
                listModel.all = items;
                listModel.applyFilter(search.text);
            }
        }
    }

    Io.Process {
        id: copyProc
    }

    QtObject {
        id: actions
        function shQuote(s) {
            return "'" + String(s).replace(/'/g, "'\\''") + "'";
        }
        function copyItem(line) {
            if (!line)
                return;
            const cmd = "printf %s " + shQuote(line) + " | cliphist decode | wl-copy";
            copyProc.exec(["sh", "-lc", cmd]);
            root._hidePopup();
        }

        function pasteItem(line) {
            const sh = `
printf %s ${shQuote(String(line))} | cliphist decode | wl-copy
if command -v wtype >/dev/null 2>&1; then wtype -M ctrl v -m ctrl; fi`;

            Io.execDetached(["sh", "-lc", sh]);
        }
        function deleteItem(line) {
            Io.execDetached(["sh", "-lc", "printf %s " + shQuote(String(line)) + " | cliphist delete"]);
            listModel.reload();
        }
        function wipeAll() {
            Io.execDetached(["cliphist", "wipe"]);
            listModel.reload();
        }
    }
}
