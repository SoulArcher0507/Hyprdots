import QtQuick
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../../theme" as ThemePkg

Item {
    id: systemTrayWidget

    required property var bar
    property real scaleFactor: 1.0

    readonly property color hoverColor: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.08)

    property var activeMenu: null
    property var launcherIconCache: ({})
    property int launcherIconCacheRevision: 0

    signal menuOpened(var menuId)
    readonly property color borderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color textPrimary: ThemePkg.Theme.foreground
    readonly property color backgroundPrimary: ThemePkg.Theme.surface(0.10)

    readonly property int baseIconSize: 22
    readonly property int baseIconSpacing: 8
    readonly property int baseIconPadding: 8

    readonly property int iconSize: baseIconSize * scaleFactor
    readonly property int iconSpacing: baseIconSpacing * scaleFactor
    readonly property int iconPadding: baseIconPadding * scaleFactor

    readonly property int trayContentWidth: trayRepeater.count > 0 ? trayRepeater.count * (iconSize + iconSpacing) - iconSpacing : 0

    width: trayContentWidth > 0 ? trayContentWidth + iconPadding * 2 : 0

    readonly property string launcherScriptDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/launcher/"

    function normalizeIconKey(value) {
        let key = String(value || "").toLowerCase().trim();
        if (key === "")
            return "";

        key = key.replace(/^file:\/\//, "");
        key = key.replace(/^image:\/\/icon\//, "");
        key = key.split("?")[0].split("/").pop();
        key = key.replace(/\.desktop$/, "");

        return key.replace(/[^a-z0-9]/g, "");
    }

    function cacheLauncherIcon(cache, key, iconPath) {
        const normalized = normalizeIconKey(key);
        if (normalized !== "" && iconPath && !cache[normalized])
            cache[normalized] = iconPath;
    }

    function cacheKnownTrayAliases(cache, app, iconPath) {
        const iconName = normalizeIconKey(app.iconName);
        const desktop = normalizeIconKey(app.desktop);
        const name = normalizeIconKey(app.name);

        if (iconName === "orgtelegramdesktop" || desktop === "orgtelegramdesktopdesktop" || name === "telegram") {
            cacheLauncherIcon(cache, "TelegramDesktop", iconPath);
            cacheLauncherIcon(cache, "telegram-desktop", iconPath);
            cacheLauncherIcon(cache, "telegram", iconPath);
        }

        if (iconName === "kwalletmanager" || desktop === "orgkdekwalletmanager" || name === "kwalletmanager") {
            cacheLauncherIcon(cache, "kwallet", iconPath);
            cacheLauncherIcon(cache, "kwalletd", iconPath);
            cacheLauncherIcon(cache, "org.kde.kwalletd", iconPath);
            cacheLauncherIcon(cache, "org.kde.kwalletmanager", iconPath);
        }
    }

    function trayIconSource(trayItem, revision) {
        revision;

        const nativeIcon = String(trayItem.icon || "");
        const candidates = [
            trayItem.id,
            trayItem.title,
            trayItem.tooltipTitle,
            nativeIcon
        ];

        for (let i = 0; i < candidates.length; i++) {
            const key = normalizeIconKey(candidates[i]);
            const iconPath = key !== "" ? launcherIconCache[key] : "";
            if (iconPath)
                return iconPath.startsWith("file://") ? iconPath : "file://" + iconPath;

            if (key.includes("kwallet") || key.includes("kdewallet")) {
                const kwalletIcon = launcherIconCache["kwalletmanager"];
                if (kwalletIcon)
                    return kwalletIcon.startsWith("file://") ? kwalletIcon : "file://" + kwalletIcon;
            }

            if (key.includes("telegram")) {
                const telegramIcon = launcherIconCache["orgtelegramdesktop"] || launcherIconCache["telegram"] || launcherIconCache["telegramdesktop"];
                if (telegramIcon)
                    return telegramIcon.startsWith("file://") ? telegramIcon : "file://" + telegramIcon;
            }
        }

        return nativeIcon;
    }

    Process {
        id: launcherIconLoader
        command: ["bash", systemTrayWidget.launcherScriptDir + "list_apps.sh"]
        running: true

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const apps = JSON.parse(String(text || "[]"));
                    const cache = {};
                    for (let i = 0; i < apps.length; i++) {
                        const app = apps[i];
                        if (!app || !app.icon)
                            continue;

                        systemTrayWidget.cacheLauncherIcon(cache, app.name, app.icon);
                        systemTrayWidget.cacheLauncherIcon(cache, app.desktop, app.icon);
                        systemTrayWidget.cacheLauncherIcon(cache, app.iconName, app.icon);
                        systemTrayWidget.cacheKnownTrayAliases(cache, app, app.icon);
                    }
                    systemTrayWidget.launcherIconCache = cache;
                    systemTrayWidget.launcherIconCacheRevision += 1;
                } catch (e) {
                    console.warn("SystemTray: failed to parse launcher icon cache:", e);
                }
            }
        }
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: iconSpacing

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            MouseArea {
                id: trayMouseArea

                property SystemTrayItem trayItem: modelData
                property bool tipVisible: false
                property real tipRectX: 0
                property real tipRectY: 0

                width: iconSize
                height: iconSize
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true

                property real _anchorX: 0
                property real _anchorY: 0

                Timer {
                    id: trayTipShow
                    interval: 250
                    repeat: false
                    onTriggered: {
                        if (trayMouseArea.containsMouse && trayItem.title && trayItem.title.length > 0) {
                            trayMouseArea.tipVisible = true;
                        }
                    }
                }

                function updateTipAnchor() {
                    const host = QsWindow.window && QsWindow.window.contentItem ? QsWindow.window.contentItem : null;
                    const p = trayMouseArea.mapToItem(host, 0, 0);
                    trayMouseArea.tipRectX = p.x;
                    trayMouseArea.tipRectY = p.y;
                }

                onPressed: function (mouse) {
                    if (mouse.button === Qt.RightButton) {
                        if (trayItem.hasMenu) {
                            const gx = mouse.screenX;
                            const gy = mouse.screenY;
                            const w = QsWindow.window;
                            if (w && w.mapFromGlobal) {
                                const pt = w.mapFromGlobal(gx, gy);
                                trayMouseArea._anchorX = pt.x;
                                trayMouseArea._anchorY = pt.y;
                            } else {
                                const p = trayMouseArea.mapToItem(w ? w.contentItem : null, 0, 0);
                                trayMouseArea._anchorX = p.x + trayMouseArea.width / 2;
                                trayMouseArea._anchorY = p.y;
                            }
                            menuAnchor.openAnimated();
                        }
                    }
                }

                onClicked: function (mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        trayItem.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItem.secondaryActivate();
                    }
                }

                onWheel: function (wheel) {
                    trayItem.scroll(wheel.angleDelta.x, wheel.angleDelta.y);
                }

                onEntered: {
                    trayMouseArea.updateTipAnchor();
                    trayTipShow.start();
                }

                onExited: {
                    trayTipShow.stop();
                    trayMouseArea.tipVisible = false;
                }

                TrayMenu {
                    id: menuAnchor
                    trayItemMenu: trayItem.menu
                    scaleFactor: systemTrayWidget.scaleFactor

                    anchor.window: QsWindow.window
                    anchor.rect.x: trayMouseArea._anchorX - 1
                    anchor.rect.y: QsWindow.window.height - Math.round(6 * systemTrayWidget.scaleFactor)
                    anchor.rect.width: 2
                    anchor.rect.height: 1
                    anchor.edges: Edges.Bottom

                    onVisibleChanged: {
                        if (visible) {
                            if (systemTrayWidget.activeMenu && systemTrayWidget.activeMenu !== menuAnchor) {
                                if (systemTrayWidget.activeMenu.beginAnimatedClose) {
                                    systemTrayWidget.activeMenu.beginAnimatedClose();
                                } else {
                                    systemTrayWidget.activeMenu.visible = false;
                                }
                            }
                            systemTrayWidget.activeMenu = menuAnchor;
                        } else {
                            if (systemTrayWidget.activeMenu === menuAnchor) {
                                systemTrayWidget.activeMenu = null;
                            }
                        }
                    }
                }

                Rectangle {
                    id: backgroundRect
                    anchors.fill: parent
                    color: trayMouseArea.containsMouse ? hoverColor : "transparent"
                    radius: 4
                    transformOrigin: Item.Center
                    scale: trayMouseArea.pressed ? 0.95 : (trayMouseArea.containsMouse ? 1.05 : 1.0)

                    Behavior on scale {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutQuart
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Image {
                    id: iconImage
                    anchors.centerIn: parent
                    width: iconSize - 2
                    height: iconSize - 2
                    source: systemTrayWidget.trayIconSource(trayItem, systemTrayWidget.launcherIconCacheRevision)
                    fillMode: Image.PreserveAspectFit
                    smooth: true

                    Text {
                        anchors.centerIn: parent
                        text: trayItem.title ? trayItem.title.charAt(0).toUpperCase() : "?"
                        color: textPrimary
                        font.pixelSize: 12 * scaleFactor
                        font.bold: true
                        renderType: Text.NativeRendering
                        visible: parent.status === Image.Error || parent.status === Image.Null
                    }
                }

                PopupWindow {
                    id: hoverTip
                    color: "transparent"
                    visible: trayMouseArea.tipVisible && trayItem.title && trayItem.title.length > 0
                    anchor.window: QsWindow.window
                    property int gap: Math.round(5 * systemTrayWidget.scaleFactor)
                    anchor.rect.x: trayMouseArea.tipRectX
                    anchor.rect.y: trayMouseArea.tipRectY + trayMouseArea.height + gap
                    anchor.rect.width: trayMouseArea.width
                    anchor.rect.height: 1
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom

                    property int hpad: Math.round(8 * systemTrayWidget.scaleFactor)
                    property int vpad: Math.round(6 * systemTrayWidget.scaleFactor)
                    readonly property int tipW: tipText.implicitWidth + 2 * hpad
                    readonly property int tipH: tipText.implicitHeight + 2 * vpad

                    implicitWidth: tipW
                    implicitHeight: tipH

                    Rectangle {
                        anchors.fill: parent
                        radius: 10 * systemTrayWidget.scaleFactor
                        color: systemTrayWidget.backgroundPrimary
                        border.width: 1 * systemTrayWidget.scaleFactor
                        border.color: systemTrayWidget.borderColor
                        opacity: 1.0

                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            text: trayItem.title
                            color: ThemePkg.Theme.accent
                            font.pixelSize: Math.round(13 * systemTrayWidget.scaleFactor)
                            font.family: "Fira Sans Semibold"
                            renderType: Text.NativeRendering
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }
}
