import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import "../../theme" as ThemePkg
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    anchors.fill: parent

    property var timeButton: null
    property var overlayWindow: null
    readonly property int panelWidth: 960
    readonly property int panelHeight: 570
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

    Shortcut { 
        sequence: "Left"
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut { 
        sequence: "Right"
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

  
    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color mantle: ThemePkg.Theme.surface(0.05)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext1: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.7)
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay2: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.5)
    readonly property color overlay1: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.4)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    
    readonly property color mauve: ThemePkg.Theme.c5
    readonly property color pink: ThemePkg.Theme.c13
    readonly property color sapphire: ThemePkg.Theme.c4
    readonly property color blue: ThemePkg.Theme.c4
    readonly property color red: ThemePkg.Theme.danger
    readonly property color peach: ThemePkg.Theme.warning
    readonly property color yellow: ThemePkg.Theme.c3
    readonly property color teal: ThemePkg.Theme.c6
    readonly property color green: ThemePkg.Theme.success
    readonly property string textFont: "Fira Sans"
    readonly property int panelMargin: 16
    readonly property int sidePanelWidth: 308
    readonly property int sidePanelHeight: 538
    readonly property int sidePanelInnerMargin: 20
    readonly property real centralHubOffset: 164
    readonly property real centralHubScale: 1.0
    readonly property real orbitRadiusScale: 1.15
    readonly property bool animationsEnabled: ThemePkg.Theme.edgeAnimationsEnabled
    readonly property real snappedWeatherTextOffset: Math.round(window.weatherContentOffset)
    readonly property real snappedCalendarTextOffset: Math.round(window.calendarContentOffset)

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/calendar"

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;      
        if (h >= 12 && h < 17) return window.sapphire;  
        if (h >= 17 && h < 21) return window.mauve;     
        return window.blue;                             
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;     
        if (h >= 12 && h < 17) return window.teal;      
        if (h >= 17 && h < 21) return window.pink;      
        return window.mauve;                            
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    property bool startupComplete: true
    property real introMain: 1.0
    property real introAmbient: 1.0
    property real introClock: 1.0
    property real introCalendar: 1.0
    property real introWeather: 1.0


    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: window.animationsEnabled
    }

    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000
    
    property real secondPulse: 1.0
    NumberAnimation on secondPulse { 
        id: pulseReset 
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false 
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            window.currentTime = new Date();
            if (window.animationsEnabled) {
                window.secondPulse = 1.06; 
                pulseReset.start();
            } else {
                pulseReset.stop();
                window.secondPulse = 1.0;
            }
            
            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    property var weatherData: null
    property int weatherView: 0
    property color activeWeatherHex: weatherData && weatherData.forecast && weatherData.forecast[weatherView] ? weatherData.forecast[weatherView].hex : window.mauve

    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1
    
    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    property real targetTemp: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? Number(window.weatherData.forecast[window.targetWeatherView].max) : 0
    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        enabled: window.animationsEnabled
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        
        if (window.targetTemp > window.displayedTemp) return window.red;
        
        if (window.targetTemp < window.displayedTemp) return window.blue;
        
        return window.text; 
    }
    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: -40 * weatherAnimDirection; duration: 250; easing.type: Easing.InSine }
            
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: 300; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction { 
            script: { 
                window.weatherView = window.targetWeatherView; 
                window.weatherContentOffset = 40 * weatherAnimDirection; 
                
                window.transitionSpin = -180 * weatherAnimDirection;
            } 
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: 450; easing.type: Easing.OutQuart }
            
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return; 

        if (!window.animationsEnabled) {
            window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
            window.targetWeatherView = idx;
            window.weatherView = idx;
            window.weatherContentOpacity = 1.0;
            window.weatherContentOffset = 0.0;
            window.transitionSpin = 0.0;
            window.transitionScale = 1.0;
            return;
        }

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0]) return -1;
        return 0; 
    }

    Process {
        id: weatherPoller
        command: ["bash", window.scriptsDir + "/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.weatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 150000 
        running: true; repeat: true
        onTriggered: weatherPoller.running = true
    }

    

    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: -20 * calendarAnimDirection; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = 20 * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 350; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 350; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (!window.animationsEnabled) {
            window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
            window.targetMonthOffset = newOffset;
            window.monthOffset = newOffset;
            window.calendarContentOpacity = 1.0;
            window.calendarContentOffset = 0.0;
            return;
        }

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1); 
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();
        
        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1; 

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    onAnimationsEnabledChanged: {
        if (window.animationsEnabled)
            return;

        if (!window.startupComplete) {
            window.introMain = 1.0;
            window.introAmbient = 1.0;
            window.introClock = 1.0;
            window.introCalendar = 1.0;
            window.introWeather = 1.0;
            window.startupComplete = true;
        }

        if (weatherTransitionAnim.running)
            weatherTransitionAnim.stop();
        window.weatherView = window.targetWeatherView;
        window.weatherContentOpacity = 1.0;
        window.weatherContentOffset = 0.0;
        window.transitionSpin = 0.0;
        window.transitionScale = 1.0;

        if (calendarTransitionAnim.running)
            calendarTransitionAnim.stop();
        window.monthOffset = window.targetMonthOffset;
        window.calendarContentOpacity = 1.0;
        window.calendarContentOffset = 0.0;

        pulseReset.stop();
        window.secondPulse = 1.0;
    }

    Component.onCompleted: {
        updateCalendarGrid();
        popupTargetVisible = true;
        if (!window.animationsEnabled) {
            window.introMain = 1.0;
            window.introAmbient = 1.0;
            window.introClock = 1.0;
            window.introCalendar = 1.0;
            window.introWeather = 1.0;
            window.startupComplete = true;
        }
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

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth - 18; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight - 18; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: window.popupOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth + 14; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight - 16; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: window.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }

    Item {
        id: popupShell
        width: window.popupCardWidth
        height: window.popupCardHeight
        opacity: window.popupCardOpacity
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: window.popupCardLift
        anchors.rightMargin: window.panelMargin
        scale: 0.95 + (0.05 * introMain)

        transform: Scale {
            origin.x: popupShell.width / 2
            origin.y: popupShell.height / 2
            xScale: window.popupCardScaleX
            yScale: window.popupCardScaleY
        }

        Rectangle {
            anchors.fill: parent
            radius: window.popupCardRadius
            color: window.base
            border.color: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
            border.width: 1
            clip: true

            AnimatedBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: ThemePkg.Theme.accent
            }

            Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                x: (parent.width * 0.75 - width / 2) + Math.cos(window.globalOrbitAngle * 1.5) * 180
                y: (parent.height * 0.3 - height / 2) + Math.sin(window.globalOrbitAngle * 1.5) * 100
                opacity: 0.025 * window.introAmbient
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Rectangle {
                width: parent.width * 0.6; height: width; radius: width / 2
                x: (parent.width * 0.25 - width / 2) + Math.sin(window.globalOrbitAngle * 1.2) * -150
                y: (parent.height * 0.7 - height / 2) + Math.cos(window.globalOrbitAngle * 1.2) * -100
                opacity: 0.02 * window.introAmbient
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Rectangle {
                width: parent.width * 0.45; height: width; radius: width / 2
                x: (parent.width * 0.5 - width / 2) + Math.cos(window.globalOrbitAngle * -1.8) * 190
                y: (parent.height * 0.5 - height / 2) + Math.sin(window.globalOrbitAngle * -1.8) * -130
                opacity: 0.015 * window.introAmbient
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -45
                text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 400
                color: window.activeWeatherHex
                opacity: (0.03 + (0.01 * Math.sin(window.globalOrbitAngle * 4))) * window.introAmbient * window.weatherContentOpacity
                z: 0
                Behavior on color { ColorAnimation { duration: 1500 } }
                
                property real drift: 0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    running: window.animationsEnabled
                    NumberAnimation { to: -8; duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                }
                
                transform: [
                    Translate { y: Math.round(drift) },
                    Translate { x: Math.round(window.weatherContentOffset * 1.5) }
                ]
            }

            Item {
                id: centralHub
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: window.centralHubOffset
                width: 1; height: 1 
                z: 5

                opacity: introClock
                scale: (0.85 + (0.15 * introClock)) * window.centralHubScale

                property real levitation: 0
                SequentialAnimation on levitation {
                    loops: Animation.Infinite
                    running: window.animationsEnabled
                    NumberAnimation { to: -6; duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 4000; easing.type: Easing.InOutSine }
                }

                property real orbitBreath: 1.0
                SequentialAnimation on orbitBreath {
                    loops: Animation.Infinite
                    running: window.animationsEnabled
                    NumberAnimation { to: 1.035; duration: 3500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 3500; easing.type: Easing.InOutSine }
                }

                property real pitchBreath: 0
                SequentialAnimation on pitchBreath {
                    loops: Animation.Infinite; running: window.animationsEnabled
                    NumberAnimation { to: 3.5; duration: 4200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -3.5; duration: 4200; easing.type: Easing.InOutSine }
                }

                property real yawBreath: 0
                SequentialAnimation on yawBreath {
                    loops: Animation.Infinite; running: window.animationsEnabled
                    NumberAnimation { to: 2.5; duration: 5100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -2.5; duration: 5100; easing.type: Easing.InOutSine }
                }

                property real rollBreath: 0
                SequentialAnimation on rollBreath {
                    loops: Animation.Infinite; running: window.animationsEnabled
                    NumberAnimation { to: 1.5; duration: 5800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1.5; duration: 5800; easing.type: Easing.InOutSine }
                }

                transform: Translate { y: Math.round((25 * (1.0 - introClock)) + centralHub.levitation) }

                Item {
                    id: orbitScene
                    anchors.fill: parent
                    transform: [
                        Rotation { axis { x: 1; y: 0; z: 0 } angle: centralHub.pitchBreath },
                        Rotation { axis { x: 0; y: 1; z: 0 } angle: centralHub.yawBreath },
                        Rotation { axis { x: 0; y: 0; z: 1 } angle: centralHub.rollBreath }
                    ]

                    Canvas {
                        z: -10
                        x: -290
                        y: -162
                        width: 580
                        height: 324
                        opacity: 0.25

                        property real currentScale: centralHub.orbitBreath
                        onCurrentScaleChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.beginPath();
                            var currentRx = 200 * window.orbitRadiusScale * currentScale;
                            var currentRy = 100 * window.orbitRadiusScale * currentScale;
                            for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                                var xx = width/2 + Math.cos(i) * currentRx;
                                var yy = height/2 + Math.sin(i) * currentRy;
                                if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                            }
                            ctx.strokeStyle = window.textAccent;
                            ctx.lineWidth = 1.5;
                            ctx.setLineDash([4, 10]);
                            ctx.stroke();
                        }
                        Behavior on opacity { NumberAnimation { duration: 1500 } }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0 
                    scale: 0.95 + (0.05 * window.secondPulse) 
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2
                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: window.textFont
                            font.weight: Font.Black
                            font.pixelSize: 68
                            color: window.text
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: window.textFont
                            font.weight: Font.Bold
                            font.pixelSize: 24
                            color: window.textAccent
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 12
                            opacity: window.secondPulse > 1.02 ? 1.0 : 0.6 
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.family: window.textFont
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: window.subtext0
                        opacity: 0.9
                    }
                }

                Item {
                    parent: orbitScene
                    anchors.fill: parent
                    opacity: window.weatherContentOpacity
                    
                    scale: window.transitionScale 
                    transform: Translate { x: Math.round(window.weatherContentOffset * 1.5) }

                    Repeater {
                        id: hourRepeater
                        model: {
                            if (!window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[window.weatherView]) return [];
                            
                            if (window.weatherView === 0) {
                                let nowMs = window.currentTime.getTime();
                                let targetYear = window.currentTime.getFullYear();
                                
                                let flatList = [];
                                for (let d = 0; d < window.weatherData.forecast.length; d++) {
                                    let dayData = window.weatherData.forecast[d];
                                    if (!dayData || !dayData.hourly) continue;
                                    for (let i = 0; i < dayData.hourly.length; i++) {
                                        let hObj = dayData.hourly[i];
                                        let tStr = hObj.time || "00:00";
                                        let dStr = dayData.date || ""; 
                                        
                                        let pDate = new Date(dStr + " " + targetYear + " " + tStr);
                                        let pTimeMs = pDate.getTime();
                                        
                                        if (!isNaN(pTimeMs)) {
                                            flatList.push({ item: hObj, time: pTimeMs, dateStr: dStr });
                                        }
                                    }
                                }
                                
                                if (flatList.length === 0) {
                                    return (window.weatherData.forecast[0].hourly || []).slice(0, 8);
                                }
                                
                                let bestIdx = 0;
                                let minDiff = 999999999999;
                                for (let k = 0; k < flatList.length; k++) {
                                    let diff = Math.abs(flatList[k].time - nowMs);
                                    if (diff < minDiff) {
                                        minDiff = diff;
                                        bestIdx = k;
                                    }
                                }
                                
                                let upcoming = [];
                                let currentDayStr = flatList[bestIdx] ? flatList[bestIdx].dateStr : "";
                                for (let i = bestIdx; i < flatList.length && upcoming.length < 8; i++) {
                                    if (flatList[i].dateStr !== currentDayStr) break;
                                    upcoming.push(flatList[i].item);
                                }
                                
                                return upcoming;
                                
                            } else {
                                return (window.weatherData.forecast[window.weatherView].hourly || []).slice(0, 8);
                            }
                        }
                        
                        delegate: Item {
                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true
                            layer.textureSize: Qt.size(width * 2, height * 2)
                            
                            property int mCount: hourRepeater.count
                            property bool isToday: window.weatherView === 0
                            property bool isHighlighted: isToday && index === window.activeHourIndex
                            
                            property real rx: 200 * window.orbitRadiusScale * centralHub.orbitBreath
                            property real ry: 100 * window.orbitRadiusScale * centralHub.orbitBreath
                            
                            property int relIdx: isToday ? (index - window.activeHourIndex) : index
                            
                            property real targetAngleDeg: isToday ? (65 + (relIdx * 30)) : (index * (360 / Math.max(1, mCount)))
                            
                            property real orbitOffset: isToday ? 0 : (window.globalOrbitAngle * (180 / Math.PI) * -1.5)
                            property real osc: isToday ? (Math.sin(window.globalOrbitAngle * 10 + index) * 5) : 0 
                            
                            property real rad: (targetAngleDeg + orbitOffset + osc + window.transitionSpin) * (Math.PI / 180)

                            x: Math.round(Math.cos(rad) * rx - width/2)
                            y: Math.round(Math.sin(rad) * ry - height/2)
                            z: Math.sin(rad) * 100 
                            
                            scale: isHighlighted ? 1.4 : (isToday ? (0.95 + 0.20 * Math.sin(rad)) : (0.90 + 0.25 * Math.sin(rad)))
                            opacity: isHighlighted ? 1.0 : (isToday ? (0.7 + 0.3 * ((Math.sin(rad) + 1) / 2)) : (0.65 + 0.35 * ((Math.sin(rad) + 1) / 2)))

                            width: 50; height: 82
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 25
                                color: isHighlighted ? window.textAccent : (hrMa.containsMouse ? window.surface2 : window.surface0)
                                border.color: isHighlighted ? "transparent" : (hrMa.containsMouse ? window.textAccent : window.surface1)
                                border.width: 1
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                ColumnLayout {
                                    anchors.centerIn: parent 
                                    spacing: 2
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.time
                                        font.family: window.textFont; font.weight: Font.Bold; font.pixelSize: 11
                                        color: isHighlighted ? window.base : (hrMa.containsMouse ? window.text : window.overlay1)
                                    }
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || (window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : "")
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                        color: isHighlighted ? window.base : (modelData.hex || window.text)
                                        
                                        transform: Translate { y: hrMa.containsMouse ? -2 : 0 }
                                        Behavior on transform {
                                            enabled: window.animationsEnabled
                                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                        }
                                    }
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter; text: modelData.temp + "°"
                                        font.family: window.textFont; font.weight: Font.Black; font.pixelSize: 13
                                        color: isHighlighted ? window.base : window.text 
                                    }
                                }
                            }
                            MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: window.panelMargin
                width: window.sidePanelWidth
                height: window.sidePanelHeight
                color: Qt.alpha(window.surface0, 0.2) 
                radius: 16
                border.color: Qt.alpha(window.surface1, 0.4)
                border.width: 1
                z: 10 

                opacity: introCalendar
                transform: Translate { x: -30 * (1.0 - introCalendar) }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.sidePanelInnerMargin
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: prevMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: 15 }
                            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.setMonthOffset(window.targetMonthOffset - 1) }
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: window.textFont
                            font.weight: Font.Black
                            font.pixelSize: 16
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter
                            
                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.snappedCalendarTextOffset }
                        }

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: nextMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: 15 }
                            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.setMonthOffset(window.targetMonthOffset + 1) }
                        }

                        
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: window.textFont
                                font.weight: Font.Black
                                font.pixelSize: 13
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 5
                        columnSpacing: 5

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                color: isToday ? window.textAccent : (dayMa.containsMouse ? Qt.alpha(window.surface2, 0.4) : "transparent")
                                radius: 10
                                scale: dayMa.containsMouse ? 1.2 : 1.0
                                border.color: isToday ? window.surface0 : (dayMa.containsMouse ? window.overlay0 : "transparent")
                                border.width: isToday || dayMa.containsMouse ? 1 : 0
                                
                                Behavior on color {
                                    enabled: window.animationsEnabled
                                    ColorAnimation { duration: 150 }
                                }
                                Behavior on scale {
                                    enabled: window.animationsEnabled
                                    NumberAnimation { duration: 250; easing.type: Easing.OutBack }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: window.textFont
                                    font.weight: isToday ? Font.Black : Font.Bold
                                    font.pixelSize: 15
                                    color: isToday ? window.base : (isCurrentMonth ? window.text : window.surface0)
                                    Behavior on color {
                                        enabled: window.animationsEnabled
                                        ColorAnimation { duration: 200 }
                                    }
                                }

                                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: window.panelMargin
                width: window.sidePanelWidth
                height: window.sidePanelHeight
                z: 10 

                opacity: introWeather
                transform: Translate { x: 30 * (1.0 - introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: 16
                        
                        MouseArea { 
                            id: wPrevMa; width: 30; height: 30; hoverEnabled: true
                            property bool buttonEnabled: window.targetWeatherView > 0
                            cursorShape: buttonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (buttonEnabled) window.setWeatherView(window.targetWeatherView - 1) 
                            
                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: window.animationsEnabled && wPrevMa.buttonEnabled
                                NumberAnimation { to: -3; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }
                            
                            Text { 
                                anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                                color: parent.containsMouse && parent.buttonEnabled ? window.textAccent : (parent.buttonEnabled ? window.overlay1 : window.overlay0)
                                transform: Translate { x: parent.containsMouse && parent.buttonEnabled ? -5 : wPrevMa.pulseOffset }
                                Behavior on transform {
                                    enabled: window.animationsEnabled
                                    NumberAnimation { duration: 250; easing.type: Easing.OutBack }
                                }
                            }
                        }
                        
                        Text {
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].day_full.toUpperCase() : "LOADING..."
                            font.family: window.textFont
                            font.weight: Font.Black
                            font.pixelSize: 16
                            color: window.text
                        }
                        
                        MouseArea { 
                            id: wNextMa; width: 30; height: 30; hoverEnabled: true
                            property bool buttonEnabled: window.targetWeatherView < 4 && window.weatherData
                            cursorShape: buttonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (buttonEnabled) window.setWeatherView(window.targetWeatherView + 1)
                            
                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: window.animationsEnabled && wNextMa.buttonEnabled
                                NumberAnimation { to: 3; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }
                            
                            Text { 
                                anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 20
                                color: parent.containsMouse && parent.buttonEnabled ? window.textAccent : (parent.buttonEnabled ? window.overlay1 : window.overlay0)
                                transform: Translate { x: parent.containsMouse && parent.buttonEnabled ? 5 : wNextMa.pulseOffset }
                                Behavior on transform {
                                    enabled: window.animationsEnabled
                                    NumberAnimation { duration: 250; easing.type: Easing.OutBack }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight 
                        spacing: -5
                        
                        Text {
                            Layout.alignment: Qt.AlignHCenter 
                            text: Math.round(window.displayedTemp) + "°"
                            font.family: window.textFont
                            font.weight: Font.Black
                            font.pixelSize: 64
                            color: window.tempGlowColor
                            style: Text.Outline; 
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(window.crust, 0.4)
                            
                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on styleColor { ColorAnimation { duration: 300 } }
                        }
                        
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].desc : ""
                            font.family: window.textFont
                            font.weight: Font.Bold
                            font.pixelSize: 13
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            
                            opacity: window.weatherContentOpacity
                            transform: Translate { x: window.snappedWeatherTextOffset }
                        }
                    }

                    Item { Layout.fillHeight: true } 

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 0
                        Layout.bottomMargin: 0
                        spacing: 10

                        Repeater {
                            model: 4

                            Item {
                                width: 62
                                height: 90
                                scale: gaugeMa.containsMouse ? 1.08 : 1.0
                                Behavior on scale {
                                    enabled: window.animationsEnabled
                                    NumberAnimation { duration: 250; easing.type: Easing.OutBack }
                                }

                                property var forecast: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? window.weatherData.forecast[window.targetWeatherView] : null

                                property string gaugeIcon: index === 0 ? "󰖝" : index === 1 ? "󰖙" : index === 2 ? "󰖗" : "󰔄"
                                property string gaugeLbl: index === 0 ? "WIND" : index === 1 ? "HUMID" : index === 2 ? "RAIN" : "FEELS"

                                property string gaugeVal: forecast ? (
                                    index === 0 ? forecast.wind + "m/s" :
                                    index === 1 ? forecast.humidity + "%" :
                                    index === 2 ? (forecast.pop !== undefined ? forecast.pop + "%" : "0%") :
                                    forecast.feels_like + "°"
                                ) : ""

                                property real gaugeFill: forecast ? (
                                    index === 0 ? Math.min(1.0, forecast.wind / 25.0) :
                                    index === 1 ? forecast.humidity / 100.0 :
                                    index === 2 ? forecast.pop / 100.0 :
                                    Math.max(0.0, Math.min(1.0, (forecast.feels_like + 15) / 55.0))
                                ) : 0.0
                                
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 60; height: 60; radius: 30
                                    color: window.textAccent
                                    opacity: gaugeMa.containsMouse ? 0.3 : 0.0
                                    Behavior on opacity {
                                        enabled: window.animationsEnabled
                                        NumberAnimation { duration: 200 }
                                    }
                                }

                                Item {
                                    id: circleItem
                                    width: 60; height: 60
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    
                                    Canvas {
                                        id: gaugeCanvas
                                        anchors.fill: parent
                                        rotation: -90 
                                        
                                        property real animProgress: parent.parent.gaugeFill
                                        
                                        Behavior on animProgress {
                                            enabled: window.animationsEnabled
                                            NumberAnimation { duration: 1000; easing.type: Easing.OutExpo }
                                        }
                                        
                                        onAnimProgressChanged: requestPaint()
                                        
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var r = width / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(r, r, r - 3, 0, 2 * Math.PI);
                                            ctx.strokeStyle = Qt.alpha(window.text, 0.1);
                                            ctx.lineWidth = 2.5;
                                            ctx.stroke();
                                            
                                            if (animProgress > 0) {
                                                ctx.beginPath();
                                                ctx.arc(r, r, r - 3, 0, animProgress * 2 * Math.PI);
                                                var grad = ctx.createLinearGradient(0, 0, width, height);
                                                grad.addColorStop(0, window.timeAccent);
                                                grad.addColorStop(1, window.sapphire);
                                                ctx.strokeStyle = grad;
                                                ctx.lineWidth = 3;
                                                ctx.lineCap = "round";
                                                ctx.stroke();
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.parent.gaugeVal
                                        font.family: window.textFont
                                        font.weight: Font.Black
                                        font.pixelSize: 12
                                        color: window.text
                                    }
                                }
                                
                                RowLayout {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 3
                                    
                                    Text { 
                                        text: parent.parent.gaugeIcon
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 13
                                        color: gaugeMa.containsMouse ? window.textAccent : window.overlay0
                                        Behavior on color {
                                            enabled: window.animationsEnabled
                                            ColorAnimation { duration: 200 }
                                        }
                                    }
                                    Text { 
                                        text: parent.parent.gaugeLbl
                                        font.family: window.textFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 11
                                        color: window.overlay0 
                                    }
                                }
                                
                                MouseArea { id: gaugeMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }

            
        }
    }
}
