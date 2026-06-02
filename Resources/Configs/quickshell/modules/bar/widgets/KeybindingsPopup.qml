import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../theme" as ThemePkg

Item {
    id: root

    readonly property int panelWidth: 500
    readonly property int panelHeight: 640
    readonly property int panelMargin: 16
    readonly property int contentMargin: 22

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
    readonly property color accent2: ThemePkg.Theme.accent2
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property real popupOpenWidth: root.panelWidth
    readonly property real popupOpenHeight: root.panelHeight
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2

    property string searchQuery: ""
    property bool popupMounted: false
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.42
    property real popupCardScaleY: 0.24
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: popupOriginLift()

    function popupOriginLift() {
        return root.barPanelCenterY - (root.popupClosedHeight / 2);
    }

    function preparePopupOpen() {
        ThemePkg.Theme.globalCloseAllPopups();
        root.loadKeybindings();
        searchField.text = "";
        root.searchQuery = "";
        root.showPopup();
    }

    function showPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999)
            return;
        popupEnterAnim.stop();
        popupEnterAnim.start();
        Qt.callLater(function() {
            if (root.popupTargetVisible)
                searchField.forceActiveFocus();
        });
    }

    function hidePopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        popupExitAnim.start();
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalCloseShellPopups() {
            root.hidePopup();
        }
        function onGlobalCloseAllPopups() {
            root.hidePopup();
        }
        function onGlobalToggleKeybindings() {
            if (root.popupTargetVisible) {
                root.hidePopup();
            } else {
                root.preparePopupOpen();
            }
        }
    }

    ListModel { id: filteredModel }
    property var allBindings: []

    readonly property string keybindingsFile: Quickshell.env("HOME") + "/.config/hypr/conf/keybindings.lua"
    function loadKeybindings() {
        keybindingsReadProc.running = true;
    }

    Process {
        id: keybindingsReadProc
        command: ["cat", root.keybindingsFile]
        stdout: StdioCollector {
            id: keybindingsReadOut
            waitForEnd: true
            onStreamFinished: {
                root.parseKeybindings(text);
            }
        }
    }

    function parseKeybindings(rawText) {
        var lines = String(rawText || "").split("\n");
        var result = [];
        var currentCategory = "General";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();

            var luaMatch = line.match(/^--\s*@bind\s+(.+?)\s+::\s+(.+?)\s+::\s+(.+?)\s+::\s+(.+)$/);
            if (luaMatch) {
                result.push({
                    category: luaMatch[1].trim(),
                    keybind: formatLuaKeybind(luaMatch[2].trim()),
                    description: luaMatch[4].trim(),
                    dispatcher: luaMatch[3].trim(),
                    dispatchArgs: ""
                });
                continue;
            }

            var categoryMatch = line.match(/^#\s+(.+)$/);
            if (categoryMatch && !line.match(/^#\s*bind/i)) {
                var potentialCategory = categoryMatch[1].trim();
                if (potentialCategory.length > 0 && potentialCategory.length < 40 && !potentialCategory.startsWith("bind")) {
                    currentCategory = potentialCategory;
                    continue;
                }
            }

            if (!line.match(/^bind[emnr]*\s*=/))
                continue;

            var commentIdx = line.lastIndexOf("#");
            if (commentIdx < 0)
                continue;

            var description = line.substring(commentIdx + 1).trim();
            if (!description)
                continue;

            var bindPart = line.substring(0, commentIdx).trim();

            var eqIdx = bindPart.indexOf("=");
            if (eqIdx < 0)
                continue;

            var afterEq = bindPart.substring(eqIdx + 1).trim();
            var parts = afterEq.split(",");
            if (parts.length < 2)
                continue;

            var mods = parts[0].trim();
            var key = parts[1].trim();
            var dispatcher = (parts.length > 2) ? parts[2].trim() : "";
            var dispatchArgs = (parts.length > 3) ? parts.slice(3).join(",").trim() : "";

            var keybindStr = formatKeybind(mods, key);

            result.push({
                category: currentCategory,
                keybind: keybindStr,
                description: description,
                dispatcher: dispatcher,
                dispatchArgs: dispatchArgs
            });
        }

        root.allBindings = result;
        applyFilter("");
    }

    function formatKeybind(mods, key) {
        var modStr = String(mods || "");
        var keyStr = prettyKeyToken(key);

        modStr = modStr.replace(/\$mainMod/gi, "Super");
        modStr = modStr.replace(/SUPER/gi, "Super");
        modStr = modStr.replace(/SHIFT/gi, "Shift");
        modStr = modStr.replace(/CTRL/gi, "Ctrl");
        modStr = modStr.replace(/ALT/gi, "Alt");

        var modParts = modStr.split(/\s+/).filter(function(s) { return s.length > 0; });
        if (keyStr.length <= 0)
            return modParts.join(" + ");

        if (modParts.length > 0) {
            return modParts.join(" + ") + " + " + keyStr;
        }
        return keyStr;
    }

    function formatLuaKeybind(keys) {
        var parts = String(keys || "").split(/\s*\+\s*/).filter(function(s) { return s.length > 0; });
        var formatted = [];
        for (var i = 0; i < parts.length; i++)
            formatted.push(prettyKeyToken(parts[i]));
        return formatted.join(" + ");
    }

    function prettyKeyToken(key) {
        var keyStr = String(key || "").trim();

        keyStr = keyStr.replace(/\$mainMod/gi, "Super");
        keyStr = keyStr.replace(/^SUPER$/i, "Super");
        keyStr = keyStr.replace(/^SHIFT$/i, "Shift");
        keyStr = keyStr.replace(/^CTRL$/i, "Ctrl");
        keyStr = keyStr.replace(/^ALT$/i, "Alt");
        keyStr = keyStr.replace(/^XF86MonBrightnessUp$/i, "Brightness ↑");
        keyStr = keyStr.replace(/^XF86MonBrightnessDown$/i, "Brightness ↓");
        keyStr = keyStr.replace(/^XF86AudioRaiseVolume$/i, "Vol ↑");
        keyStr = keyStr.replace(/^XF86AudioLowerVolume$/i, "Vol ↓");
        keyStr = keyStr.replace(/^XF86AudioMute$/i, "Mute");
        keyStr = keyStr.replace(/^XF86AudioPlay$/i, "Play");
        keyStr = keyStr.replace(/^XF86AudioPause$/i, "Pause");
        keyStr = keyStr.replace(/^XF86AudioNext$/i, "Next");
        keyStr = keyStr.replace(/^XF86AudioPrev$/i, "Prev");
        keyStr = keyStr.replace(/^XF86AudioMicMute$/i, "Mic Mute");
        keyStr = keyStr.replace(/^XF86ScreenSaver$/i, "Lock");
        keyStr = keyStr.replace(/^PRINT$/i, "PrtSc");
        keyStr = keyStr.replace(/^mouse:272$/i, "LMB");
        keyStr = keyStr.replace(/^mouse:273$/i, "RMB");
        keyStr = keyStr.replace(/^mouse_down$/i, "Scroll ↓");
        keyStr = keyStr.replace(/^mouse_up$/i, "Scroll ↑");
        keyStr = keyStr.replace(/^Tab$/i, "Tab");
        keyStr = keyStr.replace(/^Return$/i, "Enter");
        keyStr = keyStr.replace(/^space$/i, "Space");
        keyStr = keyStr.replace(/^left$/i, "←");
        keyStr = keyStr.replace(/^right$/i, "→");
        keyStr = keyStr.replace(/^up$/i, "↑");
        keyStr = keyStr.replace(/^down$/i, "↓");
        keyStr = keyStr.replace(/^code:(\d+)$/i, "Fn:$1");

        return keyStr;
    }

    function applyFilter(query) {
        filteredModel.clear();
        var needle = String(query || "").toLowerCase();
        var items = root.allBindings;
        var scored = [];

        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            if (!needle) {
                scored.push({ item: item, score: 0 });
                continue;
            }

            var desc = item.description.toLowerCase();
            var kb = item.keybind.toLowerCase();
            var cat = item.category.toLowerCase();
            var score = -1;

            if (desc === needle || kb === needle) {
                score = 100;
            } else if (desc.startsWith(needle) || kb.startsWith(needle)) {
                score = 50;
            } else if (desc.indexOf(needle) >= 0 || kb.indexOf(needle) >= 0 || cat.indexOf(needle) >= 0) {
                score = 10;
            } else {
                var subIdx = 0;
                for (var j = 0; j < desc.length && subIdx < needle.length; j++) {
                    if (needle[subIdx] === desc[j]) subIdx++;
                }
                if (subIdx === needle.length) {
                    score = 8;
                } else if (needle.length >= 3) {
                    var matches = 0;
                    var nameArray = desc.split("");
                    for (var k = 0; k < needle.length; k++) {
                        var idx = nameArray.indexOf(needle[k]);
                        if (idx !== -1) {
                            matches++;
                            nameArray[idx] = null;
                        }
                    }
                    var matchRatio = matches / needle.length;
                    if (matchRatio >= 0.75) {
                        var lengthPenalty = Math.abs(needle.length - desc.length) / Math.max(desc.length, 1);
                        var firstLetterPenalty = (desc[0] !== needle[0]) ? 1.0 : 0.0;
                        var fuzzyScore = (5 * matchRatio) - lengthPenalty - firstLetterPenalty;
                        if (fuzzyScore > 0) score = fuzzyScore;
                    }
                }

                if (score < 1) {
                    subIdx = 0;
                    for (j = 0; j < kb.length && subIdx < needle.length; j++) {
                        if (needle[subIdx] === kb[j]) subIdx++;
                    }
                    if (subIdx === needle.length) score = 6;
                }
            }

            if (score > 0) {
                scored.push({ item: item, score: score });
            }
        }

        if (needle) {
            scored.sort(function(a, b) {
                if (a.score !== b.score) return b.score - a.score;
                return a.item.description.localeCompare(b.item.description);
            });
        }

        for (i = 0; i < scored.length; i++) {
            var s = scored[i].item;
            filteredModel.append({
                category: s.category,
                keybind: s.keybind,
                description: s.description,
                dispatcher: s.dispatcher,
                dispatchArgs: s.dispatchArgs
            });
        }

        if (list.count > 0)
            list.positionViewAtBeginning();
    }

    function executeKeybind(dispatcher, dispatchArgs) {
        if (!dispatcher)
            return;
        root.hidePopup();
        if (String(dispatcher).indexOf("hl.") === 0) {
            Quickshell.execDetached(["hyprctl", "dispatch", String(dispatcher)]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", dispatcher, String(dispatchArgs || "")]);
        }
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
                    win.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
                }
            } catch (e) {}
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            enabled: root.popupTargetVisible
            onActivated: root.hidePopup()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hidePopup()
        }

        SequentialAnimation {
            id: popupEnterAnim
            running: false

            onStopped: {
                if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                    root.popupMounted = false;
            }

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
                NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
                NumberAnimation { target: root; property: "popupCardLift"; to: root.popupOriginLift(); duration: 280; easing.type: Easing.InCubic }
            }
        }

        Item {
            id: cardShell
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: root.panelMargin
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
                focus: true
                width: root.panelWidth
                height: root.panelHeight
                radius: root.popupCardRadius
                color: root.base
                border.color: root.panelBorderColor
                border.width: 1
                clip: true
                anchors.top: parent.top
                anchors.right: parent.right

                AnimatedBorder {
                    anchors.fill: parent
                    radius: parent.radius
                    borderWidth: parent.border.width
                    accentColor: root.accent
                }

                property real orbitAngle: 0
                NumberAnimation on orbitAngle {
                    from: 0
                    to: Math.PI * 2
                    duration: 90000
                    loops: Animation.Infinite
                    running: root.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                }

                Rectangle {
                    width: parent.width * 0.72
                    height: width
                    radius: width / 2
                    x: parent.width * 0.55 - width / 2 + Math.cos(card.orbitAngle) * 70
                    y: -height * 0.25 + Math.sin(card.orbitAngle * 1.25) * 40
                    color: root.accent
                    opacity: 0.045
                }

                Rectangle {
                    width: parent.width * 0.55
                    height: width
                    radius: width / 2
                    x: parent.width * 0.2 - width / 2 + Math.cos(card.orbitAngle * 1.4 + 1.0) * 48
                    y: parent.height * 0.55 - height / 2 + Math.sin(card.orbitAngle * 1.1) * 56
                    color: root.accent2
                    opacity: 0.03
                }

                Text {
                    id: parallaxIcon
                    anchors.centerIn: parent
                    property real drift: 0
                    SequentialAnimation on drift {
                        loops: Animation.Infinite
                        running: root.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
                        NumberAnimation { to: -12; duration: 6000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                    }
                    transform: Translate { y: parallaxIcon.drift }
                    text: "󰌌"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 320
                    color: root.accent
                    opacity: 0.03 + (0.01 * Math.sin(card.orbitAngle * 3.0))
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.contentMargin
                    spacing: 14
                    z: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "󰌌"
                            color: root.accent
                            font.pixelSize: 20
                            font.family: "Iosevka Nerd Font"
                        }

                        Text {
                            text: "Keybindings"
                            color: root.text
                            font.pixelSize: 19
                            font.family: "Fira Sans"
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Text {
                            text: filteredModel.count + " bindings"
                            color: root.subtext0
                            font.pixelSize: 12
                            font.family: "Fira Sans"
                        }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "Search keybindings…"
                        color: root.text
                        placeholderTextColor: root.overlay1
                        font.pixelSize: 13
                        font.family: "Fira Sans"

                        background: Rectangle {
                            color: "#0dffffff"
                            border.color: searchField.activeFocus ? root.accent : "#1affffff"
                            border.width: 1
                            radius: 10
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.applyFilter(text);
                        }

                        Keys.onEscapePressed: {
                            if (text !== "") {
                                text = "";
                            } else {
                                root.hidePopup();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.panelBorderColor
                        opacity: 0.5
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: filteredModel

                        ThemePkg.FastScrollHandler {
                            anchors.fill: parent
                            flickable: list
                        }

                        section.property: "category"
                        section.delegate: Item {
                            required property string section
                            width: list.width - 16
                            height: 32

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: parent.section
                                color: root.accent
                                font.pixelSize: 12
                                font.family: "Fira Sans"
                                font.weight: Font.Bold
                                font.capitalization: Font.AllUppercase
                                opacity: 0.8
                            }
                        }

                        delegate: Rectangle {
                            id: kbRow
                            width: list.width - 16
                            height: 44
                            radius: 14
                            color: hovered ? "#0affffff" : "#05ffffff"
                            border.width: 1
                            border.color: hovered ? root.accent : "#1affffff"

                            property bool hovered: false

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: Math.max(kbText.implicitWidth + 20, 80)
                                    Layout.preferredHeight: 28
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 8
                                    color: ThemePkg.Theme.withAlpha(root.accent, kbRow.hovered ? 0.18 : 0.12)
                                    border.color: ThemePkg.Theme.withAlpha(root.accent, 0.35)
                                    border.width: 1

                                    Text {
                                        id: kbText
                                        anchors.centerIn: parent
                                        text: model.keybind
                                        color: root.accent
                                        font.pixelSize: 11
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: model.description
                                    color: root.text
                                    font.pixelSize: 13
                                    font.family: "Fira Sans"
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: kbRow.hovered = true
                                onExited: kbRow.hovered = false
                                onClicked: root.executeKeybind(model.dispatcher, model.dispatchArgs)
                            }
                        }

                        header: Item {
                            width: list.width
                            height: filteredModel.count <= 0 ? 200 : 0
                            visible: filteredModel.count <= 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: filteredModel.count <= 0

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰌌"
                                    color: root.subtext0
                                    font.pixelSize: 42
                                    font.family: "Iosevka Nerd Font"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery ? "No keybindings match your search." : "No keybindings found."
                                    color: root.text
                                    font.pixelSize: 14
                                    font.family: "Fira Sans"
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery ? "Try a different query." : "Check " + root.keybindingsFile
                                    color: root.subtext0
                                    font.pixelSize: 12
                                    font.family: "Fira Sans"
                                }
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
                                color: root.panelBorderColor
                                border.color: root.panelBorderColor
                                opacity: vbar.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: root.panelBorderColor
                                color: root.accent
                            }
                        }
                    }
                }
            }
        }
    }
}
