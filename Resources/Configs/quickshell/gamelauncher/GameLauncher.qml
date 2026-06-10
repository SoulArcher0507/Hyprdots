//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt.labs.platform 1.1

ShellRoot {
    id: root
    property bool edgeAnimationsEnabled: true
    property bool borderAnimationsEnabled: true
    property bool popupAnimationsEnabled: true
    property FileView _animStateFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/state.ini"
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: this.reload()
        onLoaded: root._parseAnimState(this.text())
    }
    function _parseAnimState(txt) {
        if (!txt || txt === "") return;
        var lines = txt.split("\n"); var inSection = false; var legacyValue = undefined; var foundBorderValue = false;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "[quickshell.theme]") { inSection = true; continue; }
            if (inSection) {
                if (line.startsWith("[")) break;
                if (line.startsWith("borderAnimationsEnabled=")) {
                    root.borderAnimationsEnabled = (line.split("=")[1].trim().toLowerCase() === "true");
                    foundBorderValue = true;
                    continue;
                }
                if (line.startsWith("popupAnimationsEnabled=")) {
                    root.popupAnimationsEnabled = (line.split("=")[1].trim().toLowerCase() === "true");
                    continue;
                }
                if (line.startsWith("edgeAnimationsEnabled=")) {
                    legacyValue = (line.split("=")[1].trim().toLowerCase() === "true");
                }
            }
        }
        if (!foundBorderValue && legacyValue !== undefined)
            root.borderAnimationsEnabled = legacyValue;
        if (legacyValue !== undefined)
            root.edgeAnimationsEnabled = legacyValue;
    }
    readonly property string textFont: "Fira Sans Semibold"
    readonly property string iconFont: "CaskaydiaMono Nerd Font"
    readonly property string nerdFont: "Iosevka Nerd Font"
    property var _j: ({ special:{background:"#222222",foreground:"#cccccc"}, colors:{color0:"#111111",color1:"#dc2f2f",color2:"#98c379",color3:"#d19a66",color4:"#61afef",color5:"#c678dd",color6:"#56b6c2",color7:"#abb2bf",color8:"#3e4451",color9:"#e06c75",color10:"#98c379",color11:"#d19a66",color12:"#61afef",color13:"#c678dd",color14:"#56b6c2",color15:"#ffffff"}, quickshell:{bg:"",fg:"",accent:"",accent2:"",success:"",warning:"",danger:"",muted:""} })
    property FileView _colorFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/colors.json"
        watchChanges: true; Component.onCompleted: this.reload(); onFileChanged: this.reload()
        onLoaded: root._applyColors(this.text())
    }
    function _applyColors(txt) {
        if (!txt || txt === "") return;
        try {
            const parsed = JSON.parse(txt);
            function pick(a, b) { return (b !== undefined && b !== null && b !== "") ? b : a; }
            const s = parsed.special || {}, c = parsed.colors || {}, q = parsed.quickshell || {};
            _j = { special:{background:pick(_j.special.background,s.background),foreground:pick(_j.special.foreground,s.foreground)},
                colors:{color0:pick(_j.colors.color0,c.color0),color1:pick(_j.colors.color1,c.color1),color2:pick(_j.colors.color2,c.color2),color3:pick(_j.colors.color3,c.color3),color4:pick(_j.colors.color4,c.color4),color5:pick(_j.colors.color5,c.color5),color6:pick(_j.colors.color6,c.color6),color7:pick(_j.colors.color7,c.color7),color8:pick(_j.colors.color8,c.color8),color9:pick(_j.colors.color9,c.color9),color10:pick(_j.colors.color10,c.color10),color11:pick(_j.colors.color11,c.color11),color12:pick(_j.colors.color12,c.color12),color13:pick(_j.colors.color13,c.color13),color14:pick(_j.colors.color14,c.color14),color15:pick(_j.colors.color15,c.color15)},
                quickshell:{bg:pick(_j.quickshell.bg,q.bg),fg:pick(_j.quickshell.fg,q.fg),accent:pick(_j.quickshell.accent,q.accent),accent2:pick(_j.quickshell.accent2,q.accent2),success:pick(_j.quickshell.success,q.success),warning:pick(_j.quickshell.warning,q.warning),danger:pick(_j.quickshell.danger,q.danger),muted:pick(_j.quickshell.muted,q.muted)} };
        } catch (e) { console.warn("GameLauncher: colors.json parse error:", e); }
    }
    function _toRgb(x) {
        if (typeof x === "string") { let s = x.trim(); if (s[0]==="#") s=s.slice(1); if (s.length===3) s=s.split("").map(ch=>ch+ch).join(""); if (s.length===8) s=s.slice(2); return {r:parseInt(s.slice(0,2),16)/255,g:parseInt(s.slice(2,4),16)/255,b:parseInt(s.slice(4,6),16)/255}; }
        else if (x && x.r !== undefined) return {r:x.r,g:x.g,b:x.b}; return {r:0,g:0,b:0};
    }
    function _pick(deflt) { for (let i=1;i<arguments.length;++i){const v=arguments[i];if(v!==undefined&&v!==null&&v!=="")return v;} return deflt; }
    function mix(a,b,t) { const A=_toRgb(a),B=_toRgb(b),k=Math.max(0,Math.min(1,t)); return Qt.rgba(A.r*(1-k)+B.r*k,A.g*(1-k)+B.g*k,A.b*(1-k)+B.b*k,1.0); }
    function surface(level) { return mix(bg,fg,Math.max(0,Math.min(1,level))); }
    function alpha(c,a) { const rgb=_toRgb(c); return Qt.rgba(rgb.r||0,rgb.g||0,rgb.b||0,(a===undefined||a===null)?1.0:a); }
    readonly property color bg: _pick("#222222",_j?.quickshell?.bg,_j?.special?.background)
    readonly property color fg: _pick("#cccccc",_j?.quickshell?.fg,_j?.special?.foreground)
    readonly property color c4: _pick("#61afef",_j?.colors?.color4)
    readonly property color c5: _pick("#c678dd",_j?.colors?.color5)
    readonly property color c6: _pick("#56b6c2",_j?.colors?.color6)
    readonly property color c8: _pick("#3e4451",_j?.colors?.color8)
    readonly property color accentClr: _pick(c4,_j?.quickshell?.accent)
    readonly property color accent2Clr: _pick(c6,_j?.quickshell?.accent2)
    readonly property color base: surface(0.10)
    readonly property color text: fg
    readonly property color subtext0: mix(bg,fg,0.6)
    readonly property color overlay0: mix(bg,fg,0.3)
    readonly property color overlay1: mix(bg,fg,0.4)
    readonly property color surface0: surface(0.06)
    readonly property color surface1: surface(0.08)
    readonly property color surface2: surface(0.12)
    readonly property color accent: accentClr
    readonly property color moduleBorderColor: mix(bg,fg,0.35)
    readonly property color moduleFontColor: accentClr

    readonly property real popupOpenWidth: 960
    readonly property real popupOpenHeight: 460
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2

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

    function closeOtherPanels() {
        Quickshell.execDetached(["qs","ipc","-p",Quickshell.env("HOME")+"/.config/quickshell","call","global","closeShellPopups"]);
        Quickshell.execDetached(["qs","ipc","-p",Quickshell.env("HOME")+"/.config/quickshell/launcher","call","launcher","hide"]);
        Quickshell.execDetached(["qs","ipc","-p",Quickshell.env("HOME")+"/.config/quickshell/overview","call","overview","close"]);
    }
    function _openGameLauncher() {
        root.closeOtherPanels();
        search.text=""; gameListModel.applyFilter(""); gameList.positionViewAtBeginning();
        root._showGameLauncherPopup(); search.forceActiveFocus(); gameListModel.reload();
    }
    function _showGameLauncherPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999)
            return;
        popupEnterAnim.stop();
        if (root.popupAnimationsEnabled)
            popupEnterAnim.start();
        else
            root.openInstant();
    }
    function _hideGameLauncherPopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        if (root.popupAnimationsEnabled)
            popupExitAnim.start();
        else
            root.closeInstant();
    }

    function openInstant() {
        popupExitAnim.stop();
        popupEnterAnim.stop();
        popupTargetVisible = true;
        popupMounted = true;
        popupCardOpacity = 1.0;
        popupCardScaleX = 1.0;
        popupCardScaleY = 1.0;
        popupCardWidth = popupOpenWidth;
        popupCardHeight = popupOpenHeight;
        popupCardRadius = popupOpenRadius;
        popupCardLift = 0;
    }

    function closeInstant() {
        popupEnterAnim.stop();
        popupExitAnim.stop();
        popupTargetVisible = false;
        popupMounted = false;
        popupCardOpacity = 0.0;
        popupCardScaleX = 0.42;
        popupCardScaleY = 0.24;
        popupCardWidth = popupClosedWidth;
        popupCardHeight = popupClosedHeight;
        popupCardRadius = popupClosedRadius;
        popupCardLift = popupOriginLift();
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
    IpcHandler {
        target: "gamelauncher"
        function toggle(): void {
            if (root.popupTargetVisible) { root._hideGameLauncherPopup(); }
            else { root._openGameLauncher(); }
        }
        function show(): void { root._openGameLauncher(); }
        function hide(): void { root._hideGameLauncherPopup(); }
    }

    PanelWindow {
        id: win; visible: root.popupMounted; focusable: root.popupMounted; color: "transparent"
        anchors { top:true; bottom:true; left:true; right:true }
        Component.onCompleted: { try { if (win.WlrLayershell) win.WlrLayershell.layer = WlrLayer.Overlay; } catch(e){} }

        Item {
            anchors.fill: parent; focus: true
            Keys.onReleased: e => { if (e.key===Qt.Key_Escape) { root._hideGameLauncherPopup(); e.accepted=true; } }
            MouseArea { anchors.fill: parent; onClicked: root._hideGameLauncherPopup() }

            Item {
                id: cardShell; width: root.popupCardWidth; height: root.popupCardHeight; anchors.centerIn: parent
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

                Rectangle {
                    id: card; anchors.fill: parent
                    radius: root.popupCardRadius; color: root.base; border.color: root.moduleBorderColor; border.width: 1; clip: true

                    AnimatedBorder {
                        anchors.fill: parent
                        radius: card.radius
                        borderWidth: card.border.width
                        accentColor: root.accent
                        animationsEnabled: root.borderAnimationsEnabled
                    }

                    MouseArea { anchors.fill:parent; acceptedButtons:Qt.AllButtons; onClicked:{} }

                    property real globalOrbitAngle: 0
                    NumberAnimation on globalOrbitAngle { from:0;to:Math.PI*2;duration:90000;loops:Animation.Infinite;running:root.popupMounted&&root.edgeAnimationsEnabled }
                    Rectangle { width:parent.width*0.8;height:width;radius:width/2;x:(parent.width*0.5-width/2)+Math.cos(card.globalOrbitAngle*1.5)*80;y:(parent.height*0.1-height/2)+Math.sin(card.globalOrbitAngle*1.5)*100;opacity:0.04;color:root.accent;z:0 }
                    Rectangle { width:parent.width*0.6;height:width;radius:width/2;x:(parent.width*0.2-width/2)+Math.sin(card.globalOrbitAngle*1.2)*-60;y:(parent.height*0.8-height/2)+Math.cos(card.globalOrbitAngle*1.2)*-80;opacity:0.03;color:root.c5;z:0 }

                Text {
                    id: bgIcon; anchors.centerIn: parent
                    property real drift: 0
                    SequentialAnimation on drift { loops:Animation.Infinite;running:root.popupMounted&&root.edgeAnimationsEnabled; NumberAnimation{to:-15;duration:6000;easing.type:Easing.InOutSine} NumberAnimation{to:0;duration:6000;easing.type:Easing.InOutSine} }
                    transform: Translate { y: bgIcon.drift }
                    text: "\u{F11B}"; font.family:root.nerdFont; font.pixelSize:320; color:root.accent
                    opacity: 0.03+(0.01*Math.sin(card.globalOrbitAngle*4)); z:0
                }

                ColumnLayout {
                    id: content; anchors.fill:parent; anchors.margins:25; spacing:12; z:1

                    TextField {
                        id: search; Layout.fillWidth:true; Layout.preferredHeight:34
                        placeholderText: "Search games…"; leftPadding:16; rightPadding:16
                        verticalAlignment: TextInput.AlignVCenter; color:root.text
                        placeholderTextColor: root.overlay1; font.pixelSize:14; font.family:root.textFont
                        background: Rectangle { color:"#0dffffff"; border.color:search.activeFocus?root.accent:"#1affffff"; border.width:1; radius:10 }
                        onTextChanged: gameListModel.applyFilter(text)
                        Keys.onReturnPressed: {
                            if (filteredGames.count > 0) {
                                const first = filteredGames.get(0);
                                if (first && first.appid) launchGame(first.appid);
                            }
                        }
                        Keys.onEscapePressed: root._hideGameLauncherPopup()
                        Keys.onRightPressed: { gameList.forceActiveFocus(); gameList.currentIndex = 0; }
                    }

                    ListView {
                        id: gameList; Layout.fillWidth:true; Layout.fillHeight:true
                        orientation: ListView.Horizontal; clip:true; spacing:16
                        boundsBehavior: Flickable.StopAtBounds; model:filteredGames
                        highlight:null; currentIndex:-1; highlightMoveDuration:0; highlightMoveVelocity:-1

                        MouseArea {
                            id: gameListScrollHandler
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false
                            propagateComposedEvents: true

                            property var flickable: gameList
                            property real wheelStep: 120
                            property real touchpadMultiplier: 2.4
                            property bool scrollEnabled: !!flickable
                                && flickable.contentWidth > flickable.width
                                && flickable.interactive !== false

                            function clamp(value, minValue, maxValue) {
                                return Math.max(minValue, Math.min(maxValue, value));
                            }

                            function minContentX() {
                                if (!flickable)
                                    return 0;
                                return Number(flickable.originX || 0);
                            }

                            function maxContentX() {
                                if (!flickable)
                                    return 0;
                                const minX = gameListScrollHandler.minContentX();
                                return Math.max(
                                    minX,
                                    minX + Number(flickable.contentWidth || 0) - Number(flickable.width || 0)
                                );
                            }

                            onWheel: (wheel) => {
                                if (!gameListScrollHandler.scrollEnabled || !gameListScrollHandler.flickable)
                                    return;

                                const pixelDelta = Number(
                                    wheel.pixelDelta
                                        ? (wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.pixelDelta.y)
                                        : 0
                                );
                                const angleDelta = Number(
                                    wheel.angleDelta
                                        ? (wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y)
                                        : 0
                                );

                                let scrollDelta = 0;
                                if (pixelDelta !== 0)
                                    scrollDelta = pixelDelta * gameListScrollHandler.touchpadMultiplier;
                                else if (angleDelta !== 0)
                                    scrollDelta = (angleDelta / 120) * gameListScrollHandler.wheelStep;

                                if (scrollDelta === 0)
                                    return;

                                if (gameListScrollHandler.flickable.cancelFlick)
                                    gameListScrollHandler.flickable.cancelFlick();

                                gameListScrollHandler.flickable.contentX = gameListScrollHandler.clamp(
                                    gameListScrollHandler.flickable.contentX - scrollDelta,
                                    gameListScrollHandler.minContentX(),
                                    gameListScrollHandler.maxContentX()
                                );
                                wheel.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: { if(currentIndex>=0&&currentIndex<filteredGames.count){const item=filteredGames.get(currentIndex);if(item&&item.appid)launchGame(item.appid);} }
                        Keys.onEscapePressed: root._hideGameLauncherPopup()
                        Keys.onLeftPressed: { if(currentIndex<=0){search.forceActiveFocus();currentIndex=-1;}else{currentIndex--;positionViewAtIndex(currentIndex,ListView.Contain);} }
                        Keys.onRightPressed: { if(currentIndex<filteredGames.count-1){currentIndex++;positionViewAtIndex(currentIndex,ListView.Contain);} }

                        delegate: Item {
                            id: gameCard; width: 180; height: gameList.height
                            property bool hovered: false

                            Column {
                                anchors.fill: parent; spacing: 8

                                Rectangle {
                                    id: coverContainer; width: 180; height: parent.height - 40
                                    radius: 12; clip: true; color: "#05ffffff"
                                    border.width: 1
                                    border.color: (gameCard.hovered || gameList.currentIndex === index) ? root.accent : "#1affffff"
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    scale: (gameCard.hovered || gameList.currentIndex === index) ? 1.04 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    transformOrigin: Item.Center

                                    Image {
                                        id: coverImg; anchors.fill:parent; anchors.margins:0
                                        source: model.cover !== "" ? ("file://" + model.cover) : (model.header !== "" ? ("file://" + model.header) : "")
                                        fillMode: Image.PreserveAspectCrop; asynchronous:true; smooth:true; mipmap:true
                                        visible: status === Image.Ready
                                    }

                                    Rectangle {
                                        anchors.fill:parent; radius:12; color:root.alpha(root.accent,0.10); visible:coverImg.status!==Image.Ready
                                        Column {
                                            anchors.centerIn:parent; spacing:8
                                            Text { anchors.horizontalCenter:parent.horizontalCenter; text:"\u{F1B7}"; font.family:root.nerdFont; font.pixelSize:48; color:root.accent }
                                            Text { anchors.horizontalCenter:parent.horizontalCenter; text:model.name?model.name:"?"; color:root.overlay1; font.pixelSize:12; font.family:root.textFont; width:150; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill:parent; radius:12
                                        gradient: Gradient {
                                            GradientStop { position:0.0; color:"transparent" }
                                            GradientStop { position:1.0; color:root.alpha(root.accent,0.15) }
                                        }
                                        opacity: (gameCard.hovered || gameList.currentIndex === index) ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }

                                Text {
                                    width: 180; text: model.name || ""
                                    color: (gameCard.hovered || gameList.currentIndex === index) ? root.text : root.subtext0
                                    font.pixelSize: 12; font.family: root.textFont
                                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor
                                onEntered: gameCard.hovered = true; onExited: gameCard.hovered = false
                                onClicked: launchGame(model.appid)
                            }
                        }

                        ScrollBar.horizontal: ScrollBar {
                            id: hbar; policy:ScrollBar.AsNeeded; hoverEnabled:true
                            implicitHeight:10; minimumSize:0.08; active:hovered||pressed||gameList.moving
                            background: Rectangle { anchors.fill:parent;radius:height/2;color:root.moduleBorderColor;border.color:root.moduleBorderColor;opacity:hbar.active?1.0:0.7 }
                            contentItem: Rectangle { radius:height/2;border.width:1;border.color:root.moduleBorderColor;color:root.moduleFontColor }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:true; Layout.preferredHeight:36; radius:10; color:"#0dffffff"; border.color:"#1affffff"; border.width:1
                        RowLayout {
                            anchors.fill:parent; anchors.leftMargin:14; anchors.rightMargin:14; spacing:20
                            Row {
                                spacing:6; Layout.alignment:Qt.AlignVCenter
                                Rectangle {
                                    width:hintSteam.implicitWidth+10;height:20;radius:4;color:root.alpha(root.surface2,0.4);border.color:root.alpha(root.overlay0,0.3);border.width:1;anchors.verticalCenter:parent.verticalCenter
                                    Text { id:hintSteam;anchors.centerIn:parent;text:"⏎";color:root.overlay1;font.pixelSize:10;font.family:root.textFont }
                                }
                                Text { text:"launch"; color:root.overlay0; font.pixelSize:11; font.family:root.textFont; anchors.verticalCenter:parent.verticalCenter }
                            }
                            Row {
                                spacing:6; Layout.alignment:Qt.AlignVCenter
                                Rectangle {
                                    width:hintNav.implicitWidth+10;height:20;radius:4;color:root.alpha(root.surface2,0.4);border.color:root.alpha(root.overlay0,0.3);border.width:1;anchors.verticalCenter:parent.verticalCenter
                                    Text { id:hintNav;anchors.centerIn:parent;text:"← →";color:root.overlay1;font.pixelSize:10;font.family:root.textFont }
                                }
                                Text { text:"navigate"; color:root.overlay0; font.pixelSize:11; font.family:root.textFont; anchors.verticalCenter:parent.verticalCenter }
                            }
                            Item { Layout.fillWidth:true }
                            Text { Layout.alignment:Qt.AlignVCenter; text:filteredGames.count+" games"; color:root.overlay0; font.pixelSize:11; font.family:root.textFont }
                        }
                    }
                }
            }
        }
    }
    }

    function launchGame(appid) {
        if (!appid) return;
        root._hideGameLauncherPopup();
        Quickshell.execDetached(["sh","-c","steam steam://rungameid/"+appid+" &"]);
    }

    ListModel { id: filteredGames }
    QtObject {
        id: gameListModel; property var all: []
        function applyFilter(q) {
            filteredGames.clear();
            const needle = String(q||"").toLowerCase(); let items = [];
            if (!needle) { items = all; }
            else {
                for (let i=0;i<all.length;i++) {
                    const g=all[i], gn=g.name.toLowerCase(); let score=-1;
                    if(gn===needle) score=100; else if(gn.startsWith(needle)) score=50; else if(gn.includes(needle)) score=10;
                    else { let si=0; for(let j=0;j<gn.length&&si<needle.length;j++){if(needle[si]===gn[j])si++;} if(si===needle.length)score=8;
                        else if(needle.length>=3){let m=0,na=gn.split("");for(let k=0;k<needle.length;k++){let idx=na.indexOf(needle[k]);if(idx!==-1){m++;na[idx]=null;}} let mr=m/needle.length;if(mr>=0.75){let lp=Math.abs(needle.length-gn.length)/Math.max(gn.length,1);let fp=(gn[0]!==needle[0])?1.0:0.0;let fs=(5*mr)-lp-fp;if(fs>0)score=fs;}} }
                    if(score>0) items.push({app:g,score:score});
                }
                items.sort(function(a,b){if(a.score!==b.score)return b.score-a.score;return a.app.name.toLowerCase().localeCompare(b.app.name.toLowerCase());});
                items = items.map(function(item){return item.app;});
            }
            if (items.length>0) filteredGames.append(items);
            if (gameList.count>0) gameList.positionViewAtBeginning();
            gameList.currentIndex = -1;
        }
        function reload() { procList.running = true; }
    }
    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/gamelauncher/"
    Process {
        id: procList; command:["bash",root.scriptDir+"list_steam_games.sh"]
        stdout: StdioCollector { waitForEnd:true
            onStreamFinished: {
                try { const games=JSON.parse(String(text||"[]")); games.sort(function(a,b){return a.name.toLowerCase().localeCompare(b.name.toLowerCase());}); gameListModel.all=games; gameListModel.applyFilter(search.text); }
                catch(e){ console.warn("GameLauncher: failed to parse game list:",e); }
            }
        }
    }
    Component.onCompleted: { Qt.application.organization="Quickshell"; Qt.application.domain="quickshell.org"; gameListModel.reload(); }
}
