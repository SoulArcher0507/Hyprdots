pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt.labs.platform 1.1
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "." as Hyprshot
import "../modules/bar/widgets" as BarWidgets

Hyprshot.FreezeScreen {
    id: root
    visible: false
    property bool autoStart: true
    property bool sessionActive: false

    property var _j: ({
            special: {
                background: "#222222",
                foreground: "#cccccc"
            },
            colors: {
                color3: "#d19a66",
                color4: "#61afef",
                color6: "#56b6c2"
            },
            quickshell: {
                bg: "",
                fg: "",
                accent: "",
                accent2: ""
            }
        })

    property FileView _colorFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/colors.json"
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: this.reload()
        onLoaded: root._applyColors(this.text())
    }

    function _applyColors(txt) {
        if (!txt || txt === "")
            return;

        try {
            const parsed = JSON.parse(txt);

            function pick(a, b) {
                return (b !== undefined && b !== null && b !== "") ? b : a;
            }

            const s = parsed.special || {};
            const c = parsed.colors || {};
            const q = parsed.quickshell || {};

            root._j = {
                special: {
                    background: pick(root._j.special.background, s.background),
                    foreground: pick(root._j.special.foreground, s.foreground)
                },
                colors: {
                    color3: pick(root._j.colors.color3, c.color3),
                    color4: pick(root._j.colors.color4, c.color4),
                    color6: pick(root._j.colors.color6, c.color6)
                },
                quickshell: {
                    bg: pick(root._j.quickshell.bg, q.bg),
                    fg: pick(root._j.quickshell.fg, q.fg),
                    accent: pick(root._j.quickshell.accent, q.accent),
                    accent2: pick(root._j.quickshell.accent2, q.accent2)
                }
            };
        } catch (e) {
            console.warn("HyprQuickshot: colors.json parse error:", e);
        }
    }

    function _pick(deflt) {
        for (let i = 1; i < arguments.length; ++i) {
            const v = arguments[i];
            if (v !== undefined && v !== null && v !== "")
                return v;
        }
        return deflt;
    }

    function _toRgb(x) {
        if (typeof x === "string") {
            let s = x.trim();
            if (s[0] === "#")
                s = s.slice(1);
            if (s.length === 3)
                s = s.split("").map(ch => ch + ch).join("");
            if (s.length === 8)
                s = s.slice(2);
            return {
                r: parseInt(s.slice(0, 2), 16) / 255,
                g: parseInt(s.slice(2, 4), 16) / 255,
                b: parseInt(s.slice(4, 6), 16) / 255
            };
        } else if (x && x.r !== undefined) {
            return {
                r: x.r,
                g: x.g,
                b: x.b
            };
        }

        return {
            r: 0,
            g: 0,
            b: 0
        };
    }

    function mix(a, b, t) {
        const A = root._toRgb(a);
        const B = root._toRgb(b);
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(
            A.r * (1 - k) + B.r * k,
            A.g * (1 - k) + B.g * k,
            A.b * (1 - k) + B.b * k,
            1.0
        );
    }

    function alpha(c, a) {
        const rgb = root._toRgb(c);
        return Qt.rgba(
            rgb.r || 0,
            rgb.g || 0,
            rgb.b || 0,
            (a === undefined || a === null) ? 1.0 : a
        );
    }

    readonly property color bg: root._pick("#222222", root._j?.quickshell?.bg, root._j?.special?.background)
    readonly property color fg: root._pick("#cccccc", root._j?.quickshell?.fg, root._j?.special?.foreground)
    readonly property color c3: root._pick("#d19a66", root._j?.colors?.color3)
    readonly property color c4: root._pick("#61afef", root._j?.colors?.color4)
    readonly property color c6: root._pick("#56b6c2", root._j?.colors?.color6)
    readonly property color text: root.fg
    readonly property color subtext0: root.mix(root.bg, root.fg, 0.6)
    readonly property color accent: root._pick(root.c4, root._j?.quickshell?.accent)
    readonly property color accent2: root._pick(root.c6, root._j?.quickshell?.accent2)
    readonly property color panelColor: root.alpha(root.mix(root.bg, root.fg, 0.18), 0.98)
    readonly property color panelBorderColor: root.mix(root.bg, root.fg, 0.35)
    readonly property color idleButtonColor: root.alpha(root.mix(root.bg, root.fg, 0.14), 0.98)
    readonly property color hoverButtonColor: root.alpha(root.mix(root.bg, root.fg, 0.22), 0.99)
    readonly property color selectionOutlineColor: root.alpha(root.modeColor(root.mode), 0.96)
    readonly property int panelPadding: 8
    readonly property var regionShapeOptions: [
        { key: "rectangle", label: "Rectangle" },
        { key: "circle", label: "Circle" },
        { key: "freehand", label: "Freehand" }
    ]

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 40000; loops: Animation.Infinite; running: true
    }

    property bool edgeAnimationsEnabled: true

    property FileView _animStateFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/state.ini"
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: this.reload()
        onLoaded: root._parseAnimState(this.text())
    }

    function _parseAnimState(txt) {
        if (!txt || txt === "") return;
        var lines = txt.split("\n");
        var inSection = false;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "[quickshell.theme]") {
                inSection = true;
                continue;
            }
            if (inSection) {
                if (line.startsWith("[")) break;
                if (line.startsWith("edgeAnimationsEnabled=")) {
                    var val = line.split("=")[1].trim().toLowerCase();
                    root.edgeAnimationsEnabled = (val === "true");
                    return;
                }
            }
        }
    }

    component InlineElectricBorder: BarWidgets.ElectricBorder {
        anchors.fill: parent
        accentColor: root.accent
        radius: 12
        borderWidth: 1
        animationsEnabled: root.edgeAnimationsEnabled
    }

    function modeColor(modeName) {
        switch (modeName) {
        case "region":
            return root.c3
        case "window":
            return root.accent
        case "screen":
            return root.accent2
        case "picker":
            return root.mix(root.c4, root.c6, 0.45)
        case "ocr":
            return root.mix(root.c3, root.c4, 0.55)
        default:
            return root.fg
        }
    }

    property var activeScreen: null

    Connections {
        target: Hyprland
        enabled: root.activeScreen === null

        function onFocusedMonitorChanged() {
            root.syncActiveScreen()
        }
    }

    targetScreen: activeScreen

    property var hyprlandMonitor: Hyprland.focusedMonitor
    property string tempPath
    property bool captureReady: false
    property bool captureFailed: false
    property real captureOffsetX: 0
    property real captureOffsetY: 0
    property bool selectionQueued: false
    property int captureRetryCount: 0
    readonly property int captureMaxRetries: 3
    property var queuedSelection: null
    property string lastOutputPath: ""
    property bool lastSaveWasFile: true
    property string lastPickedColor: ""
    property color pickerPreviewColor: root.modeColor("picker")
    property string lastExtractedText: ""
    property string ocrStatusText: ""
    property bool ocrResultVisible: false
    property bool saveToFileEnabled: true
    property bool externalPickerLaunching: false

    property string mode: "region"
    property string selectedRegionShape: "rectangle"
    property bool regionShapeMenuOpen: false

    function syncActiveScreen() {
        const monitor = Hyprland.focusedMonitor
        if (!monitor)
            return

        for (const screen of Quickshell.screens) {
            if (screen.name === monitor.name) {
                root.activeScreen = screen
                break
            }
        }
    }

    onModeChanged: {
        if (root.mode !== "region")
            root.regionShapeMenuOpen = false
        if (root.mode !== "picker")
            root.pickerPreviewColor = root.modeColor("picker")
        if (root.mode !== "ocr")
            root.ocrResultVisible = false
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.regionShapeMenuOpen) {
                root.regionShapeMenuOpen = false
                return
            }
            if (root.ocrResultVisible) {
                root.ocrResultVisible = false
                return
            }
            root.finish()
        }
    }
    Timer {
        id: captureTimeoutTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (root.sessionActive && !root.captureReady && captureProcess.running) {
                console.warn("HyprQuickshot: grim capture timed out after 5s")
                root.captureReady = false
                root.captureFailed = true
                root.visible = true
            }
        }
    }
 
    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function localPath(pathOrUrl) {
        const value = String(pathOrUrl || "")
        if (value.startsWith("file://"))
            return decodeURIComponent(value.slice(7))
        if (value.startsWith("file:"))
            return decodeURIComponent(value.slice(5))
        return value
    }

    function fileUrl(pathOrUrl) {
        const value = root.localPath(pathOrUrl)
        return value !== "" ? `file://${encodeURI(value)}` : ""
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function shapeIconSource(shapeKey) {
        switch (shapeKey) {
        case "circle":
            return Qt.resolvedUrl("icons/circle.svg")
        case "freehand":
            return Qt.resolvedUrl("icons/freehand.svg")
        default:
            return Qt.resolvedUrl("icons/region.svg")
        }
    }

    function modeIconSource(modeName) {
        switch (modeName) {
        case "picker":
            return Qt.resolvedUrl("icons/picker.svg")
        case "ocr":
            return Qt.resolvedUrl("icons/ocr.svg")
        case "clipboard":
            return Qt.resolvedUrl("icons/folder.svg")
        default:
            return ""
        }
    }

    function screenshotsDir() {
        const picturesRoot = root.localPath(StandardPaths.writableLocation(StandardPaths.PicturesLocation))
        const baseDir = picturesRoot !== "" ? picturesRoot : (Quickshell.env("HOME") + "/Pictures")
        return baseDir + "/Screenshots"
    }

    function notifyScreenshotSaved(outputPath, savedToFile) {
        if (!outputPath || outputPath === "") {
            root.finish()
            return
        }

        const quotedOutputPath = root.shellQuote(outputPath)
        const summary = root.shellQuote(savedToFile ? "Screenshot saved" : "Screenshot copied to clipboard")
        const body = root.shellQuote("Click to open or edit with ksnip")
        
        let actions = "--action=default=Open"
        if (savedToFile) {
            actions += " --action=folder='Open Folder'"
        }

        const script = `
            action=$(notify-send --app-name=HyprQuickshot --icon=${quotedOutputPath} --hint=STRING:image-path:${quotedOutputPath} --expire-time=12000 ${actions} ${summary} ${body})
            if [ "$action" = "default" ]; then
                ksnip ${quotedOutputPath}
            elif [ "$action" = "folder" ]; then
                dolphin --select ${quotedOutputPath}
            fi
        `

        Quickshell.execDetached(["sh", "-c", script])
        root.finish()
    }

    function resetSessionState() {
        if (captureProcess.running)
            captureProcess.running = false
        if (screenshotProcess.running)
            screenshotProcess.running = false
        if (colorPreviewProcess.running)
            colorPreviewProcess.running = false
        if (hyprpickerProcess.running)
            hyprpickerProcess.running = false
        if (ocrProcess.running)
            ocrProcess.running = false
        if (ocrCopyProcess.running)
            ocrCopyProcess.running = false
        captureTimeoutTimer.stop()
        captureRetryTimer.stop()
        root.visible = false
        root.frozenImagePath = ""
        root.captureReady = false
        root.captureFailed = false
        root.selectionQueued = false
        root.captureRetryCount = 0
        root.queuedSelection = null
        root.lastOutputPath = ""
        root.lastSaveWasFile = true
        root.lastPickedColor = ""
        root.pickerPreviewColor = root.modeColor("picker")
        root.lastExtractedText = ""
        root.ocrStatusText = ""
        root.ocrResultVisible = false
        root.saveToFileEnabled = true
        root.externalPickerLaunching = false
        root.mode = "region"
        root.selectedRegionShape = "rectangle"
        root.regionShapeMenuOpen = false
        regionSelector.resetSelection()
        windowSelector.resetSelection()
        colorPickerOverlay.cursorX = colorPickerOverlay.width / 2
        colorPickerOverlay.cursorY = colorPickerOverlay.height / 2
    }

    function open() {
        if (root.sessionActive && (captureProcess.running || screenshotProcess.running || hyprpickerProcess.running || ocrProcess.running))
            return

        root.resetSessionState()
        root.sessionActive = true
        root.syncActiveScreen()
        root.startCapture()
    }

    function finish() {
        if (root.autoStart) {
            Qt.quit()
            return
        }

        root.sessionActive = false
        root.resetSessionState()
    }

    function startCapture() {
        const timestamp = Date.now()
        root.tempPath = Quickshell.cachePath(`screenshot-${timestamp}.png`)
        root.frozenImagePath = ""
        root.captureReady = false
        root.captureFailed = false
        const monitor = root.hyprlandMonitor || {}
        const outputName = String(monitor.name || "")
        root.captureOffsetX = outputName !== "" ? 0 : (Number(monitor.x) || 0)
        root.captureOffsetY = outputName !== "" ? 0 : (Number(monitor.y) || 0)
        const quotedTempPath = root.shellQuote(root.tempPath)
        const captureCommand = outputName !== ""
            ? `grim -l 0 -o ${root.shellQuote(outputName)} ${quotedTempPath}`
            : `grim -l 0 ${quotedTempPath}`
        captureProcess.command = ["sh", "-c", `mkdir -p "$(dirname ${quotedTempPath})" && ${captureCommand}`]
        captureProcess.running = true
        captureTimeoutTimer.restart()
    }

    Component.onCompleted: {
        if (root.autoStart)
            root.open()
    }

    Process {
        id: captureProcess
        running: false

        onExited: function(exitCode) {
            captureTimeoutTimer.stop()
            if (!root.sessionActive)
                return

            if (exitCode === 0) {
                root.captureRetryCount = 0
                root.captureReady = true
                root.captureFailed = false
                root.frozenImagePath = root.tempPath
                if (!root.visible)
                    root.visible = true
                root.flushQueuedSelection()
                return
            }

            root.captureReady = false
            root.captureFailed = true
            console.warn("HyprQuickshot: grim capture failed with exit code", exitCode)

            if (root.selectionQueued && root.captureRetryCount < root.captureMaxRetries) {
                root.captureRetryCount++
                console.warn("HyprQuickshot: retrying grim capture (attempt",
                    root.captureRetryCount, "of", root.captureMaxRetries + ")")
                captureRetryTimer.restart()
            } else if (root.selectionQueued) {
                console.warn("HyprQuickshot: grim capture failed after",
                    root.captureMaxRetries, "retries, giving up")
                root.selectionQueued = false
                root.queuedSelection = null
                if (!root.visible)
                    root.visible = true
            } else {
                if (!root.visible)
                    root.visible = true
            }
        }
    }

    Timer {
        id: captureRetryTimer
        interval: 200
        running: false
        repeat: false
        onTriggered: root.startCapture()
    }

    Process {
        id: screenshotProcess
        running: false

        onExited: function(exitCode) {
            if (!root.sessionActive)
                return

            if (exitCode === 0) {
                root.notifyScreenshotSaved(root.lastOutputPath, root.lastSaveWasFile)
                return
            }

            root.visible = true
            console.warn("HyprQuickshot: export failed with exit code", exitCode)
            if (screenshotStderr.text && screenshotStderr.text.trim() !== "")
                console.warn("HyprQuickshot stderr:", screenshotStderr.text.trim())
        }

        stdout: StdioCollector {
            id: screenshotStdout
        }
        stderr: StdioCollector {
            id: screenshotStderr
        }

    }

    Process {
        id: colorPreviewProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode !== 0)
                return

            const hex = colorPreviewStdout.text.trim()
            if (hex !== "")
                root.pickerPreviewColor = `#${hex}`
        }

        stdout: StdioCollector {
            id: colorPreviewStdout
        }
        stderr: StdioCollector {
            id: colorPreviewStderr
        }
    }

    Process {
        id: hyprpickerProcess
        running: false

        onExited: function(exitCode) {
            const color = hyprpickerStdout.text.trim()
            if (exitCode === 0 && color !== "") {
                root.lastPickedColor = color
            } else if (exitCode !== 0) {
                console.warn("HyprQuickshot: hyprpicker failed with exit code", exitCode)
                if (hyprpickerStderr.text && hyprpickerStderr.text.trim() !== "")
                    console.warn("HyprQuickshot hyprpicker stderr:", hyprpickerStderr.text.trim())
            }

            if (root.sessionActive)
                root.finish()
        }

        stdout: StdioCollector {
            id: hyprpickerStdout
        }
        stderr: StdioCollector {
            id: hyprpickerStderr
        }
    }

    Process {
        id: ocrProcess
        running: false

        onExited: function(exitCode) {
            if (!root.sessionActive)
                return

            root.visible = true
            root.ocrResultVisible = true

            if (exitCode === 0) {
                root.lastExtractedText = ocrStdout.text.replace(/\s+$/, "")
                root.ocrStatusText = root.lastExtractedText !== ""
                    ? "Text extracted and copied to the clipboard."
                    : "No text detected in the selected area."
                return
            }

            root.lastExtractedText = ""
            if (exitCode === 64) {
                root.ocrStatusText = "Install tesseract to enable screen text extraction."
            } else {
                root.ocrStatusText = "Text extraction failed for the selected area."
            }

            console.warn("HyprQuickshot: OCR failed with exit code", exitCode)
            if (ocrStderr.text && ocrStderr.text.trim() !== "")
                console.warn("HyprQuickshot OCR stderr:", ocrStderr.text.trim())
        }

        stdout: StdioCollector {
            id: ocrStdout
        }
        stderr: StdioCollector {
            id: ocrStderr
        }
    }

    Process {
        id: ocrCopyProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0)
                return

            console.warn("HyprQuickshot: OCR clipboard copy failed with exit code", exitCode)
            if (ocrCopyStderr.text && ocrCopyStderr.text.trim() !== "")
                console.warn("HyprQuickshot OCR copy stderr:", ocrCopyStderr.text.trim())
        }

        stdout: StdioCollector {
            id: ocrCopyStdout
        }
        stderr: StdioCollector {
            id: ocrCopyStderr
        }
    }

    function normalizeSelection(selectionOrX, y, width, height) {
        if (selectionOrX !== null && typeof selectionOrX === "object" && selectionOrX.x !== undefined) {
            return {
                shape: String(selectionOrX.shape || "rectangle"),
                x: Number(selectionOrX.x) || 0,
                y: Number(selectionOrX.y) || 0,
                width: Number(selectionOrX.width) || 0,
                height: Number(selectionOrX.height) || 0,
                points: Array.isArray(selectionOrX.points) ? selectionOrX.points.map(function(point) {
                    return {
                        x: Number(point.x) || 0,
                        y: Number(point.y) || 0
                    }
                }) : []
            }
        }

        return {
            shape: "rectangle",
            x: Number(selectionOrX) || 0,
            y: Number(y) || 0,
            width: Number(width) || 0,
            height: Number(height) || 0,
            points: []
        }
    }

    function scaledSelection(selection) {
        const monitor = root.hyprlandMonitor || {}
        const scale = Number(monitor.scale) || 1
        const scaledX = Math.round((selection.x + root.captureOffsetX) * scale)
        const scaledY = Math.round((selection.y + root.captureOffsetY) * scale)
        const scaledWidth = Math.round(selection.width * scale)
        const scaledHeight = Math.round(selection.height * scale)
        const scaledPoints = (selection.points || []).map(function(point) {
            return {
                x: Math.round(point.x * scale),
                y: Math.round(point.y * scale)
            }
        })

        return {
            shape: selection.shape || "rectangle",
            x: scaledX,
            y: scaledY,
            width: scaledWidth,
            height: scaledHeight,
            points: scaledPoints
        }
    }

    function selectionDrawCommand(selection) {
        if (selection.shape === "circle") {
            const radius = Math.round(Math.min(selection.width, selection.height) / 2)
            const centerX = Math.round(selection.width / 2)
            const centerY = Math.round(selection.height / 2)
            return `circle ${centerX},${centerY} ${centerX + radius},${centerY}`
        }

        if (selection.shape === "freehand" && selection.points.length >= 3) {
            const polygon = selection.points.map(function(point) {
                return `${point.x},${point.y}`
            }).join(" ")
            return polygon !== "" ? `polygon ${polygon}` : ""
        }

        return ""
    }

    function queueSelection(selectionOrX, y, width, height) {
        const selection = root.normalizeSelection(selectionOrX, y, width, height)
        if (selection.width <= 0 || selection.height <= 0)
            return

        root.queuedSelection = selection
        root.selectionQueued = true

        if (root.captureFailed && !captureProcess.running) {
            root.captureRetryCount = 0
            root.startCapture()
        }

        root.flushQueuedSelection()
    }

    function flushQueuedSelection() {
        if (!root.selectionQueued || !root.captureReady || screenshotProcess.running || !root.queuedSelection)
            return

        root.selectionQueued = false
        const sel = root.queuedSelection
        root.queuedSelection = null
        root.saveScreenshot(sel)
    }

    function saveScreenshot(selection) {
        const scaledSelection = root.scaledSelection(selection)
        const scaledX = scaledSelection.x
        const scaledY = scaledSelection.y
        const scaledWidth = scaledSelection.width
        const scaledHeight = scaledSelection.height

        if (scaledWidth <= 0 || scaledHeight <= 0)
            return

        const now = new Date()
        const timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss")
        const picturesDir = root.screenshotsDir()
        const outputPath = root.saveToFileEnabled
            ? `${picturesDir}/screenshot-${timestamp}.png`
            : Quickshell.cachePath(`clipboard-${timestamp}.png`)
        root.lastOutputPath = outputPath
        root.lastSaveWasFile = root.saveToFileEnabled
        const quotedTempPath = root.shellQuote(root.tempPath)
        const quotedPicturesDir = root.shellQuote(picturesDir)
        const quotedOutputPath = root.shellQuote(outputPath)
        const drawCommand = root.selectionDrawCommand(scaledSelection)
        let exportCommand =
            (root.saveToFileEnabled ? `mkdir -p ${quotedPicturesDir} && ` : "") +
            `if command -v magick >/dev/null 2>&1; then CROP_BIN=magick; ` +
            `elif command -v convert >/dev/null 2>&1; then CROP_BIN=convert; ` +
            `else exit 127; fi && `

        if (scaledSelection.shape === "rectangle" || drawCommand === "") {
            exportCommand += `env MAGICK_OCL_DEVICE=OFF "$CROP_BIN" ${quotedTempPath} -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} +repage ${quotedOutputPath}`
        } else {
            exportCommand +=
                `env MAGICK_OCL_DEVICE=OFF "$CROP_BIN" ${quotedTempPath} -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} +repage ` +
                `\\( -size ${scaledWidth}x${scaledHeight} xc:none -fill white -draw ${root.shellQuote(drawCommand)} \\) ` +
                `-alpha set -compose CopyOpacity -composite ${quotedOutputPath}`
        }

        exportCommand += ` && ` +
            `wl-copy --type image/png < ${quotedOutputPath} ; ` +
            `rm -f ${quotedTempPath} ; ` +
            (root.saveToFileEnabled ? "" : `(sleep 30 && rm -f ${quotedOutputPath}) & `)

        screenshotProcess.command = ["sh", "-c", exportCommand]

        screenshotProcess.running = true
        root.visible = false
    }

    function scaledPoint(mouseX, mouseY) {
        const monitor = root.hyprlandMonitor || {}
        const scale = Number(monitor.scale) || 1

        return {
            x: Math.max(0, Math.round((mouseX + root.captureOffsetX) * scale)),
            y: Math.max(0, Math.round((mouseY + root.captureOffsetY) * scale))
        }
    }

    function copyColorAt(mouseX, mouseY) {
        root.startHyprpickerColorPick()
    }

    function startHyprpickerColorPick() {
        if (!root.sessionActive)
            return

        if (captureProcess.running) {
            captureProcess.running = false
            captureTimeoutTimer.stop()
        }
        if (colorPreviewProcess.running)
            colorPreviewProcess.running = false

        root.regionShapeMenuOpen = false
        root.externalPickerLaunching = true
        root.lastPickedColor = ""
        root.mode = ""
        root.visible = false

        const pickerScript =
            `sleep 0.25; ` +
            `if ! command -v hyprpicker >/dev/null 2>&1; then ` +
            `notify-send --app-name=HyprQuickshot "Color picker unavailable" "hyprpicker is not installed"; ` +
            `exit 127; fi; ` +
            `if ! command -v wl-copy >/dev/null 2>&1; then ` +
            `notify-send --app-name=HyprQuickshot "Color picker unavailable" "wl-copy is not installed"; ` +
            `exit 127; fi; ` +
            `COLOR=$(hyprpicker -f hex -b -q); STATUS=$?; ` +
            `[ "$STATUS" -eq 0 ] || exit "$STATUS"; ` +
            `[ -n "$COLOR" ] || exit 1; ` +
            `printf %s "$COLOR" | wl-copy; ` +
            `notify-send --app-name=HyprQuickshot "Color copied" "$COLOR"; ` +
            `printf %s "$COLOR"`

        hyprpickerProcess.command = ["sh", "-lc", pickerScript]
        hyprpickerProcess.running = true
    }

    function refreshPickerPreviewColor(mouseX, mouseY) {
        if (!root.captureReady || colorPreviewProcess.running || !root.tempPath)
            return

        const point = root.scaledPoint(mouseX, mouseY)
        const quotedTempPath = root.shellQuote(root.tempPath)
        const formatArg = root.shellQuote(`%[hex:p{${point.x},${point.y}}]`)
        const command =
            `if command -v magick >/dev/null 2>&1; then PICK_BIN=magick; ` +
            `elif command -v convert >/dev/null 2>&1; then PICK_BIN=convert; ` +
            `else exit 127; fi && ` +
            `env MAGICK_OCL_DEVICE=OFF "$PICK_BIN" ${quotedTempPath} -alpha off -format ${formatArg} info:`

        colorPreviewProcess.command = ["sh", "-c", command]
        colorPreviewProcess.running = true
    }

    function extractTextFromSelection(selectionOrX, y, width, height) {
        if (!root.captureReady || ocrProcess.running || !root.tempPath)
            return

        const selection = root.normalizeSelection(selectionOrX, y, width, height)
        const scaledSelection = root.scaledSelection(selection)
        if (scaledSelection.width <= 0 || scaledSelection.height <= 0)
            return

        const cropPath = `/tmp/hyprquickshot-ocr-${Date.now()}.png`
        const quotedTempPath = root.shellQuote(root.tempPath)
        const quotedCropPath = root.shellQuote(cropPath)
        const command =
            `if ! command -v tesseract >/dev/null 2>&1; then exit 64; fi; ` +
            `if command -v magick >/dev/null 2>&1; then CROP_BIN=magick; ` +
            `elif command -v convert >/dev/null 2>&1; then CROP_BIN=convert; ` +
            `else exit 127; fi; ` +
            `CROP_PATH=${quotedCropPath}; ` +
            `"$CROP_BIN" ${quotedTempPath} -crop ${scaledSelection.width}x${scaledSelection.height}+${scaledSelection.x}+${scaledSelection.y} +repage "$CROP_PATH" || exit $?; ` +
            `TEXT=$(tesseract "$CROP_PATH" stdout 2>/dev/null); STATUS=$?; ` +
            `rm -f "$CROP_PATH"; ` +
            `[ "$STATUS" -eq 0 ] || exit "$STATUS"; ` +
            `if [ -n "$TEXT" ]; then printf %s "$TEXT" | wl-copy; fi; ` +
            `printf %s "$TEXT"`

        root.lastExtractedText = ""
        root.ocrStatusText = "Extracting text from the selected area..."
        root.ocrResultVisible = true
        ocrProcess.command = ["sh", "-c", command]
        ocrProcess.running = true
    }

    function copyExtractedText(text) {
        const value = String(text || "")
        if (value === "" || ocrCopyProcess.running)
            return

        ocrCopyProcess.command = ["sh", "-c", `printf %s ${root.shellQuote(value)} | wl-copy`]
        ocrCopyProcess.running = true
        root.ocrStatusText = "Text copied to the clipboard."
    }

    component HoldToggleBubble: Item {
        id: toggleBubble
        width: 48
        height: 48

        property bool isActive: true
        property bool triggered: false
        property real fillLevel: 0.0
        property real flashOpacity: 0.0
        property int holdDuration: 700
        property string tooltipText: ""
        property color accentColor: root.mix(root.c6, root.c4, 0.35)
        property color inactiveColor: root.mix(root.bg, root.fg, 0.22)
        readonly property bool hovered: toggleBubbleMouse.containsMouse
        readonly property color bubbleTopColor: Qt.lighter(isActive ? accentColor : inactiveColor, 1.15)
        readonly property color bubbleBottomColor: isActive ? accentColor : inactiveColor
        readonly property color bubbleBorderColor: isActive
            ? Qt.lighter(accentColor, 1.1)
            : root.alpha(root.panelBorderColor, hovered ? 0.95 : 0.78)
        readonly property color bubbleGlowColor: isActive ? accentColor : root.alpha(root.fg, 0.14)
        readonly property color bubblePulseColor: isActive ? accentColor : root.alpha(root.fg, 0.18)
        readonly property color bubbleWaveTopColor: root.mix(root.bg, root.fg, 0.94)
        readonly property color bubbleWaveBottomColor: root.bg
        readonly property color iconTint: isActive ? root.bg : root.text
        signal holdComplete

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 14
            height: width
            radius: width / 2
            color: "#000000"
            opacity: toggleBubble.isActive ? 0.14 : 0.10
            z: -3
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 18
            height: width
            radius: width / 2
            color: toggleBubble.bubbleGlowColor
            opacity: toggleBubble.isActive ? (toggleBubble.hovered ? 0.28 : 0.16) : (toggleBubble.hovered ? 0.12 : 0.06)
            z: -2

            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on opacity { NumberAnimation { duration: 220 } }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: true
                NumberAnimation {
                    to: toggleBubble.hovered ? 1.14 : 1.08
                    duration: toggleBubble.hovered ? 800 : 2000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.0
                    duration: toggleBubble.hovered ? 800 : 2000
                    easing.type: Easing.InOutSine
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: toggleBubble.bubblePulseColor
            opacity: pulseOpacity
            scale: pulseScale
            z: -1

            property real pulseOpacity: 0.0
            property real pulseScale: 1.0

            Timer {
                interval: 45
                running: parent.visible
                repeat: true
                onTriggered: {
                    const time = Date.now() / 1000
                    parent.pulseOpacity = (toggleBubble.isActive ? 0.22 : 0.12) + Math.sin(time * 2.5) * 0.08
                    parent.pulseScale = 1.01 + Math.cos(time * 3.0) * 0.02
                }
            }
        }

        Rectangle {
            id: toggleBubbleShell
            anchors.fill: parent
            radius: width / 2
            border.width: 1
            border.color: toggleBubble.bubbleBorderColor
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: toggleBubble.bubbleTopColor }
                GradientStop { position: 1.0; color: toggleBubble.bubbleBottomColor }
            }
            layer.enabled: true
            layer.smooth: true

            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
            anchors.fill: toggleBubbleShell
            radius: toggleBubbleShell.radius
            z: 1
            color: "transparent"
            border.width: 1
            border.color: root.alpha("#ffffff", toggleBubble.hovered ? 0.08 : 0.04)
        }

        Canvas {
            id: toggleWaveCanvas
            anchors.fill: parent
            visible: toggleBubble.fillLevel > 0.0
            opacity: 0.95
            z: 2
            property real wavePhase: 0.0

            NumberAnimation on wavePhase {
                running: toggleBubble.fillLevel > 0.0 && toggleBubble.fillLevel < 1.0
                loops: Animation.Infinite
                from: 0
                to: Math.PI * 2
                duration: 800
            }

            onWavePhaseChanged: requestPaint()
            Connections {
                target: toggleBubble
                function onFillLevelChanged() {
                    toggleWaveCanvas.requestPaint()
                }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (toggleBubble.fillLevel <= 0.001)
                    return

                const radius = width / 2
                const fillY = height * (1.0 - toggleBubble.fillLevel)
                ctx.save()
                ctx.beginPath()
                ctx.arc(radius, radius, radius, 0, 2 * Math.PI)
                ctx.clip()
                ctx.beginPath()
                ctx.moveTo(0, fillY)
                if (toggleBubble.fillLevel < 0.99) {
                    const waveAmp = 6 * Math.sin(toggleBubble.fillLevel * Math.PI)
                    const cp1y = fillY + Math.sin(toggleWaveCanvas.wavePhase) * waveAmp
                    const cp2y = fillY + Math.cos(toggleWaveCanvas.wavePhase + Math.PI) * waveAmp
                    ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY)
                    ctx.lineTo(width, height)
                    ctx.lineTo(0, height)
                } else {
                    ctx.lineTo(width, 0)
                    ctx.lineTo(width, height)
                    ctx.lineTo(0, height)
                }
                ctx.closePath()
                const grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, toggleBubble.bubbleWaveTopColor.toString())
                grad.addColorStop(1, toggleBubble.bubbleWaveBottomColor.toString())
                ctx.fillStyle = grad
                ctx.fill()
                ctx.restore()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: toggleBubbleShell.radius
            color: "#ffffff"
            opacity: toggleBubble.flashOpacity
            z: 3
        }

        Item {
            anchors.centerIn: parent
            width: 24
            height: 24
            z: 4

            Image {
                id: toggleBubbleIcon
                anchors.fill: parent
                source: root.modeIconSource("clipboard")
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
            }

            MultiEffect {
                anchors.fill: toggleBubbleIcon
                source: toggleBubbleIcon
                colorization: 1.0
                colorizationColor: toggleBubble.iconTint
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * toggleBubble.fillLevel
            clip: true
            visible: toggleBubble.fillLevel > 0.0
            z: 4

            Item {
                width: 24
                height: 24
                x: parent.width / 2 - width / 2
                y: (toggleBubble.height / 2) - (height / 2) - (toggleBubble.height - parent.height)

                Image {
                    id: toggleBubbleWaveIcon
                    anchors.fill: parent
                    source: root.modeIconSource("clipboard")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: toggleBubbleWaveIcon
                    source: toggleBubbleWaveIcon
                    colorization: 1.0
                    colorizationColor: root.text
                }
            }
        }

        ToolTip {
            id: toggleBubbleTip
            visible: toggleBubble.hovered
            delay: 250
            x: Math.round((toggleBubble.width - implicitWidth) / 2)
            y: -implicitHeight - 6
            text: toggleBubble.tooltipText
            contentItem: Text {
                text: toggleBubbleTip.text
                color: root.text
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            background: Rectangle {
                radius: 10
                color: root.alpha(root.bg, 0.96)
                border.width: 1
                border.color: root.alpha(root.panelBorderColor, 0.85)
            }
        }

        MouseArea {
            id: toggleBubbleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: {
                if (!toggleBubble.triggered) {
                    toggleDrainAnim.stop()
                    toggleFillAnim.start()
                }
            }
            onReleased: {
                if (!toggleBubble.triggered) {
                    toggleFillAnim.stop()
                    toggleDrainAnim.start()
                }
            }
            onCanceled: {
                if (!toggleBubble.triggered) {
                    toggleFillAnim.stop()
                    toggleDrainAnim.start()
                }
            }
        }

        NumberAnimation {
            id: toggleFillAnim
            target: toggleBubble
            property: "fillLevel"
            to: 1.0
            duration: toggleBubble.holdDuration * (1.0 - toggleBubble.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                if (!toggleBubble.triggered) {
                    toggleBubble.triggered = true
                    toggleBubble.flashOpacity = 0.6
                    toggleFlashDrainAnim.start()
                    toggleBubble.holdComplete()
                    toggleBubble.fillLevel = 0.0
                    toggleBubble.triggered = false
                }
            }
        }

        NumberAnimation {
            id: toggleDrainAnim
            target: toggleBubble
            property: "fillLevel"
            to: 0.0
            duration: 1000 * toggleBubble.fillLevel
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: toggleFlashDrainAnim
            target: toggleBubble
            property: "flashOpacity"
            to: 0.0
            duration: 450
            easing.type: Easing.OutExpo
        }
    }

    Hyprshot.RegionSelector {
        visible: !root.externalPickerLaunching && (root.mode === "region" || root.mode === "ocr") && !root.ocrResultVisible && !ocrProcess.running
        id: regionSelector
        anchors.fill: parent
 
        dimOpacity: 0.6
        borderRadius: 10.0
        outlineThickness: 2.0
        outlineColor: root.selectionOutlineColor
        selectionShape: root.mode === "ocr" ? "rectangle" : root.selectedRegionShape
 
        onRegionSelected: (selection) => {
            if (root.mode === "ocr")
                root.extractTextFromSelection(selection)
            else
                root.queueSelection(selection)
        }
    }
 
    Hyprshot.WindowSelector {
        visible: !root.externalPickerLaunching && root.mode === "window"
        id: windowSelector
        anchors.fill: parent
 
        monitor: root.hyprlandMonitor
        dimOpacity: 0.6
        borderRadius: 10.0
        outlineThickness: 2.0
        outlineColor: root.selectionOutlineColor
 
        onRegionSelected: (x, y, width, height) => {
            root.queueSelection(x, y, width, height)
        }
    }

    Item {
        id: colorPickerOverlay
        visible: !root.externalPickerLaunching && root.mode === "picker"
        anchors.fill: parent
        z: 4

        property real cursorX: width / 2
        property real cursorY: height / 2
        readonly property color livePreviewColor: root.pickerPreviewColor
        readonly property real lensSize: 160
        readonly property real lensZoom: 12
        readonly property real outputScale: Number(root.hyprlandMonitor?.scale) || 1
        readonly property real monitorOffX: root.captureOffsetX
        readonly property real monitorOffY: root.captureOffsetY

        readonly property real lensTargetX: cursorX - lensSize / 2
        readonly property real lensTargetY: cursorY - lensSize - 55
        readonly property real lensX: root.clamp(lensTargetX, 16, width - lensSize - 16)
        readonly property real lensY: lensTargetY < 16 ? (cursorY + 32) : lensTargetY

        function colorToHex(c) {
            var r = Math.round(c.r * 255).toString(16).toUpperCase().padStart(2, '0')
            var g = Math.round(c.g * 255).toString(16).toUpperCase().padStart(2, '0')
            var b = Math.round(c.b * 255).toString(16).toUpperCase().padStart(2, '0')
            return '#' + r + g + b
        }

        Image {
            id: pickerSourceImage
            source: root.captureReady ? root.fileUrl(root.tempPath) : ""
            visible: false
            cache: true
            asynchronous: false
        }

        Timer {
            id: pickerPreviewTimer
            interval: 250
            repeat: true
            running: colorPickerOverlay.visible && root.captureReady
            onTriggered: root.refreshPickerPreviewColor(colorPickerOverlay.cursorX, colorPickerOverlay.cursorY)
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor

            onPositionChanged: (mouse) => {
                colorPickerOverlay.cursorX = mouse.x
                colorPickerOverlay.cursorY = mouse.y
            }

            onPressed: (mouse) => {
                colorPickerOverlay.cursorX = mouse.x
                colorPickerOverlay.cursorY = mouse.y
            }

            onClicked: (mouse) => {
                colorPickerOverlay.cursorX = mouse.x
                colorPickerOverlay.cursorY = mouse.y
                root.copyColorAt(mouse.x, mouse.y)
            }
        }

        Item {
            id: pickerLens
            x: colorPickerOverlay.lensX
            y: colorPickerOverlay.lensY
            width: colorPickerOverlay.lensSize
            height: colorPickerOverlay.lensSize

            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                radius: width / 2
                color: "transparent"
                border.width: 8
                border.color: root.alpha("#000000", 0.18)
            }

            Item {
                id: lensContentSource
                anchors.fill: parent
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: lensMask
                }

                Image {
                    id: zoomedView
                    source: pickerSourceImage.source
                    smooth: false
                    fillMode: Image.Stretch
                    cache: true
                    visible: root.captureReady && pickerSourceImage.status === Image.Ready

                    width: pickerSourceImage.sourceSize.width / colorPickerOverlay.outputScale * colorPickerOverlay.lensZoom
                    height: pickerSourceImage.sourceSize.height / colorPickerOverlay.outputScale * colorPickerOverlay.lensZoom

                    x: colorPickerOverlay.lensSize / 2 - (colorPickerOverlay.cursorX + colorPickerOverlay.monitorOffX) * colorPickerOverlay.lensZoom
                    y: colorPickerOverlay.lensSize / 2 - (colorPickerOverlay.cursorY + colorPickerOverlay.monitorOffY) * colorPickerOverlay.lensZoom
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.06)
                }
            }

            Rectangle {
                id: lensMask
                anchors.fill: parent
                radius: width / 2
                antialiasing: true
                visible: false
                layer.enabled: true
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: root.alpha(colorPickerOverlay.livePreviewColor, 0.95)
                antialiasing: true
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: 1.5
                height: parent.height
                color: root.alpha(root.fg, 0.45)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                width: parent.width
                height: 1.5
                color: root.alpha(root.fg, 0.45)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: "transparent"
                border.width: 2
                border.color: root.alpha(colorPickerOverlay.livePreviewColor, 0.98)
                antialiasing: true
            }

            Rectangle {
                id: hexChip
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8
                width: hexRow.implicitWidth + 16
                height: 26
                radius: 13
                color: root.alpha(root.bg, 0.88)
                border.width: 1
                border.color: root.alpha(colorPickerOverlay.livePreviewColor, 0.55)
                antialiasing: true

                Row {
                    id: hexRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 3
                        color: colorPickerOverlay.livePreviewColor
                        border.width: 1
                        border.color: root.alpha(root.fg, 0.2)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: colorPickerOverlay.colorToHex(colorPickerOverlay.livePreviewColor)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: root.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

    }

    Rectangle {
        id: ocrResultPanel
        visible: root.mode === "ocr" && (root.ocrResultVisible || ocrProcess.running)
        z: 7
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 48, 760)
        readonly property real maxPanelHeight: Math.min(parent.height - 96, 440)
        readonly property real maxContentHeight: Math.max(120, maxPanelHeight - 146)
        height: Math.min(maxPanelHeight, ocrPanelContent.implicitHeight + 36)
        radius: 18
        color: root.alpha(root.mix(root.bg, root.fg, 0.12), 0.97)
        border.width: 1
        border.color: root.alpha(root.modeColor("ocr"), 0.45)
        antialiasing: true
        clip: true
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        InlineElectricBorder {
            radius: ocrResultPanel.radius
            borderWidth: ocrResultPanel.border.width
            accentColor: root.modeColor("ocr")
        }

        Rectangle {
            id: ocrPanelMask
            anchors.fill: parent
            radius: ocrResultPanel.radius
            visible: false
            antialiasing: true
            layer.enabled: true
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ocrPanelMask
            }

            Rectangle {
                width: parent.width * 0.72
                height: width
                radius: width / 2
                x: -width * 0.18 + Math.cos(root.globalOrbitAngle * 1.4) * 26
                y: -height * 0.34
                color: root.alpha(root.modeColor("ocr"), 0.10)
                antialiasing: true
            }

            Rectangle {
                width: parent.width * 0.58
                height: width
                radius: width / 2
                x: parent.width - width * 0.72 + Math.sin(root.globalOrbitAngle * 1.9) * 22
                y: parent.height - height * 0.62
                color: root.alpha(root.accent2, 0.07)
                antialiasing: true
            }

            Column {
                id: ocrPanelContent
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                Column {
                    width: parent.width - closeOcrPanelButton.width - 10
                    spacing: 2

                    Text {
                        text: "Text Extractor"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: root.text
                    }

                    Text {
                        text: root.ocrStatusText !== "" ? root.ocrStatusText : "Select an area to extract text from the screen."
                        font.pixelSize: 12
                        color: root.subtext0
                        wrapMode: Text.Wrap
                    }
                }

                Button {
                    id: closeOcrPanelButton
                    width: 36
                    height: 36

                    background: Rectangle {
                        radius: 10
                        color: closeOcrPanelButton.hovered
                            ? root.alpha(root.modeColor("ocr"), 0.18)
                            : root.alpha(root.bg, 0.22)
                        border.width: 1
                        border.color: root.alpha(root.panelBorderColor, 0.85)
                        antialiasing: true
                    }

                    contentItem: Text {
                        text: "x"
                        color: root.text
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.ocrResultVisible = false
                }
            }

            Loader {
                active: ocrProcess.running
                visible: active
                width: parent.width
                height: 84

                sourceComponent: Item {
                    BusyIndicator {
                        anchors.centerIn: parent
                        running: true
                    }
                }
            }

            Rectangle {
                visible: !ocrProcess.running
                width: parent.width
                height: Math.min(ocrResultPanel.maxContentHeight, Math.max(120, ocrTextArea.implicitHeight + 24))
                radius: 14
                color: root.alpha(root.bg, 0.34)
                border.width: 1
                border.color: root.alpha(root.panelBorderColor, 0.55)
                clip: true

                Flickable {
                    id: ocrTextFlickable
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    contentWidth: width
                    contentHeight: ocrTextArea.implicitHeight

                    TextArea {
                        id: ocrTextArea
                        width: parent.width
                        text: root.lastExtractedText !== "" ? root.lastExtractedText : "No extracted text yet."
                        color: root.text
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        readOnly: true
                        selectByMouse: true
                        persistentSelection: true
                        background: Item {}
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10

                Button {
                    id: copyOcrButton
                    width: 104
                    height: 38
                    enabled: !ocrProcess.running && root.lastExtractedText !== ""

                    background: Rectangle {
                        radius: 10
                        color: copyOcrButton.enabled
                            ? (copyOcrButton.hovered
                                ? root.alpha(root.modeColor("ocr"), 0.24)
                                : root.alpha(root.modeColor("ocr"), 0.18))
                            : root.alpha(root.bg, 0.20)
                        border.width: 1
                        border.color: copyOcrButton.enabled
                            ? root.alpha(root.modeColor("ocr"), 0.80)
                            : root.alpha(root.panelBorderColor, 0.60)
                        antialiasing: true
                    }

                    contentItem: Text {
                        text: "Copy Text"
                        color: copyOcrButton.enabled ? root.text : root.subtext0
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.copyExtractedText(root.lastExtractedText)
                }

                Button {
                    id: ocrNewSelectionButton
                    width: 132
                    height: 38
                    enabled: !ocrProcess.running

                    background: Rectangle {
                        radius: 10
                        color: ocrNewSelectionButton.hovered
                            ? root.alpha(root.accent2, 0.18)
                            : root.alpha(root.bg, 0.22)
                        border.width: 1
                        border.color: root.alpha(root.panelBorderColor, 0.75)
                        antialiasing: true
                    }

                    contentItem: Text {
                        text: "New Selection"
                        color: root.text
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        root.lastExtractedText = ""
                        root.ocrStatusText = "Select an area to extract text from the screen."
                        root.ocrResultVisible = false
                    }
                }
            }
        }
        }
    }
 
    Rectangle {
        id: actionPanel
        visible: !root.externalPickerLaunching
        z: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        implicitWidth: controlsRow.implicitWidth + root.panelPadding * 2
        implicitHeight: controlsRow.implicitHeight + root.panelPadding * 2
        width: implicitWidth
        height: implicitHeight

        color: root.panelColor
        radius: 12
        border.width: 1
        border.color: root.panelBorderColor
        antialiasing: true
        clip: true

        InlineElectricBorder {
            radius: actionPanel.radius
            borderWidth: actionPanel.border.width
            accentColor: root.modeColor(root.mode)
        }

        Rectangle {
            width: parent.width * 0.8
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 80
            y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 40
            opacity: 0.12
            color: root.accent
            antialiasing: true
            scale: 1.0 + 0.1 * Math.sin(root.globalOrbitAngle * 5)
            rotation: root.globalOrbitAngle * 10

            Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutSine } }
            Behavior on color { ColorAnimation { duration: 1000 } }
        }

        Rectangle {
            width: parent.width * 0.9
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -80
            y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -40
            opacity: 0.08
            color: root.accent2
            antialiasing: true
            scale: 1.0 + 0.15 * Math.cos(root.globalOrbitAngle * 3)
            rotation: -root.globalOrbitAngle * 15

            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 800; easing.type: Easing.OutSine } }
            Behavior on color { ColorAnimation { duration: 1000 } }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: root.alpha(root.text, 0.025)
        }

        Text {
            id: backgroundParallaxIcon
            anchors.centerIn: parent
            text: "󰄀"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 180
            color: root.accent
            opacity: 0.05 + (0.02 * Math.sin(root.globalOrbitAngle * 4))
            rotation: Math.sin(root.globalOrbitAngle * 2) * 2
            z: 0

            property real drift: 0
            SequentialAnimation on drift {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: -10; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 4000; easing.type: Easing.InOutSine }
            }

            transform: Translate { y: backgroundParallaxIcon.drift }
        }
 
        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 3

            Button {
                id: regionShapeSelectButton
                width: 20
                height: 48

                property bool isActive: root.regionShapeMenuOpen
                property color accentColor: root.modeColor("region")
                property color fillColor: regionShapeSelectButton.isActive
                    ? root.alpha(regionShapeSelectButton.accentColor, 0.28)
                    : (regionShapeSelectButton.hovered
                        ? root.alpha(regionShapeSelectButton.accentColor, 0.18)
                        : root.idleButtonColor)
                property color strokeColor: regionShapeSelectButton.isActive
                    ? root.alpha(regionShapeSelectButton.accentColor, 0.90)
                    : (regionShapeSelectButton.hovered
                        ? root.alpha(regionShapeSelectButton.accentColor, 0.55)
                        : root.alpha(root.panelBorderColor, 0.80))
                property color iconColor: regionShapeSelectButton.isActive
                    ? regionShapeSelectButton.accentColor
                    : (regionShapeSelectButton.hovered
                        ? root.alpha(regionShapeSelectButton.accentColor, 0.92)
                        : root.text)

                background: Rectangle {
                    radius: 8
                    color: regionShapeSelectButton.fillColor
                    border.width: regionShapeSelectButton.isActive ? 2 : 1
                    border.color: regionShapeSelectButton.strokeColor
                    antialiasing: true
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                }

                contentItem: Text {
                    text: "▴"
                    font.pixelSize: 10
                    font.family: "Iosevka Nerd Font"
                    color: regionShapeSelectButton.iconColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    root.mode = "region"
                    root.regionShapeMenuOpen = !root.regionShapeMenuOpen
                }
            }

            Row {
                id: buttonRow
                spacing: 8

                Button {
                    id: regionModeButton
                    implicitWidth: 48
                    implicitHeight: 48

                    property bool isActive: root.mode === "region"
                    property color accentColor: root.modeColor("region")
                    property color fillColor: regionModeButton.isActive
                        ? root.alpha(regionModeButton.accentColor, 0.28)
                        : (regionModeButton.hovered
                            ? root.alpha(regionModeButton.accentColor, 0.18)
                            : root.idleButtonColor)
                    property color strokeColor: regionModeButton.isActive
                        ? root.alpha(regionModeButton.accentColor, 0.90)
                        : (regionModeButton.hovered
                            ? root.alpha(regionModeButton.accentColor, 0.55)
                            : root.alpha(root.panelBorderColor, 0.80))
                    property color iconColor: regionModeButton.isActive
                        ? regionModeButton.accentColor
                        : (regionModeButton.hovered
                            ? root.alpha(regionModeButton.accentColor, 0.92)
                            : root.text)

                    background: Rectangle {
                        radius: 8
                        color: regionModeButton.fillColor
                        border.width: regionModeButton.isActive ? 2 : 1
                        border.color: regionModeButton.strokeColor
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Image {
                            id: regionIcon
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: root.shapeIconSource(root.selectedRegionShape)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: regionIcon
                            source: regionIcon
                            colorization: 1.0
                            colorizationColor: regionModeButton.iconColor
                        }
                    }

                    onClicked: {
                        root.mode = "region"
                        root.regionShapeMenuOpen = false
                    }
                }

                Button {
                    id: windowModeButton
                    implicitWidth: 48
                    implicitHeight: 48

                    property bool isActive: root.mode === "window"
                    property color accentColor: root.modeColor("window")
                    property color fillColor: windowModeButton.isActive
                        ? root.alpha(windowModeButton.accentColor, 0.28)
                        : (windowModeButton.hovered
                            ? root.alpha(windowModeButton.accentColor, 0.18)
                            : root.idleButtonColor)
                    property color strokeColor: windowModeButton.isActive
                        ? root.alpha(windowModeButton.accentColor, 0.90)
                        : (windowModeButton.hovered
                            ? root.alpha(windowModeButton.accentColor, 0.55)
                            : root.alpha(root.panelBorderColor, 0.80))
                    property color iconColor: windowModeButton.isActive
                        ? windowModeButton.accentColor
                        : (windowModeButton.hovered
                            ? root.alpha(windowModeButton.accentColor, 0.92)
                            : root.text)

                    background: Rectangle {
                        radius: 8
                        color: windowModeButton.fillColor
                        border.width: windowModeButton.isActive ? 2 : 1
                        border.color: windowModeButton.strokeColor
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Image {
                            id: windowIcon
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: Qt.resolvedUrl("icons/window.svg")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: windowIcon
                            source: windowIcon
                            colorization: 1.0
                            colorizationColor: windowModeButton.iconColor
                        }
                    }

                    onClicked: {
                        root.regionShapeMenuOpen = false
                        root.mode = "window"
                    }
                }

                Button {
                    id: screenModeButton
                    implicitWidth: 48
                    implicitHeight: 48

                    property bool isActive: root.mode === "screen"
                    property color accentColor: root.modeColor("screen")
                    property color fillColor: screenModeButton.isActive
                        ? root.alpha(screenModeButton.accentColor, 0.28)
                        : (screenModeButton.hovered
                            ? root.alpha(screenModeButton.accentColor, 0.18)
                            : root.idleButtonColor)
                    property color strokeColor: screenModeButton.isActive
                        ? root.alpha(screenModeButton.accentColor, 0.90)
                        : (screenModeButton.hovered
                            ? root.alpha(screenModeButton.accentColor, 0.55)
                            : root.alpha(root.panelBorderColor, 0.80))
                    property color iconColor: screenModeButton.isActive
                        ? screenModeButton.accentColor
                        : (screenModeButton.hovered
                            ? root.alpha(screenModeButton.accentColor, 0.92)
                            : root.text)

                    background: Rectangle {
                        radius: 8
                        color: screenModeButton.fillColor
                        border.width: screenModeButton.isActive ? 2 : 1
                        border.color: screenModeButton.strokeColor
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Image {
                            id: screenIcon
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: Qt.resolvedUrl("icons/screen.svg")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: screenIcon
                            source: screenIcon
                            colorization: 1.0
                            colorizationColor: screenModeButton.iconColor
                        }
                    }

                    onClicked: {
                        root.regionShapeMenuOpen = false
                        root.mode = "screen"
                        const captureScreen = root.targetScreen || root.activeScreen
                        if (!captureScreen)
                            return
                        root.queueSelection(0, 0, captureScreen.width, captureScreen.height)
                    }
                }

                Button {
                    id: pickerModeButton
                    implicitWidth: 48
                    implicitHeight: 48

                    property bool isActive: root.mode === "picker"
                    property color accentColor: root.modeColor("picker")
                    property color fillColor: pickerModeButton.isActive
                        ? root.alpha(pickerModeButton.accentColor, 0.28)
                        : (pickerModeButton.hovered
                            ? root.alpha(pickerModeButton.accentColor, 0.18)
                            : root.idleButtonColor)
                    property color strokeColor: pickerModeButton.isActive
                        ? root.alpha(pickerModeButton.accentColor, 0.90)
                        : (pickerModeButton.hovered
                            ? root.alpha(pickerModeButton.accentColor, 0.55)
                            : root.alpha(root.panelBorderColor, 0.80))
                    property color iconColor: pickerModeButton.isActive
                        ? pickerModeButton.accentColor
                        : (pickerModeButton.hovered
                            ? root.alpha(pickerModeButton.accentColor, 0.92)
                            : root.text)

                    background: Rectangle {
                        radius: 8
                        color: pickerModeButton.fillColor
                        border.width: pickerModeButton.isActive ? 2 : 1
                        border.color: pickerModeButton.strokeColor
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Image {
                            id: pickerModeIcon
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: root.modeIconSource("picker")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: pickerModeIcon
                            source: pickerModeIcon
                            colorization: 1.0
                            colorizationColor: pickerModeButton.iconColor
                        }
                    }

                    onClicked: {
                        root.regionShapeMenuOpen = false
                        root.startHyprpickerColorPick()
                    }
                }

                Button {
                    id: ocrModeButton
                    implicitWidth: 48
                    implicitHeight: 48

                    property bool isActive: root.mode === "ocr"
                    property color accentColor: root.modeColor("ocr")
                    property color fillColor: ocrModeButton.isActive
                        ? root.alpha(ocrModeButton.accentColor, 0.28)
                        : (ocrModeButton.hovered
                            ? root.alpha(ocrModeButton.accentColor, 0.18)
                            : root.idleButtonColor)
                    property color strokeColor: ocrModeButton.isActive
                        ? root.alpha(ocrModeButton.accentColor, 0.90)
                        : (ocrModeButton.hovered
                            ? root.alpha(ocrModeButton.accentColor, 0.55)
                            : root.alpha(root.panelBorderColor, 0.80))
                    property color iconColor: ocrModeButton.isActive
                        ? ocrModeButton.accentColor
                        : (ocrModeButton.hovered
                            ? root.alpha(ocrModeButton.accentColor, 0.92)
                            : root.text)

                    background: Rectangle {
                        radius: 8
                        color: ocrModeButton.fillColor
                        border.width: ocrModeButton.isActive ? 2 : 1
                        border.color: ocrModeButton.strokeColor
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Image {
                            id: ocrModeIcon
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: root.modeIconSource("ocr")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: ocrModeIcon
                            source: ocrModeIcon
                            colorization: 1.0
                            colorizationColor: ocrModeButton.iconColor
                        }
                    }

                    onClicked: {
                        root.regionShapeMenuOpen = false
                        root.mode = "ocr"
                        root.lastExtractedText = ""
                        root.ocrStatusText = "Select an area to extract text from the screen."
                        root.ocrResultVisible = false
                    }
                }

                HoldToggleBubble {
                    id: clipboardOnlyToggle
                    isActive: root.saveToFileEnabled
                    tooltipText: root.saveToFileEnabled
                        ? "Save to disk is ON. Hold to switch to clipboard only."
                        : "Clipboard only is ON. Hold to re-enable saving to disk."
                    onHoldComplete: root.saveToFileEnabled = !root.saveToFileEnabled
                }
        }
    }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.regionShapeMenuOpen
        z: 4
        onClicked: root.regionShapeMenuOpen = false
    }

    Rectangle {
        id: regionShapeMenu
        visible: root.regionShapeMenuOpen
        z: 6
        x: actionPanel.x + controlsRow.x
        y: actionPanel.y - height - 12
        width: 172
        implicitHeight: menuColumn.implicitHeight + 12
        height: implicitHeight
        radius: 12
        color: root.alpha(root.mix(root.bg, root.fg, 0.14), 0.98)
        border.width: 1
        border.color: root.alpha(root.panelBorderColor, 0.92)
        antialiasing: true
        clip: true
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        InlineElectricBorder {
            radius: regionShapeMenu.radius
            borderWidth: regionShapeMenu.border.width
            accentColor: root.accent
        }

        Rectangle {
            width: parent.width * 0.82
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2.1) * 34
            y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2.1) * 18
            opacity: 0.12
            color: root.accent
            antialiasing: true
            scale: 1.0 + 0.08 * Math.sin(root.globalOrbitAngle * 4)
            rotation: root.globalOrbitAngle * 8

            Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutSine } }
            Behavior on color { ColorAnimation { duration: 1000 } }
        }

        Rectangle {
            width: parent.width * 0.9
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.6) * -38
            y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.6) * -16
            opacity: 0.08
            color: root.accent2
            antialiasing: true
            scale: 1.0 + 0.12 * Math.cos(root.globalOrbitAngle * 3)
            rotation: -root.globalOrbitAngle * 11

            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 800; easing.type: Easing.OutSine } }
            Behavior on color { ColorAnimation { duration: 1000 } }
        }

        Text {
            id: regionShapeMenuParallaxIcon
            anchors.centerIn: parent
            text: "󰩫"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 88
            color: root.accent
            opacity: 0.045 + (0.015 * Math.sin(root.globalOrbitAngle * 4))
            rotation: Math.sin(root.globalOrbitAngle * 2) * 2
            z: 0

            property real drift: 0
            SequentialAnimation on drift {
                loops: Animation.Infinite
                running: regionShapeMenu.visible
                NumberAnimation { to: -6; duration: 3600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 3600; easing.type: Easing.InOutSine }
            }

            transform: Translate { y: regionShapeMenuParallaxIcon.drift }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: root.alpha(root.text, 0.02)
        }

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            Repeater {
                model: root.regionShapeOptions

                Button {
                    id: shapeItemButton
                    required property var modelData
                    implicitWidth: 160
                    implicitHeight: 42

                    property bool isSelected: root.selectedRegionShape === modelData.key
                    property color accentColor: root.modeColor("region")
                    property color fillColor: shapeItemButton.isSelected
                        ? root.alpha(shapeItemButton.accentColor, 0.24)
                        : (shapeItemButton.hovered
                            ? root.alpha(shapeItemButton.accentColor, 0.12)
                            : "transparent")
                    property color strokeColor: shapeItemButton.isSelected
                        ? root.alpha(shapeItemButton.accentColor, 0.80)
                        : (shapeItemButton.hovered
                            ? root.alpha(shapeItemButton.accentColor, 0.40)
                            : "transparent")
                    property color iconColor: shapeItemButton.isSelected
                        ? shapeItemButton.accentColor
                        : (shapeItemButton.hovered
                            ? root.alpha(shapeItemButton.accentColor, 0.92)
                            : root.text)

                    background: Rectangle {
                        radius: 10
                        color: shapeItemButton.fillColor
                        border.width: shapeItemButton.isSelected ? 2 : (shapeItemButton.hovered ? 1 : 0)
                        border.color: shapeItemButton.strokeColor
                        antialiasing: true
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Item {
                                width: 24
                                height: 24

                                Image {
                                    id: shapePreview
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: root.shapeIconSource(shapeItemButton.modelData.key)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: shapePreview
                                    source: shapePreview
                                    colorization: 1.0
                                    colorizationColor: shapeItemButton.iconColor
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: shapeItemButton.modelData.label
                                color: shapeItemButton.iconColor
                                font.pixelSize: 13
                            }
                        }
                    }

                    onClicked: {
                        root.mode = "region"
                        root.selectedRegionShape = modelData.key
                        root.regionShapeMenuOpen = false
                    }
                }
            }
        }
    }
}
