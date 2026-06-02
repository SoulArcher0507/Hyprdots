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

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape && root.pickerVisible) {
            root.closeAddSoundPicker();
            event.accepted = true;
        }
    }

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
    readonly property real popupClosedWidth: root.panelWidth - 44
    readonly property real popupClosedHeight: root.panelHeight - 28
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 34
    readonly property int overlayEnterDuration: 405
    readonly property int overlayExitDuration: 305
    readonly property bool overlayOwnsCloseAnimation: true

    readonly property url activeSoundsFolderUrl: Qt.resolvedUrl("../../notifications/sounds")
    readonly property url alternativeSoundsFolderUrl: Qt.resolvedUrl("../../notifications/sounds/alternatives")
    readonly property string activeSoundsDir: decodeURIComponent(String(activeSoundsFolderUrl).replace("file://", ""))
    readonly property string alternativeSoundsDir: decodeURIComponent(String(alternativeSoundsFolderUrl).replace("file://", ""))
    readonly property var soundNameFilters: ["*.wav", "*.ogg", "*.oga", "*.mp3", "*.flac", "*.aac", "*.m4a"]

    property bool busy: false
    property string statusMessage: ""
    property bool statusIsError: false
    property string previewLabel: ""
    property real introProgress: 0.0
    property var overlayScreen: null
    property bool pickerVisible: false
    onPickerVisibleChanged: if (pickerVisible) root.forceActiveFocus()
    property bool pickerMounted: false
    property bool pickerTargetVisible: false
    property real pickerCardOpacity: 0.0
    property real pickerCardScaleX: 0.91
    property real pickerCardScaleY: 0.79
    property real pickerCardWidth: 596
    property real pickerCardHeight: 532
    property real pickerCardRadius: 34
    property real pickerCardLift: 18
    property url pickerFolderUrl: "file://" + Quickshell.env("HOME")
    property string pickerSelectedPath: ""
    property string pickerSelectedName: ""
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

    Component.onCompleted: {
        popupTargetVisible = true;
        introProgress = 1.0;
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

    Behavior on introProgress {
        NumberAnimation {
            duration: 360
            easing.type: Easing.OutCubic
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

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function stringValue(value) {
        if (value === undefined || value === null)
            return "";
        if (typeof value === "string")
            return value;
        if (value.toString)
            return value.toString();
        return String(value);
    }

    function localPathFromUrl(value) {
        var text = root.stringValue(value).trim();
        var wrappedUrlMatch = text.match(/^(?:QUrl|url)\(\"(.*)\"\)$/);
        if (wrappedUrlMatch && wrappedUrlMatch.length > 1)
            text = wrappedUrlMatch[1];
        if (text.startsWith("file://")) {
            var path = text.substring(7);
            if (path.startsWith("//")) path = path.substring(1);
            return decodeURIComponent(path);
        }
        return text;
    }

    function isDialogSelectionUsable(value) {
        var text = root.localPathFromUrl(value).trim();
        return text !== "" && text !== "." && text !== "/";
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

    function soundFileExists(fileName) {
        var target = String(fileName || "").trim().toLowerCase();
        var i = 0;
        if (!target)
            return false;

        for (i = 0; i < activeSoundsModel.count; ++i) {
            if (String(activeSoundsModel.get(i, "fileName") || "").trim().toLowerCase() === target)
                return true;
        }

        for (i = 0; i < alternativeSoundsModel.count; ++i) {
            if (String(alternativeSoundsModel.get(i, "fileName") || "").trim().toLowerCase() === target)
                return true;
        }

        return false;
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
        root.pickerFolderUrl = "file://" + Quickshell.env("HOME");
        root.pickerSelectedPath = "";
        root.pickerSelectedName = "";
        root.pickerMounted = true;
        root.pickerTargetVisible = true;
        root.pickerVisible = true;
        pickerExitAnim.stop();
        root.pickerCardOpacity = 0.0;
        root.pickerCardScaleX = 0.91;
        root.pickerCardScaleY = 0.79;
        root.pickerCardWidth = 596;
        root.pickerCardHeight = 532;
        root.pickerCardRadius = 34;
        root.pickerCardLift = 18;
        pickerEnterAnim.stop();
        pickerEnterAnim.start();
        pickerFolderModel.reload();
    }

    function closeAddSoundPicker() {
        root.pickerTargetVisible = false;
        root.pickerSelectedPath = "";
        root.pickerSelectedName = "";
        if (!root.pickerMounted && root.pickerCardOpacity <= 0.001) {
            root.pickerVisible = false;
            return;
        }
        pickerEnterAnim.stop();
        if (!pickerExitAnim.running)
            pickerExitAnim.start();
    }

    function openPickerFolder(folderUrl) {
        if (!folderUrl)
            return;
        root.pickerFolderUrl = folderUrl;
        root.pickerSelectedPath = "";
        root.pickerSelectedName = "";
        pickerFolderModel.reload();
    }

    function selectPickerEntry(filePath, fileName, isDir, fileUrl) {
        if (isDir) {
            root.openPickerFolder(fileUrl);
            return;
        }

        root.pickerSelectedPath = String(filePath || "");
        root.pickerSelectedName = String(fileName || "");
    }

    function confirmPickerSelection() {
        if (!root.pickerSelectedPath) {
            root.status("Select an audio file to import.", true);
            return;
        }

        var selectedPath = root.pickerSelectedPath;
        root.closeAddSoundPicker();
        root.addSoundFromDialog(selectedPath);
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

    function addSoundFromDialog(selectedUrl) {
        if (!selectedUrl) return;

        var sourcePath = root.localPathFromUrl(selectedUrl);
        var sourceName = String(sourcePath).split("/").pop();

        if (!sourcePath || sourcePath === sourceName) {
            root.status("The selected file path could not be resolved.", true);
            return;
        }

        var cmd = [
            "bash",
            "-c",
            "set -eu; " +
            "src=" + root.shellQuote(sourcePath) + "; " +
            "dest_dir=" + root.shellQuote(root.alternativeSoundsDir) + "; " +
            "active_dir=" + root.shellQuote(root.activeSoundsDir) + "; " +
            "if [ ! -f \"$src\" ]; then echo \"Selected file not found: $src\" >&2; exit 2; fi; " +
            "mkdir -p \"$dest_dir\"; " +
            "base=$(basename \"$src\"); " +
            "ext=\"${base##*.}\"; ext=\"${ext,,}\"; " +
            "case \"$ext\" in wav|ogg|oga|mp3|flac|aac|m4a) ;; *) echo \"Unsupported file type: $ext\" >&2; exit 1 ;; esac; " +
            "if [ -e \"$dest_dir/$base\" ] || [ -e \"$active_dir/$base\" ]; then echo \"Duplicate sound name: $base\" >&2; exit 17; fi; " +
            "cp -f \"$src\" \"$dest_dir/$base\""
        ];

        soundActionProc.successMessage = "Added " + sourceName + " to alternatives.";
        soundActionProc.exec(cmd);
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

    FolderListModel {
        id: pickerFolderModel
        folder: root.pickerFolderUrl
        rootFolder: "file:///"
        showDirs: true
        showFiles: true
        showDirsFirst: true
        showDotAndDotDot: false
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
        id: pickerOverlay
        visible: root.pickerMounted
        anchors.fill: parent
        z: 80

        /* Shortcut removed in favor of Keys.onPressed for better compatibility with Bar overlays */

        MouseArea {
            anchors.fill: parent
            z: 0
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeAddSoundPicker()
        }

        Rectangle {
            id: pickerCard
            z: 1
            width: root.pickerCardWidth
            height: root.pickerCardHeight
            radius: root.pickerCardRadius
            color: root.base
            border.color: root.panelBorderColor
            border.width: 1
            clip: true
            opacity: root.pickerCardOpacity
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: root.panelMargin + root.pickerCardLift
            anchors.rightMargin: root.panelWidth + root.panelMargin + 24

            transform: Scale {
                origin.x: pickerCard.width / 2
                origin.y: pickerCard.height / 2
                xScale: root.pickerCardScaleX
                yScale: root.pickerCardScaleY
            }

            AnimatedBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: root.accent
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            Rectangle {
                width: parent.width * 0.7
                height: width
                radius: width / 2
                x: parent.width * 0.55 - width / 2
                y: -height * 0.35
                color: root.accent
                opacity: 0.04
            }

            Rectangle {
                width: parent.width * 0.45
                height: width
                radius: width / 2
                x: -width * 0.2
                y: parent.height * 0.55 - height / 2
                color: root.accent2
                opacity: 0.03
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Choose Sound"
                            color: root.text
                            font.pixelSize: 19
                            font.family: "Fira Sans"
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.localPathFromUrl(root.pickerFolderUrl)
                            color: root.subtext0
                            font.pixelSize: 12
                            font.family: "Fira Sans"
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 38
                        radius: 12
                        color: ThemePkg.Theme.withAlpha(root.accent2, folderUpMouse.containsMouse ? 0.22 : 0.14)
                        border.color: ThemePkg.Theme.withAlpha(root.accent2, 0.42)
                        border.width: 1
                        opacity: pickerFolderModel.parentFolder && String(pickerFolderModel.parentFolder) !== String(root.pickerFolderUrl) ? 1.0 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "󰁞"
                            color: root.text
                            font.pixelSize: 16
                            font.family: "Iosevka Nerd Font"
                        }

                        MouseArea {
                            id: folderUpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: pickerFolderModel.parentFolder && String(pickerFolderModel.parentFolder) !== String(root.pickerFolderUrl)
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.openPickerFolder(pickerFolderModel.parentFolder)
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 38
                        radius: 12
                        color: ThemePkg.Theme.withAlpha(root.danger, closePickerMouse.containsMouse ? 0.22 : 0.14)
                        border.color: ThemePkg.Theme.withAlpha(root.danger, 0.42)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: root.text
                            font.pixelSize: 16
                            font.family: "Iosevka Nerd Font"
                        }

                        MouseArea {
                            id: closePickerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeAddSoundPicker()
                        }
                    }
                }



                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: ThemePkg.Theme.withAlpha(root.surface0, 0.72)
                    border.width: 1
                    border.color: ThemePkg.Theme.withAlpha(root.panelBorderColor, 0.75)

                    ScrollView {
                        id: pickerScroll
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true

                        ThemePkg.FastScrollHandler {
                            anchors.fill: parent
                            flickable: pickerScroll.contentItem
                        }

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            id: pickerVBar
                            parent: pickerScroll
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || pickerScroll.contentItem.moving

                            background: Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: root.panelBorderColor
                                border.color: root.panelBorderColor
                                opacity: pickerVBar.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: root.panelBorderColor
                                color: root.accent
                            }
                        }

                        Column {
                            width: pickerScroll.availableWidth - 14
                            spacing: 8

                            Repeater {
                                model: pickerFolderModel

                                delegate: Rectangle {
                                    id: pickerEntry
                                    width: parent.width
                                    height: 58
                                    radius: 14

                                    property bool isDir: !!fileIsDir
                                    property bool isSelected: !isDir && root.pickerSelectedPath === String(filePath)
                                    property color rowAccent: isDir ? root.accent : root.accent2

                                    color: isSelected
                                        ? ThemePkg.Theme.withAlpha(rowAccent, 0.22)
                                        : (pickerRowMouse.containsMouse ? ThemePkg.Theme.withAlpha(rowAccent, 0.14) : "#05ffffff")
                                    border.color: isSelected
                                        ? ThemePkg.Theme.withAlpha(rowAccent, 0.45)
                                        : (pickerRowMouse.containsMouse ? ThemePkg.Theme.withAlpha(rowAccent, 0.32) : "#1affffff")
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: 10
                                            color: ThemePkg.Theme.withAlpha(pickerEntry.rowAccent, 0.16)
                                            border.color: ThemePkg.Theme.withAlpha(pickerEntry.rowAccent, 0.32)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: pickerEntry.isDir ? "󰉋" : "󰈙"
                                                color: pickerEntry.rowAccent
                                                font.pixelSize: 16
                                                font.family: "Iosevka Nerd Font"
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: fileName
                                                color: root.text
                                                font.pixelSize: 13
                                                font.family: "Fira Sans Semibold"
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: pickerEntry.isDir ? "Folder" : root.prettySoundName(fileName)
                                                color: pickerEntry.isDir ? root.subtext0 : pickerEntry.rowAccent
                                                font.pixelSize: 11
                                                font.family: "Fira Sans"
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            text: pickerEntry.isDir ? "󰁔" : (pickerEntry.isSelected ? "󰄬" : "")
                                            color: pickerEntry.isDir ? root.subtext0 : root.success
                                            font.pixelSize: 15
                                            font.family: "Iosevka Nerd Font"
                                        }
                                    }

                                    MouseArea {
                                        id: pickerRowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectPickerEntry(filePath, fileName, fileIsDir, fileUrl)
                                        onDoubleClicked: {
                                            if (fileIsDir)
                                                root.openPickerFolder(fileUrl);
                                            else {
                                                root.pickerSelectedPath = String(filePath || "");
                                                root.pickerSelectedName = String(fileName || "");
                                                root.confirmPickerSelection();
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 8
                                visible: pickerFolderModel.count <= 0

                                Item {
                                    width: 1
                                    height: 80
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰉖"
                                    color: root.subtext0
                                    font.pixelSize: 34
                                    font.family: "Iosevka Nerd Font"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No matching audio files here."
                                    color: root.text
                                    font.pixelSize: 14
                                    font.family: "Fira Sans"
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 12
                        color: ThemePkg.Theme.withAlpha(root.overlay0, cancelPickerMouse.containsMouse ? 0.22 : 0.14)
                        border.color: ThemePkg.Theme.withAlpha(root.overlay0, 0.38)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: root.text
                            font.pixelSize: 13
                            font.family: "Fira Sans"
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: cancelPickerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeAddSoundPicker()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 12
                        color: root.pickerSelectedPath !== ""
                            ? ThemePkg.Theme.withAlpha(root.accent, importPickerMouse.containsMouse ? 0.24 : 0.16)
                            : ThemePkg.Theme.withAlpha(root.overlay0, 0.16)
                        border.color: root.pickerSelectedPath !== ""
                            ? ThemePkg.Theme.withAlpha(root.accent, 0.45)
                            : root.overlay0
                        border.width: 1
                        opacity: root.pickerSelectedPath !== "" ? 1.0 : 0.55

                        Text {
                            anchors.centerIn: parent
                            text: "Import Selected"
                            color: root.text
                            font.pixelSize: 13
                            font.family: "Fira Sans"
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: importPickerMouse
                            anchors.fill: parent
                            enabled: root.pickerSelectedPath !== ""
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.confirmPickerSelection()
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: pickerEnterAnim
        running: false

        onStopped: {
            if (!root.pickerTargetVisible && root.pickerCardOpacity <= 0.001)
                root.pickerMounted = false;
            if (!root.pickerTargetVisible && root.pickerCardOpacity <= 0.001)
                root.pickerVisible = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickerCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardWidth"; to: 614; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardHeight"; to: 526; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickerCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardWidth"; to: 640; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardHeight"; to: 560; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pickerCardRadius"; to: 20; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pickerCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: pickerExitAnim
        running: false

        onStopped: {
            if (!root.pickerTargetVisible && root.pickerCardOpacity <= 0.001)
                root.pickerMounted = false;
            if (!root.pickerTargetVisible && root.pickerCardOpacity <= 0.001)
                root.pickerVisible = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickerCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardWidth"; to: 658; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardHeight"; to: 540; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardRadius"; to: 30; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "pickerCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickerCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "pickerCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "pickerCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "pickerCardWidth"; to: 596; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "pickerCardHeight"; to: 532; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "pickerCardRadius"; to: 34; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "pickerCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
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
