import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../../theme" as ThemePkg

Item {
    id: root
    focus: true
    anchors.fill: parent

    readonly property int panelWidth: 560
    readonly property int panelHeight: 560
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
    readonly property color danger: ThemePkg.Theme.danger
    readonly property color success: ThemePkg.Theme.success
    readonly property color warning: ThemePkg.Theme.warning
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
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

    property var overlaySwitcher: null

    readonly property url activeSoundsFolderUrl: Qt.resolvedUrl("../../notifications/sounds")
    readonly property url alternativeSoundsFolderUrl: Qt.resolvedUrl("../../notifications/sounds/alternatives")
    readonly property string activeSoundsDir: decodeURIComponent(String(activeSoundsFolderUrl).replace("file://", ""))
    readonly property string alternativeSoundsDir: decodeURIComponent(String(alternativeSoundsFolderUrl).replace("file://", ""))
    readonly property string notificationScriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/notifications"
    readonly property string notificationRepoScriptsDir: Quickshell.env("HOME") + "/.config/hyprdots/Resources/Configs/hypr/scripts/quickshell/notifications"
    readonly property var soundNameFilters: ["*.wav", "*.ogg", "*.oga", "*.mp3", "*.flac", "*.aac", "*.m4a"]

    property bool busy: false
    property string statusMessage: ""
    property bool statusIsError: false
    property string previewLabel: ""
    property real introProgress: 0.0
    property var overlayScreen: null
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

    Component.onCompleted: {
        popupTargetVisible = true;
        introProgress = 1.0;
        if (ThemePkg.Theme.popupAnimationsEnabled)
            popupEnterAnim.start();
        else
            root.openInstant();
    }

    onHostLoaderOpacityChanged: {
        if (hostLoaderOpacity < lastHostLoaderOpacity - 0.001 && popupTargetVisible) {
            popupTargetVisible = false;
            popupEnterAnim.stop();
            if (!ThemePkg.Theme.popupAnimationsEnabled) {
                root.closeInstant();
                lastHostLoaderOpacity = hostLoaderOpacity;
                return;
            }
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
        if (!ThemePkg.Theme.popupAnimationsEnabled) {
            root.closeInstant();
            return;
        }
        if (!popupExitAnim.running)
            popupExitAnim.start();
    }

    function cancelOverlayClose() {
        popupTargetVisible = true;
        popupExitAnim.stop();
        popupEnterAnim.stop();
        if (!ThemePkg.Theme.popupAnimationsEnabled) {
            root.openInstant();
            return;
        }
        popupEnterAnim.start();
    }

    Behavior on introProgress {
        NumberAnimation {
            duration: 360
            easing.type: Easing.OutCubic
        }
    }

    function popupOriginLift() {
        return root.barPanelCenterY - (root.popupClosedHeight / 2);
    }

    function openInstant() {
        popupExitAnim.stop();
        popupEnterAnim.stop();
        popupTargetVisible = true;
        ThemePkg.Theme.setPopupCardOpen(root);
    }

    function closeInstant() {
        popupEnterAnim.stop();
        popupExitAnim.stop();
        popupTargetVisible = false;
        ThemePkg.Theme.setPopupCardClosed(root);
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

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function prettySoundName(fileName) {
        var raw = String(fileName || "");
        var trimmed = raw.replace(/\.[^.]+$/, "");
        return trimmed.replace(/[_-]+/g, " ").trim();
    }

    function status(text, isError) {
        root.statusMessage = String(text || "");
        root.statusIsError = !!isError;
    }

    function notifyUser(summary, body) {
        ThemePkg.Theme.notify(String(summary || ""), String(body || ""), "Notification Sounds", "", ({}));
    }

    function refreshModels() {
        activeSoundsModel.reload();
        alternativeSoundsModel.reload();
    }

    function previewSound(fileUrl, fileName) {
        if (!fileUrl)
            return;
        previewPlayer.stop();
        previewPlayer.source = fileUrl;
        previewPlayer.play();
        root.previewLabel = root.prettySoundName(fileName);
    }

    function stopPreview() {
        previewPlayer.stop();
        root.previewLabel = "";
    }

    function openAddSoundPicker() {
        root.stopPreview();

        var deployedScript = root.notificationScriptsDir + "/notification_sound_portal_picker.py";
        var repoScript = root.notificationRepoScriptsDir + "/notification_sound_portal_picker.py";
        var cmd = "script=" + root.shellQuote(deployedScript) + "; " +
            "[ -f \"$script\" ] || script=" + root.shellQuote(repoScript) + "; " +
            "exec python3 \"$script\" " + root.shellQuote(root.activeSoundsDir) + " " + root.shellQuote(root.alternativeSoundsDir);

        Quickshell.execDetached(["bash", "-lc", cmd]);

        if (root.overlaySwitcher && typeof root.overlaySwitcher.close === "function")
            root.overlaySwitcher.close();
        else
            root.beginOverlayClose();
    }

    function activateSound(filePath, fileName) {
        if (root.busy || !filePath)
            return;

        var cmd = [
            "bash",
            "-c",
            "set -eu; " +
            "sounds_dir=" + root.shellQuote(root.activeSoundsDir) + "; " +
            "alternatives_dir=" + root.shellQuote(root.alternativeSoundsDir) + "; " +
            "selected_path=" + root.shellQuote(filePath) + "; " +
            "mkdir -p \"$alternatives_dir\"; " +
            "selected_name=$(basename \"$selected_path\"); " +
            "shopt -s nullglob; " +
            "for existing in \"$sounds_dir\"/*; do " +
                "[ -f \"$existing\" ] || continue; " +
                "ext=\"${existing##*.}\"; ext=\"${ext,,}\"; " +
                "case \"$ext\" in wav|ogg|oga|mp3|flac|aac|m4a) ;; *) continue ;; esac; " +
                "if [ \"$(basename \"$existing\")\" != \"$selected_name\" ]; then mv -f \"$existing\" \"$alternatives_dir/$(basename \"$existing\")\"; fi; " +
            "done; " +
            "if [ -f \"$alternatives_dir/$selected_name\" ]; then mv -f \"$alternatives_dir/$selected_name\" \"$sounds_dir/$selected_name\"; fi"
        ];

        soundActionProc.successMessage = "Active notification sound set to " + root.prettySoundName(fileName) + ".";
        soundActionProc.exec(cmd);
    }

    function removeSound(filePath, fileName) {
        if (root.busy || !filePath)
            return;

        root.stopPreview();
        soundActionProc.successMessage = "Removed " + root.prettySoundName(fileName) + ".";
        soundActionProc.exec(["bash", "-lc", "rm -f -- " + root.shellQuote(filePath)]);
    }

    FolderListModel {
        id: activeSoundsModel
        folder: root.activeSoundsFolderUrl
        showDirs: false
        sortField: FolderListModel.Name
        nameFilters: root.soundNameFilters
    }

    FolderListModel {
        id: alternativeSoundsModel
        folder: root.alternativeSoundsFolderUrl
        showDirs: false
        sortField: FolderListModel.Name
        nameFilters: root.soundNameFilters
    }

    Process {
        id: soundActionProc
        property string successMessage: ""

        stdout: StdioCollector {
            id: soundActionOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: soundActionErr
            waitForEnd: true
        }

        onRunningChanged: root.busy = running

        onExited: function(exitCode, exitStatus) {
            var stderrText = String(soundActionErr.text || "").trim();
            var stdoutText = String(soundActionOut.text || "").trim();
            if (exitCode === 0) {
                root.status(soundActionProc.successMessage, false);
                root.refreshModels();
            } else if (exitCode === 17) {
                root.status("A notification sound with the same name already exists.", true);
                root.notifyUser("Duplicate notification sound", "A file with the same name is already present.");
            } else {
                root.status((stderrText || stdoutText || "Notification sound operation failed."), true);
            }
        }
    }

    MediaPlayer {
        id: previewPlayer
        audioOutput: AudioOutput {
            volume: 1.0
        }
        onPlaybackStateChanged: {
            if (playbackState !== MediaPlayer.PlayingState)
                root.previewLabel = "";
        }
    }

    Item {
        id: panelShell
        width: root.popupCardWidth
        height: root.popupCardHeight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelMargin
        anchors.rightMargin: root.panelMargin
        opacity: root.popupCardOpacity
        transform: [
            Scale {
                origin.x: panelShell.width / 2
                origin.y: panelShell.height / 2
                xScale: root.popupCardScaleX
                yScale: root.popupCardScaleY
            },
            Translate { y: root.popupCardLift }
        ]

        Rectangle {
            id: panel
            width: root.panelWidth
            height: root.panelHeight
            radius: root.popupCardRadius
            color: root.base
            border.color: root.panelBorderColor
            border.width: 1
            anchors.top: parent.top
            anchors.right: parent.right
            clip: true

            AnimatedBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: root.accent
            }

            opacity: root.introProgress
            transform: Scale {
                origin.x: panel.width
                origin.y: 0
                xScale: 0.975 + (0.025 * root.introProgress)
                yScale: 0.975 + (0.025 * root.introProgress)
            }

            property real orbitAngle: 0
            NumberAnimation on orbitAngle {
                from: 0
                to: Math.PI * 2
                duration: 90000
                loops: Animation.Infinite
                running: true
            }

            Rectangle {
                width: parent.width * 0.72
                height: width
                radius: width / 2
                x: parent.width * 0.55 - width / 2 + Math.cos(panel.orbitAngle) * 70
                y: -height * 0.25 + Math.sin(panel.orbitAngle * 1.25) * 40
                color: root.accent
                opacity: 0.045
            }

            Rectangle {
                width: parent.width * 0.55
                height: width
                radius: width / 2
                x: parent.width * 0.2 - width / 2 + Math.cos(panel.orbitAngle * 1.4 + 1.0) * 48
                y: parent.height * 0.55 - height / 2 + Math.sin(panel.orbitAngle * 1.1) * 56
                color: root.accent2
                opacity: 0.03
            }

            Text {
                anchors.centerIn: parent
                text: "󰂚"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 300
                color: root.accent
                opacity: 0.03 + (0.01 * Math.sin(panel.orbitAngle * 3.0))
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.contentMargin
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                Text {
                    text: "Active"
                    color: root.text
                    font.pixelSize: 18
                    font.family: "Fira Sans"
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: activeSoundsModel.count > 0 ? Math.min(230, activeSoundsModel.count * 76 + 2) : 100
                    radius: 18
                    color: "transparent"
                    border.color: "transparent"
                    border.width: 0

                    ScrollView {
                        id: activeScroll
                        anchors.fill: parent
                        clip: true

                        ThemePkg.FastScrollHandler {
                            anchors.fill: parent
                            flickable: activeScroll.contentItem
                        }

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            id: activeVBar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || activeScroll.contentItem.moving

                            background: Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: root.panelBorderColor
                                border.color: root.panelBorderColor
                                opacity: activeVBar.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: root.panelBorderColor
                                color: root.accent
                            }
                        }

                        Column {
                            width: activeScroll.availableWidth
                            spacing: 8

                            Repeater {
                                model: activeSoundsModel

                                delegate: SoundRow {
                                    width: parent.width
                                    iconGlyph: "󰂚"
                                    label: root.prettySoundName(fileName)
                                    detail: "sounds/" + fileName
                                    accentColor: root.success
                                    playing: previewPlayer.playbackState === MediaPlayer.PlayingState && String(previewPlayer.source) === String(fileUrl)
                                    active: true
                                    busy: root.busy
                                    onPreviewRequested: root.previewSound(fileUrl, fileName)
                                    onPrimaryRequested: root.activateSound(filePath, fileName)
                                    onRemoveRequested: root.removeSound(filePath, fileName)
                                }
                            }

                            Item {
                                width: parent.width
                                height: 1
                                visible: activeSoundsModel.count <= 0
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: activeSoundsModel.count <= 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰝚"
                            color: root.subtext0
                            font.pixelSize: 34
                            font.family: "Iosevka Nerd Font"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Bundled fallback will be used."
                            color: root.subtext0
                            font.pixelSize: 13
                            font.family: "Fira Sans"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Alternatives"
                        color: root.text
                        font.pixelSize: 18
                        font.family: "Fira Sans"
                        font.weight: Font.DemiBold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ActionButton {
                        label: root.previewLabel !== "" ? "Stop Preview" : "Add Sound"
                        icon: root.previewLabel !== "" ? "󰓛" : "󰐕"
                        accentColor: root.previewLabel !== "" ? root.warning : root.accent
                        enabled: !root.busy
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            if (root.previewLabel !== "")
                                root.stopPreview();
                            else
                                root.openAddSoundPicker();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.statusMessage !== ""
                    radius: 12
                    color: root.statusIsError
                        ? ThemePkg.Theme.withAlpha(root.danger, 0.14)
                        : ThemePkg.Theme.withAlpha(root.success, 0.12)
                    border.width: 1
                    border.color: root.statusIsError
                        ? ThemePkg.Theme.withAlpha(root.danger, 0.4)
                        : ThemePkg.Theme.withAlpha(root.success, 0.35)
                    implicitHeight: statusLabel.implicitHeight + 18

                    Text {
                        id: statusLabel
                        anchors.fill: parent
                        anchors.margins: 9
                        text: root.statusMessage
                        wrapMode: Text.Wrap
                        color: root.text
                        font.pixelSize: 12
                        font.family: "Fira Sans"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: "transparent"
                    border.color: "transparent"
                    border.width: 0

                    ScrollView {
                        id: alternativesScroll
                        anchors.fill: parent
                        clip: true

                        ThemePkg.FastScrollHandler {
                            anchors.fill: parent
                            flickable: alternativesScroll.contentItem
                        }

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            id: alternativesVBar
                            parent: alternativesScroll
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || alternativesScroll.contentItem.moving

                            background: Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: root.panelBorderColor
                                border.color: root.panelBorderColor
                                opacity: alternativesVBar.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: root.panelBorderColor
                                color: root.accent
                            }
                        }

                        Column {
                            width: alternativesScroll.availableWidth
                            spacing: 8

                            Repeater {
                                model: alternativeSoundsModel

                                delegate: SoundRow {
                                    width: parent.width
                                    iconGlyph: "󰓃"
                                    label: root.prettySoundName(fileName)
                                    detail: "alternatives/" + fileName
                                    accentColor: root.accent2
                                    playing: previewPlayer.playbackState === MediaPlayer.PlayingState && String(previewPlayer.source) === String(fileUrl)
                                    active: false
                                    busy: root.busy
                                    onPreviewRequested: root.previewSound(fileUrl, fileName)
                                    onPrimaryRequested: root.activateSound(filePath, fileName)
                                    onRemoveRequested: root.removeSound(filePath, fileName)
                                }
                            }

                            Item {
                                width: parent.width
                                height: 1
                                visible: alternativeSoundsModel.count <= 0
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: alternativeSoundsModel.count <= 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰈙"
                            color: root.subtext0
                            font.pixelSize: 36
                            font.family: "Iosevka Nerd Font"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No alternatives yet."
                            color: root.text
                            font.pixelSize: 15
                            font.family: "Fira Sans"
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Import one and it will appear here."
                            color: root.subtext0
                            font.pixelSize: 13
                            font.family: "Fira Sans"
                        }
                    }
                }
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: actionBtnRoot
        implicitWidth: 144
        implicitHeight: 38
        radius: 12

        property string label: ""
        property string icon: ""
        property color accentColor: root.accent
        property bool enabled: true

        signal clicked

        color: enabled
            ? (actionMouse.containsMouse ? ThemePkg.Theme.withAlpha(accentColor, 0.2) : ThemePkg.Theme.withAlpha(accentColor, 0.14))
            : ThemePkg.Theme.withAlpha(root.overlay0, 0.18)
        border.color: enabled
            ? ThemePkg.Theme.withAlpha(accentColor, actionMouse.containsMouse ? 0.7 : 0.45)
            : root.overlay0
        border.width: 1
        opacity: enabled ? 1.0 : 0.5

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: actionBtnRoot.icon
                color: actionBtnRoot.enabled ? actionBtnRoot.accentColor : root.subtext0
                font.pixelSize: 16
                font.family: "Iosevka Nerd Font"
                renderType: Text.QtRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: actionBtnRoot.label
                color: root.text
                font.pixelSize: 13
                font.family: "Fira Sans"
                font.weight: Font.DemiBold
                renderType: Text.QtRendering
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: actionBtnRoot.enabled
            hoverEnabled: true
            cursorShape: actionBtnRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: actionBtnRoot.clicked()
        }
    }

    component MiniActionButton: Rectangle {
        id: miniRoot
        width: 34
        height: 34
        radius: 10

        property string icon: ""
        property string tip: ""
        property color accentColor: root.accent
        property bool enabled: true

        signal clicked

        color: enabled
            ? (miniMouse.containsMouse ? ThemePkg.Theme.withAlpha(accentColor, 0.24) : ThemePkg.Theme.withAlpha(accentColor, 0.16))
            : ThemePkg.Theme.withAlpha(root.overlay0, 0.14)
        border.color: enabled
            ? ThemePkg.Theme.withAlpha(accentColor, miniMouse.containsMouse ? 0.72 : 0.45)
            : root.overlay0
        border.width: 1
        opacity: enabled ? 1.0 : 0.45

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            anchors.centerIn: parent
            text: miniRoot.icon
            color: miniRoot.enabled ? root.text : root.subtext0
            font.pixelSize: 16
            font.family: "Iosevka Nerd Font"
        }

        MouseArea {
            id: miniMouse
            anchors.fill: parent
            enabled: miniRoot.enabled
            hoverEnabled: true
            cursorShape: miniRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: miniRoot.clicked()
        }
    }

    component SoundRow: Rectangle {
        id: rowRoot
        height: 68
        radius: 14
        color: active
            ? ThemePkg.Theme.withAlpha(accentColor, 0.2)
            : (rowHover.hovered ? "#0affffff" : "#05ffffff")
        border.color: active
            ? ThemePkg.Theme.withAlpha(accentColor, 0.45)
            : (rowHover.hovered ? root.accent : "#1affffff")
        border.width: 1

        property string iconGlyph: ""
        property string label: ""
        property string detail: ""
        property color accentColor: root.accent
        property bool active: false
        property bool busy: false
        property bool playing: false

        signal previewRequested
        signal primaryRequested
        signal removeRequested

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: ThemePkg.Theme.withAlpha(rowRoot.accentColor, 0.16)
                border.color: ThemePkg.Theme.withAlpha(rowRoot.accentColor, 0.32)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: rowRoot.iconGlyph
                    color: rowRoot.accentColor
                    font.pixelSize: 18
                    font.family: "Iosevka Nerd Font"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: rowRoot.label
                        color: root.text
                        font.pixelSize: 14
                        font.family: "Fira Sans Semibold"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                }

                Text {
                    Layout.fillWidth: true
                    text: rowRoot.playing ? "Previewing now" : rowRoot.detail
                    color: rowRoot.playing ? rowRoot.accentColor : root.subtext0
                    font.pixelSize: 12
                    font.family: "Fira Sans"
                    elide: Text.ElideRight
                }
            }

            MiniActionButton {
                Layout.alignment: Qt.AlignVCenter
                icon: rowRoot.playing ? "󰓛" : "󰐊"
                tip: rowRoot.playing ? "Stop preview" : "Preview sound"
                accentColor: rowRoot.accentColor
                enabled: !rowRoot.busy
                onClicked: {
                    if (rowRoot.playing)
                        root.stopPreview();
                    else
                        rowRoot.previewRequested();
                }
            }

            MiniActionButton {
                Layout.alignment: Qt.AlignVCenter
                icon: rowRoot.active ? "󰄬" : "󰌑"
                tip: rowRoot.active ? "Already active" : "Make active"
                accentColor: rowRoot.active ? root.success : rowRoot.accentColor
                enabled: !rowRoot.busy && !rowRoot.active
                onClicked: rowRoot.primaryRequested()
            }

            MiniActionButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "󰩺"
                tip: "Remove sound"
                accentColor: root.danger
                enabled: !rowRoot.busy
                onClicked: rowRoot.removeRequested()
            }
        }

        HoverHandler {
            id: rowHover
        }
    }
}
