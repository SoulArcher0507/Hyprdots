import "../../theme" as ThemePkg
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    readonly property int panelWidth: 850
    readonly property int panelHeight: 740
    readonly property int panelMargin: 16
    readonly property int contentMargin: 22
    readonly property int rowSpacing: 12
    readonly property int compactHeaderHeight: 58
    readonly property int compactStatsHeight: 82
    readonly property int compactChartsHeight: root.showWeekOverview ? 206 : 188
    readonly property int bottomSectionHeight: root.showAppDetail ? 420 : (root.showWeekOverview ? 310 : 300)
    readonly property color base: ThemePkg.Theme.surface(0.1)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    readonly property color accent: ThemePkg.Theme.accent
    readonly property color accent2: ThemePkg.Theme.accent2
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color peach: ThemePkg.Theme.c11
    readonly property color green: ThemePkg.Theme.c2
    readonly property color mauve: ThemePkg.Theme.c5
    readonly property color blue: ThemePkg.Theme.c4
    readonly property color resourcePanelFill: "#08ffffff"
    readonly property color resourcePanelFillHover: "#14ffffff"
    readonly property color resourcePanelBorder: "#1affffff"
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekDayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var weekDayLongNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    readonly property string textFont: "Fira Sans"
    property var globalDate: new Date()
    property var appDate: new Date()
    readonly property var activeDate: root.selectedAppClass === "" ? root.globalDate : root.appDate
    readonly property string activeDateStr: root.getIsoDate(root.activeDate)
    readonly property bool isTodaySelected: root.activeDateStr === root.getIsoDate(new Date())
    readonly property bool showDailyList: !root.isWeekView && root.selectedAppClass === ""
    readonly property bool showAppDetail: root.selectedAppClass !== ""
    readonly property bool showWeekOverview: root.isWeekView && root.selectedAppClass === ""
    property bool isWeekView: false
    property string selectedDateStr: ""
    property string selectedAppClass: ""
    property string selectedAppName: ""
    property string selectedAppIcon: ""
    property int totalSeconds: 0
    property int yesterdaySeconds: 0
    property int averageSeconds: 0
    property string currentTitle: ""
    property string weekRange: ""
    property string peakUsageHours: "N/A"
    property var hourlyData: root.zeroHourlyData()
    property int maxHourlyTotal: 1
    property var weekHeatmapData: root.zeroWeekHeatmap()
    property int maxWeekHour: 1
    property int maxWeekTotal: 1
    property int maxMonthTotal: 1
    property real chartRevealProgress: 1.0
    property bool pendingChartAnimation: false
    property string stateFile: Quickshell.env("HOME") + "/.cache/quickshell/focustime_state.json"
    readonly property real popupOpenWidth: root.panelWidth
    readonly property real popupOpenHeight: root.panelHeight
    readonly property real popupClosedWidth: root.panelWidth - 44
    readonly property real popupClosedHeight: root.panelHeight - 28
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 34

    property bool popupMounted: false
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18

    function getIsoDate(dateObj) {
        let tzOffset = dateObj.getTimezoneOffset() * 60000;
        return (new Date(dateObj - tzOffset)).toISOString().slice(0, 10);
    }

    function zeroHourlyData() {
        return Array(48).fill(0);
    }

    function zeroWeekHeatmap() {
        return [Array(24).fill(0), Array(24).fill(0), Array(24).fill(0), Array(24).fill(0), Array(24).fill(0), Array(24).fill(0), Array(24).fill(0)];
    }

    function formatTimeList(totalSecs) {
        if (!totalSecs || totalSecs < 0)
            return "0m";

        let hours = Math.floor(totalSecs / 3600);
        let minutes = Math.floor((totalSecs % 3600) / 60);
        if (hours > 0)
            return hours + "h " + minutes.toString().padStart(2, "0") + "m";

        return minutes + "m";
    }

    function formatPeakHour(hour24) {
        let suffix = hour24 >= 12 ? "PM" : "AM";
        let hour12 = hour24 % 12;
        if (hour12 === 0)
            hour12 = 12;

        return hour12 + " " + suffix;
    }

    function isHeatmapRow(index) {
        return Array.isArray(root.weekHeatmapData) && index >= 0 && index < root.weekHeatmapData.length && Array.isArray(root.weekHeatmapData[index]);
    }

    function iconSource(iconName) {
        const icon = String(iconName || "");
        if (icon === "")
            return "";
        if (icon.startsWith("file://") || icon.startsWith("image://"))
            return icon;
        if (icon.startsWith("/"))
            return "file://" + icon;
        return "image://icon/" + icon;
    }

    function populateAppModel(targetModel, apps) {
        targetModel.clear();
        if (!apps)
            return ;

        for (let i = 0; i < apps.length; ++i) {
            let app = apps[i];
            targetModel.append({
                "appClass": app.class || "",
                "label": app.name || app.class || "Unknown",
                "iconName": app.icon || "",
                "seconds": app.seconds || 0,
                "percent": app.percent || 0
            });
        }
    }

    function populateWeekModel(week) {
        weekListModel.clear();
        let maxValue = 1;
        if (week) {
            for (let i = 0; i < week.length; ++i) {
                let item = week[i];
                weekListModel.append({
                    "dateStr": item.date || "",
                    "dayName": item.day || root.weekDayNames[i % root.weekDayNames.length],
                    "total": item.total || 0,
                    "isTarget": !!item.is_target
                });
                if ((item.total || 0) > maxValue)
                    maxValue = item.total || 0;

            }
        }
        root.maxWeekTotal = maxValue;
    }

    function populateMonthModel(month) {
        monthListModel.clear();
        let maxValue = 1;
        if (month) {
            for (let i = 0; i < month.length; ++i) {
                let item = month[i];
                monthListModel.append({
                    "dateStr": item.date || "",
                    "total": item.total !== undefined ? item.total : -1,
                    "isTarget": !!item.is_target
                });
                if ((item.total || 0) > maxValue)
                    maxValue = item.total || 0;

            }
        }
        root.maxMonthTotal = maxValue;
    }

    function updatePeakUsage(heatmap) {
        let sums = Array(24).fill(0);
        let maxValue = 1;
        if (Array.isArray(heatmap)) {
            for (let day = 0; day < heatmap.length; ++day) {
                if (!Array.isArray(heatmap[day]))
                    continue;

                for (let hour = 0; hour < 24; ++hour) {
                    let value = heatmap[day][hour] || 0;
                    sums[hour] += value;
                    if (value > maxValue)
                        maxValue = value;

                }
            }
        }
        root.maxWeekHour = maxValue;
        let bestStart = -1;
        let bestValue = 0;
        for (let start = 0; start < 23; ++start) {
            let block = sums[start] + sums[start + 1];
            if (block > bestValue) {
                bestValue = block;
                bestStart = start;
            }
        }
        root.peakUsageHours = bestStart >= 0 ? root.formatPeakHour(bestStart) + " - " + root.formatPeakHour(bestStart + 2) : "N/A";
    }

    function resetPopupState() {
        root.globalDate = new Date();
        root.appDate = new Date();
        root.isWeekView = false;
        root.selectedAppClass = "";
        root.selectedAppName = "";
        root.selectedAppIcon = "";
        root.selectedDateStr = root.getIsoDate(new Date());
    }

    function preparePopupOpen() {
        ThemePkg.Theme.globalCloseAllPopups();
        root.showPopup();
        root.resetPopupState();
        root.markChartAnimationPending(true);
        root.requestDataUpdate();
    }

    function showPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999)
            return;
        popupEnterAnim.stop();
        popupEnterAnim.start();
        win.forceActiveFocus();
    }

    function hidePopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        popupExitAnim.start();
    }

    function markChartAnimationPending(resetProgress) {
        root.pendingChartAnimation = true;
        if (!ThemePkg.Theme.edgeAnimationsEnabled) {
            root.chartRevealProgress = 1.0;
            return ;
        }
        if (resetProgress) {
            chartRevealAnimation.stop();
            root.chartRevealProgress = 0.0;
        }
    }

    function playChartAnimation() {
        root.pendingChartAnimation = false;
        if (!ThemePkg.Theme.edgeAnimationsEnabled) {
            root.chartRevealProgress = 1.0;
            return ;
        }
        root.chartRevealProgress = 0.0;
        chartRevealAnimation.restart();
    }

    function chartBarProgress(index, totalBars) {
        let count = Math.max(1, totalBars || 1);
        let normalizedIndex = Math.max(0, index) / count;
        let delay = Math.min(0.45, normalizedIndex * 0.4);
        let span = Math.max(0.001, 1 - delay);
        return Math.max(0, Math.min(1, (root.chartRevealProgress - delay) / span));
    }

    function leaveSubview() {
        if (root.selectedAppClass !== "") {
            root.selectedAppClass = "";
            root.selectedAppName = "";
            root.selectedAppIcon = "";
            root.markChartAnimationPending(true);
            root.requestDataUpdate();
            return ;
        }
        if (root.isWeekView)
            root.isWeekView = false;

    }

    function changeDay(offsetDays) {
        let nextDate = new Date(root.activeDate);
        nextDate.setDate(nextDate.getDate() + offsetDays);
        if (root.getIsoDate(nextDate) > root.getIsoDate(new Date()))
            return ;

        if (root.selectedAppClass === "")
            root.globalDate = nextDate;
        else
            root.appDate = nextDate;
        root.markChartAnimationPending();
        root.requestDataUpdate();
    }

    function changeToDate(dateStr) {
        if (!dateStr)
            return ;

        let parts = dateStr.split("-");
        if (parts.length !== 3)
            return ;

        let nextDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        if (root.getIsoDate(nextDate) > root.getIsoDate(new Date()))
            return ;

        if (root.selectedAppClass === "")
            root.globalDate = nextDate;
        else
            root.appDate = nextDate;
        root.markChartAnimationPending();
        root.requestDataUpdate();
    }

    function canMoveForward(stepDays) {
        let candidate = new Date(root.activeDate);
        candidate.setDate(candidate.getDate() + stepDays);
        return root.getIsoDate(candidate) <= root.getIsoDate(new Date());
    }

    function toggleWeekOverview() {
        if (root.selectedAppClass !== "")
            return ;

        root.isWeekView = !root.isWeekView;
        if (root.isWeekView) {
            root.markChartAnimationPending(true);
            Qt.callLater(function() {
                if (root.isWeekView && root.popupMounted && root.pendingChartAnimation)
                    root.playChartAnimation();
            });
        }
    }

    function parseData(jsonText) {
        if (!jsonText || jsonText.trim() === "")
            return ;

        try {
            let data = JSON.parse(jsonText);
            root.selectedDateStr = data.selected_date || root.activeDateStr;
            root.totalSeconds = data.total || 0;
            root.yesterdaySeconds = data.yesterday || 0;
            root.averageSeconds = data.average || 0;
            root.currentTitle = data.current || "";
            root.weekRange = data.week_range || "";
            root.populateAppModel(appListModel, data.apps || []);
            root.populateAppModel(weekAppListModel, data.week_apps || []);
            root.populateWeekModel(data.week || []);
            root.populateMonthModel(data.month || []);
            let hourly = root.zeroHourlyData();
            if (Array.isArray(data.hourly)) {
                for (let i = 0; i < Math.min(48, data.hourly.length); ++i) {
                    hourly[i] = data.hourly[i] || 0;
                }
            }
            root.hourlyData = hourly;
            let maxHourly = 1;
            for (let hourIdx = 0; hourIdx < root.hourlyData.length; ++hourIdx) {
                if (root.hourlyData[hourIdx] > maxHourly)
                    maxHourly = root.hourlyData[hourIdx];

            }
            root.maxHourlyTotal = maxHourly;
            let heatmap = root.zeroWeekHeatmap();
            if (Array.isArray(data.week_heatmap)) {
                for (let day = 0; day < Math.min(7, data.week_heatmap.length); ++day) {
                    if (!Array.isArray(data.week_heatmap[day]))
                        continue;

                    for (let hour = 0; hour < Math.min(24, data.week_heatmap[day].length); ++hour) {
                        heatmap[day][hour] = data.week_heatmap[day][hour] || 0;
                    }
                }
            }
            root.weekHeatmapData = heatmap;
            root.updatePeakUsage(heatmap);
            if (root.pendingChartAnimation)
                root.playChartAnimation();
        } catch (e) {
            console.log("FocusTime parse error:", e);
        }
    }

    function requestDataUpdate() {
        if (root.selectedAppClass === "" && root.isTodaySelected)
            statePoller.reload();
        else
            statsProcess.running = true;
    }

    ListModel {
        id: appListModel
    }

    ListModel {
        id: weekAppListModel
    }

    ListModel {
        id: weekListModel
    }

    ListModel {
        id: monthListModel
    }

    Connections {
        function onGlobalCloseShellPopups() {
            root.hidePopup();
        }

        function onGlobalCloseAllPopups() {
            root.hidePopup();
        }

        function onGlobalToggleFocusTime() {
            if (root.popupTargetVisible) {
                root.hidePopup();
            } else {
                root.preparePopupOpen();
            }
        }

        target: ThemePkg.Theme
    }

    FileView {
        id: statePoller

        path: root.stateFile
        watchChanges: true
        Component.onCompleted: reload()
        onFileChanged: reload()
        onLoaded: {
            if (root.selectedAppClass === "" && root.isTodaySelected)
                root.parseData(text());

        }
    }

    Process {
        id: statsProcess

        command: {
            let args = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/archtools/focustime_stats.py"];
            args.push(root.activeDateStr);
            if (root.selectedAppClass !== "")
                args.push("--app", root.selectedAppClass);

            return args;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseData(text);
            }
        }

    }



    PanelWindow {
        id: win

        visible: root.popupMounted
        focusable: root.popupMounted
        color: "transparent"

        Component.onCompleted: {
            try {
                if (win.WlrLayershell)
                    win.WlrLayershell.layer = WlrLayer.Overlay;
            } catch (e) {}
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            enabled: root.popupTargetVisible
            onActivated: {
                if (root.selectedAppClass !== "" || root.isWeekView) {
                    root.leaveSubview();
                } else {
                    root.hidePopup();
                }
            }
        }

        Shortcut {
            sequence: "Left"
            context: Qt.ApplicationShortcut
            enabled: root.popupTargetVisible
            onActivated: root.changeDay(root.isWeekView ? -7 : -1)
        }

        Shortcut {
            sequence: "Right"
            context: Qt.ApplicationShortcut
            enabled: root.popupTargetVisible
            onActivated: root.changeDay(root.isWeekView ? 7 : 1)
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
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

            property real orbitAngle: 0

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
                x: parent.width * 0.2 - width / 2 + Math.cos(card.orbitAngle * 1.4 + 1) * 48
                y: parent.height * 0.55 - height / 2 + Math.sin(card.orbitAngle * 1.1) * 56
                color: root.accent2
                opacity: 0.03
            }

            Text {
                property real drift: 0

                anchors.centerIn: parent
                text: "󰥔"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 320
                color: root.accent
                opacity: 0.03 + (0.01 * Math.sin(card.orbitAngle * 3))

                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    running: root.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled

                    NumberAnimation {
                        to: -12
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        to: 0
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }

                }

                transform: Translate {
                    y: parent.drift
                }

            }

            Flickable {
                id: contentFlick

                anchors.fill: parent
                anchors.margins: root.contentMargin
                clip: true
                contentWidth: width
                contentHeight: popupContent.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: popupContent

                    width: contentFlick.width - (contentScrollBar.visible ? contentScrollBar.width + 10 : 0)
                    height: Math.max(implicitHeight, contentFlick.height)
                    spacing: root.rowSpacing

                    Item {
                        readonly property int stepDays: root.showWeekOverview ? 7 : 1

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.compactHeaderHeight

                        CalendarArrowButton {
                            id: prevDayBtn

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: ""
                            onButtonClicked: root.changeDay(-parent.stepDays)
                        }

                        CalendarArrowButton {
                            id: nextDayBtn

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: ""
                            buttonEnabled: root.canMoveForward(parent.stepDays)
                            onButtonClicked: root.changeDay(parent.stepDays)
                        }

                        Item {
                            id: titleArea
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: titleColumn.implicitWidth
                            height: titleColumn.implicitHeight

                            Column {
                                id: titleColumn

                                anchors.centerIn: parent
                                spacing: 1

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8

                                    Image {
                                        visible: root.showAppDetail && root.selectedAppIcon !== ""
                                        source: root.iconSource(root.selectedAppIcon)
                                        width: 22
                                        height: 22
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        text: root.showAppDetail ? root.selectedAppName : (root.showWeekOverview ? "Week Overview" : (root.isTodaySelected ? "Today" : Qt.formatDate(root.activeDate, "dddd")))
                                        color: root.text
                                        font.pixelSize: 18
                                        font.family: root.textFont
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.showAppDetail ? Qt.formatDate(root.activeDate, "dddd, MMM d") : (root.weekRange !== "" ? root.weekRange : root.currentTitle)
                                    color: root.subtext0
                                    font.pixelSize: 11
                                    font.family: root.textFont
                                    horizontalAlignment: Text.AlignHCenter
                                }

                            }

                            MouseArea {
                                id: titleMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.showAppDetail) {
                                        root.leaveSubview()
                                    } else {
                                        root.toggleWeekOverview()
                                    }
                                }
                            }

                            HoverToolTip {
                                visible: titleMouseArea.containsMouse
                                delay: 250
                                text: root.showAppDetail ? "Click to return to the overview" : (root.showWeekOverview ? "Click to switch back to the daily view" : "Click to switch to the week overview")
                            }

                        }

                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: active ? root.compactStatsHeight : 0
                        active: !root.showWeekOverview
                        visible: active
                        sourceComponent: statsCardsComponent
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: active ? root.compactChartsHeight : 0
                        active: root.showDailyList
                        visible: active
                        sourceComponent: dailyChartsComponent
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: active ? root.compactChartsHeight : 0
                        active: root.showWeekOverview
                        visible: active
                        sourceComponent: weekHeatmapComponent
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.bottomSectionHeight
                        Layout.fillHeight: true
                        Layout.minimumHeight: root.showAppDetail ? 440 : root.bottomSectionHeight
                        radius: 14
                        color: root.resourcePanelFill
                        border.color: root.resourcePanelBorder
                        border.width: 1

                        Loader {
                            anchors.fill: parent
                            anchors.margins: 0
                            sourceComponent: root.showAppDetail ? appDetailComponent : (root.showWeekOverview ? weekListComponent : dailyListComponent)
                        }

                    }

                }

                ScrollBar.vertical: PopupScrollBar {
                    id: contentScrollBar

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    policy: contentFlick.contentHeight > contentFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    active: hovered || pressed || contentFlick.moving
                }

            }

            Component {
                id: statsCardsComponent

                RowLayout {
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: root.resourcePanelFill
                        border.color: root.resourcePanelBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: root.textFont
                                font.pixelSize: 12
                                color: root.subtext0
                                text: "Daily average"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: root.textFont
                                font.weight: Font.Bold
                                font.pixelSize: 19
                                color: root.text
                                text: root.formatTimeList(root.averageSeconds)
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: root.resourcePanelFill
                        border.color: root.resourcePanelBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: root.textFont
                                font.pixelSize: 12
                                color: root.accent
                                text: "Total Time"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: root.textFont
                                font.weight: Font.Bold
                                font.pixelSize: 24
                                color: root.text
                                text: root.formatTimeList(root.totalSeconds)
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: root.resourcePanelFill
                        border.color: root.resourcePanelBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: root.textFont
                                font.pixelSize: 12
                                color: root.subtext0
                                text: "vs Yesterday"
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 5

                                Text {
                                    visible: root.totalSeconds !== root.yesterdaySeconds
                                    font.family: root.textFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 20
                                    color: (root.totalSeconds - root.yesterdaySeconds) > 0 ? root.peach : root.green
                                    text: (root.totalSeconds - root.yesterdaySeconds) > 0 ? "↑" : "↓"
                                }

                                Text {
                                    visible: root.totalSeconds !== root.yesterdaySeconds
                                    font.family: root.textFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 20
                                    color: (root.totalSeconds - root.yesterdaySeconds) > 0 ? root.peach : root.green
                                    text: root.formatTimeList(Math.abs(root.totalSeconds - root.yesterdaySeconds))
                                }

                                Text {
                                    visible: root.totalSeconds === root.yesterdaySeconds
                                    font.family: root.textFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 13
                                    color: root.overlay0
                                    text: "Same time"
                                }

                            }

                        }

                    }

                }

            }

            Component {
                id: dailyChartsComponent

                RowLayout {
                    spacing: 16

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 400
                        radius: 14
                        color: root.resourcePanelFill
                        border.color: root.resourcePanelBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            height: parent.height - 32
                            spacing: 12

                            Repeater {
                                model: weekListModel

                                delegate: Item {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 45

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.changeToDate(dateStr)
                                    }

                                    Item {
                                        anchors.bottom: dayLabel.top
                                        anchors.bottomMargin: 8
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 45
                                        property real finalHeight: Math.max(4, (parent.height - 25) * (total / Math.max(root.maxWeekTotal, 1)))
                                        height: finalHeight * root.chartBarProgress(index, Math.max(weekListModel.count, 1))

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            color: isTarget ? "transparent" : root.surface0
                                            visible: !isTarget
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            visible: isTarget

                                            gradient: Gradient {
                                                GradientStop {
                                                    position: 0
                                                    color: root.mauve
                                                }

                                                GradientStop {
                                                    position: 1
                                                    color: root.blue
                                                }

                                            }

                                        }

                                    }

                                    Text {
                                        id: dayLabel

                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.family: root.textFont
                                        font.pixelSize: 12
                                        color: isTarget ? root.text : root.overlay0
                                        text: dayName
                                    }

                                }

                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 300
                        radius: 14
                        color: root.resourcePanelFill
                        border.color: root.resourcePanelBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: root.textFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                color: root.text
                                text: root.monthNames[root.activeDate.getMonth()]
                            }

                            Grid {
                                Layout.alignment: Qt.AlignCenter
                                columns: 7
                                flow: Grid.LeftToRight
                                spacing: 6

                                Repeater {
                                    model: monthListModel

                                    delegate: Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 4
                                        visible: total !== -1
                                        color: total === 0 ? root.surface0 : ThemePkg.Theme.withAlpha(root.mauve, Math.min(1, 0.3 + 0.7 * (total / Math.max(root.maxMonthTotal, 1))))
                                        border.color: isTarget ? root.text : "transparent"
                                        border.width: isTarget ? 1 : 0

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: total !== -1
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.changeToDate(dateStr)
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

            Component {
                id: weekHeatmapComponent

                Rectangle {
                    radius: 14
                    color: root.resourcePanelFill
                    border.color: root.resourcePanelBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6

                            Repeater {
                                model: 7

                                delegate: RowLayout {
                                    property int dayIndex: index

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 68
                                        font.family: root.textFont
                                        font.pixelSize: 12
                                        color: root.subtext0
                                        text: root.weekDayLongNames[dayIndex]
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 8
                                        color: root.resourcePanelFill
                                        clip: true

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 0

                                            Repeater {
                                                model: 24

                                                delegate: Rectangle {
                                                    property real blockValue: root.isHeatmapRow(dayIndex) ? (root.weekHeatmapData[dayIndex][index] || 0) : 0
                                                    property real intensity: Math.min(1, 0.2 + 0.8 * (blockValue / Math.max(root.maxWeekHour, 1)))
                                                    property real revealProgress: root.chartBarProgress((dayIndex * 24) + index, 24 * 7)
                                                    property real hoverFactor: 1.0

                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    color: blockValue === 0 ? root.surface0 : Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, intensity)
                                                    opacity: (0.18 + (0.82 * revealProgress)) * hoverFactor
                                                    scale: 0.7 + (0.3 * revealProgress)
                                                    transformOrigin: Item.Center

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: parent.hoverFactor = 0.75
                                                        onExited: parent.hoverFactor = 1.0
                                                    }

                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: 76
                                }

                                Text {
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    color: root.overlay0
                                    text: "00:00"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    color: root.overlay0
                                    text: "06:00"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    color: root.overlay0
                                    text: "12:00"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    color: root.overlay0
                                    text: "18:00"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    color: root.overlay0
                                    text: "23:00"
                                }

                            }

                        }

                        ColumnLayout {
                            Layout.preferredWidth: 128
                            Layout.fillHeight: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: root.resourcePanelFill

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: root.textFont
                                        font.pixelSize: 12
                                        color: root.subtext0
                                        text: "Daily average"
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: root.textFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 18
                                        color: root.text
                                        text: root.formatTimeList(root.averageSeconds)
                                    }

                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: root.resourcePanelFill

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: root.textFont
                                        font.pixelSize: 12
                                        color: root.subtext0
                                        text: "Peak hours"
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: root.textFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 14
                                        color: root.text
                                        text: root.peakUsageHours
                                    }

                                }

                            }

                        }

                    }

                }

            }

            Component {
                id: dailyListComponent

                Item {
                    anchors.fill: parent

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                font.family: root.textFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                color: root.text
                                text: "Top apps"
                            }

                        }

                        ListView {
                            id: appList

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: appListModel
                            interactive: true

                            ScrollBar.vertical: ScrollBar {
                                id: dailyVbar
                                policy: ScrollBar.AsNeeded
                                hoverEnabled: true
                                implicitWidth: 10
                                minimumSize: 0.08
                                active: hovered || pressed || appList.moving

                                background: Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: root.panelBorderColor
                                    border.color: root.panelBorderColor
                                    opacity: dailyVbar.active ? 1.0 : 0.7
                                }

                                contentItem: Rectangle {
                                    radius: width / 2
                                    border.width: 1
                                    border.color: root.panelBorderColor
                                    color: root.accent
                                }
                            }

                            delegate: Rectangle {
                                width: ListView.view.width - 16
                                height: 58
                                radius: 10
                                color: appRowMouse.containsMouse ? root.surface0 : "transparent"

                                MouseArea {
                                    id: appRowMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedAppClass = appClass;
                                        root.selectedAppName = label;
                                        root.selectedAppIcon = iconName;
                                        root.appDate = new Date(root.activeDate);
                                        root.markChartAnimationPending(true);
                                        root.requestDataUpdate();
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Image {
                                            visible: iconName !== ""
                                            source: root.iconSource(iconName)
                                            sourceSize: Qt.size(20, 20)
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            Layout.rightMargin: 8
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            font.family: root.textFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 15
                                            color: root.text
                                            text: label
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            font.family: root.textFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 14
                                            color: root.subtext0
                                            text: root.formatTimeList(seconds)
                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 10

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 5
                                            color: root.crust
                                        }

                                        Rectangle {
                                            height: parent.height
                                            width: Math.max(10, parent.width * (percent / 100))
                                            radius: 5

                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal

                                                GradientStop {
                                                    position: 0
                                                    color: root.mauve
                                                }

                                                GradientStop {
                                                    position: 1
                                                    color: root.blue
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: appListModel.count === 0
                            font.family: root.textFont
                            font.pixelSize: 13
                            color: root.overlay0
                            text: "No app activity for this day"
                        }

                    }

                }

            }

            Component {
                id: weekListComponent

                Item {
                    anchors.fill: parent

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                font.family: root.textFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                color: root.text
                                text: "Top apps this week"
                            }

                        }

                        ListView {
                            id: weekAppList

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: weekAppListModel
                            interactive: true

                            ScrollBar.vertical: ScrollBar {
                                id: weeklyVbar
                                policy: ScrollBar.AsNeeded
                                hoverEnabled: true
                                implicitWidth: 10
                                minimumSize: 0.08
                                active: hovered || pressed || weekAppList.moving

                                background: Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: root.panelBorderColor
                                    border.color: root.panelBorderColor
                                    opacity: weeklyVbar.active ? 1.0 : 0.7
                                }

                                contentItem: Rectangle {
                                    radius: width / 2
                                    border.width: 1
                                    border.color: root.panelBorderColor
                                    color: root.accent
                                }
                            }

                            delegate: Rectangle {
                                width: ListView.view.width - 16
                                height: 58
                                radius: 10
                                color: weekAppMouse.containsMouse ? root.surface0 : "transparent"

                                MouseArea {
                                    id: weekAppMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedAppClass = appClass;
                                        root.selectedAppName = label;
                                        root.selectedAppIcon = iconName;
                                        root.appDate = new Date(root.activeDate);
                                        root.isWeekView = false;
                                        root.markChartAnimationPending(true);
                                        root.requestDataUpdate();
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Image {
                                            visible: iconName !== ""
                                            source: root.iconSource(iconName)
                                            sourceSize: Qt.size(20, 20)
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            Layout.rightMargin: 8
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            font.family: root.textFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 15
                                            color: root.text
                                            text: label
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            font.family: root.textFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 14
                                            color: root.subtext0
                                            text: root.formatTimeList(seconds)
                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 10

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 5
                                            color: root.crust
                                        }

                                        Rectangle {
                                            height: parent.height
                                            width: Math.max(10, parent.width * (percent / 100))
                                            radius: 5

                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal

                                                GradientStop {
                                                    position: 0
                                                    color: root.mauve
                                                }

                                                GradientStop {
                                                    position: 1
                                                    color: root.blue
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: weekAppListModel.count === 0
                            font.family: root.textFont
                            font.pixelSize: 13
                            color: root.overlay0
                            text: "No activity recorded in this week"
                        }

                    }

                }

            }

            Component {
                id: appDetailComponent

                Item {
                    anchors.fill: parent

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 182
                            Layout.maximumHeight: 182
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: root.resourcePanelFill
                                border.color: root.resourcePanelBorder
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8

                                        Repeater {
                                            model: weekListModel

                                            delegate: Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.changeToDate(dateStr)
                                                }

                                                Item {
                                                    anchors.bottom: weekDayLabel.top
                                                    anchors.bottomMargin: 4
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: Math.max(18, parent.width - 4)
                                                    property real finalHeight: Math.max(4, (parent.height - 18) * (total / Math.max(root.maxWeekTotal, 1)))
                                                    height: finalHeight * root.chartBarProgress(index, Math.max(weekListModel.count, 1))

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 4
                                                        color: isTarget ? "transparent" : root.surface0
                                                        visible: !isTarget
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 4
                                                        visible: isTarget

                                                        gradient: Gradient {
                                                            GradientStop {
                                                                position: 0
                                                                color: root.mauve
                                                            }

                                                            GradientStop {
                                                                position: 1
                                                                color: root.blue
                                                            }

                                                        }

                                                    }

                                                }

                                                Text {
                                                    id: weekDayLabel

                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    font.family: root.textFont
                                                    font.pixelSize: 9
                                                    color: isTarget ? root.text : root.overlay0
                                                    text: dayName
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            Rectangle {
                                Layout.preferredWidth: 252
                                Layout.fillHeight: true
                                radius: 14
                                color: root.resourcePanelFill
                                border.color: root.resourcePanelBorder
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: root.textFont
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 12
                                        color: root.text
                                        text: root.monthNames[root.activeDate.getMonth()]
                                    }

                                    Grid {
                                        Layout.alignment: Qt.AlignCenter
                                        columns: 7
                                        flow: Grid.LeftToRight
                                        spacing: 6

                                        Repeater {
                                            model: monthListModel

                                            delegate: Rectangle {
                                                width: 20
                                                height: 20
                                                radius: 6
                                                visible: total !== -1
                                                color: total === 0 ? root.surface0 : ThemePkg.Theme.withAlpha(root.mauve, Math.min(1, 0.3 + 0.7 * (total / Math.max(root.maxMonthTotal, 1))))
                                                border.color: isTarget ? root.text : "transparent"
                                                border.width: isTarget ? 1 : 0

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: total !== -1
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.changeToDate(dateStr)
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            radius: 14
                            color: root.resourcePanelFill
                            border.color: root.resourcePanelBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.textFont
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 13
                                        color: root.text
                                        text: "Daily usage"
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 88
                                        height: 32
                                        radius: 10
                                        color: root.surface0

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.textFont
                                            font.weight: Font.Bold
                                            font.pixelSize: 13
                                            color: root.text
                                            text: root.formatTimeList(root.totalSeconds)
                                        }

                                    }

                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.bottomMargin: 22
                                        spacing: 6

                                        Repeater {
                                            model: 48

                                            delegate: Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    property real finalHeight: Math.max(4, parent.height * (root.hourlyData[index] / Math.max(root.maxHourlyTotal, 1)))
                                                    height: finalHeight * root.chartBarProgress(index, 48)
                                                    radius: 2
                                                    color: root.hourlyData[index] > 0 ? root.blue : root.surface0
                                                }

                                            }

                                        }

                                    }

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom

                                        Text {
                                            font.family: root.textFont
                                            font.pixelSize: 11
                                            color: root.overlay0
                                            text: "00:00"
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            font.family: root.textFont
                                            font.pixelSize: 11
                                            color: root.overlay0
                                            text: "06:00"
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            font.family: root.textFont
                                            font.pixelSize: 11
                                            color: root.overlay0
                                            text: "12:00"
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            font.family: root.textFont
                                            font.pixelSize: 11
                                            color: root.overlay0
                                            text: "18:00"
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            font.family: root.textFont
                                            font.pixelSize: 11
                                            color: root.overlay0
                                            text: "23:00"
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

            NumberAnimation on orbitAngle {
                from: 0
                to: Math.PI * 2
                duration: 90000
                loops: Animation.Infinite
                running: root.popupMounted && ThemePkg.Theme.edgeAnimationsEnabled
            }

            NumberAnimation {
                id: chartRevealAnimation

                target: root
                property: "chartRevealProgress"
                from: 0
                to: 1
                duration: 520
                easing.type: Easing.OutCubic
            }

        }

        }

    }

    component PopupScrollBar: ScrollBar {
        hoverEnabled: true
        implicitWidth: 10
        minimumSize: 0.08

        background: Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.panelBorderColor
            border.color: root.panelBorderColor
            opacity: parent.active ? 1 : 0.7
        }

        contentItem: Rectangle {
            radius: width / 2
            border.width: 1
            border.color: root.panelBorderColor
            color: root.accent
        }

    }

    component CalendarArrowButton: Rectangle {
        id: arrowRoot

        property string glyph: ""
        property bool buttonEnabled: true

        signal buttonClicked()

        width: 30
        height: 30
        radius: 15
        color: arrowMa.containsMouse && buttonEnabled ? root.surface1 : "transparent"
        opacity: buttonEnabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            text: arrowRoot.glyph
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 15
            color: root.text
        }

        MouseArea {
            id: arrowMa

            anchors.fill: parent
            hoverEnabled: true
            enabled: arrowRoot.buttonEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: arrowRoot.buttonClicked()
        }

    }

    component HeaderActionButton: Rectangle {
        id: actionRoot

        property string label: "▦"

        signal buttonClicked()

        width: 30
        height: 30
        radius: 10
        color: actionMa.containsMouse ? root.resourcePanelFillHover : root.resourcePanelFill
        border.color: root.resourcePanelBorder
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: actionRoot.label
            color: root.text
            font.pixelSize: 14
            font.family: root.textFont
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: actionMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.buttonClicked()
        }

    }

    component HoverToolTip: ToolTip {
        id: hoverToolTipRoot

        x: parent ? Math.round((parent.width - implicitWidth) / 2) : 0
        y: -implicitHeight - 3
        margins: 6
        horizontalPadding: 8
        verticalPadding: 6

        background: Rectangle {
            radius: 10
            color: root.base
            border.width: 1
            border.color: root.panelBorderColor
        }

        contentItem: Text {
            text: hoverToolTipRoot.text
            color: root.accent
            font.pixelSize: 13
            font.family: "Fira Sans Semibold"
            wrapMode: Text.Wrap
        }
    }

}
