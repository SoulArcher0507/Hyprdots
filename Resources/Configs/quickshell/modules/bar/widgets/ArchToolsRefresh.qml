import QtQuick
import Quickshell
import Quickshell.Io as Io
import "archtools_state" as ArchState

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/archtools"
    readonly property string repoScriptsDir: Quickshell.env("HOME") + "/.config/hyprdots/Resources/Configs/hypr/scripts/quickshell/archtools"
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/quickshell/archtools_cache.json"
    readonly property int updatesRefreshIntervalMs: 15 * 60 * 1000
    readonly property int dotfilesRefreshIntervalMs: 30 * 60 * 1000

    property var cacheData: ({})
    property bool cacheSaveQueued: false

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function scriptRunCommand(fileName, args) {
        var file = String(fileName || "");
        var runner = file.endsWith(".py") ? "python3" : "bash";
        var deployed = root.scriptsDir + "/" + file;
        var repo = root.repoScriptsDir + "/" + file;
        var quotedArgs = (args || []).map(function(arg) {
            return root.shellQuote(arg);
        }).join(" ");
        var suffix = quotedArgs ? " " + quotedArgs : "";

        return "if [ -f " + root.shellQuote(deployed) + " ]; then exec " + runner + " " + root.shellQuote(deployed) + suffix + "; " +
            "elif [ -f " + root.shellQuote(repo) + " ]; then exec " + runner + " " + root.shellQuote(repo) + suffix + "; " +
            "else echo '{}'; exit 1; fi";
    }

    function parseLastJson(raw) {
        var text = String(raw || "").trim();
        try {
            return JSON.parse(text || "{}");
        } catch (e) {}

        var start = text.lastIndexOf("{");
        var end = text.lastIndexOf("}");
        var json = (start !== -1 && end !== -1 && end > start) ? text.slice(start, end + 1) : text;

        try {
            return JSON.parse(json || "{}");
        } catch (e) {
            return null;
        }
    }

    function asNumber(value, fallback) {
        var n = Number(value);
        return isNaN(n) ? fallback : n;
    }

    function hasUpdateCounts(obj) {
        return !!obj && (
            obj.pacman !== undefined
            || obj.aur !== undefined
            || obj.flatpak !== undefined
            || obj.total !== undefined
            || obj.updPacman !== undefined
            || obj.updAur !== undefined
            || obj.updFlatpak !== undefined
            || obj.updTotal !== undefined
        );
    }

    function mergeCacheFields(fields) {
        var next = Object.assign({}, root.cacheData || ({}));
        for (var key in fields)
            next[key] = fields[key];
        root.cacheData = next;
    }

    function saveCache() {
        if (cacheSaveProc.running) {
            root.cacheSaveQueued = true;
            return;
        }

        cacheSaveProc.command = [
            "bash",
            "-lc",
            "cache_file=$1; json=$2; mkdir -p -- \"$(dirname -- \"$cache_file\")\" && printf '%s\\n' \"$json\" > \"$cache_file\"",
            "archtools-cache-save",
            root.cacheFile,
            JSON.stringify(root.cacheData)
        ];
        cacheSaveProc.running = true;
    }

    function applyCacheObject(obj) {
        if (!obj)
            return;

        root.cacheData = obj;
        if (root.hasUpdateCounts(obj))
            root.applyUpdateCounts(obj, false);

        if (obj.unreadNews !== undefined)
            ArchState.ArchToolsState.unreadNews = root.asNumber(obj.unreadNews, 0);
        if (obj.unreadDotfiles !== undefined)
            ArchState.ArchToolsState.unreadDotfiles = root.asNumber(obj.unreadDotfiles, 0);
    }

    function applyUpdateCounts(obj, persist) {
        if (!root.hasUpdateCounts(obj))
            return;

        var pacman = root.asNumber(obj.pacman !== undefined ? obj.pacman : obj.updPacman, 0);
        var aur = root.asNumber(obj.aur !== undefined ? obj.aur : obj.updAur, 0);
        var flatpak = root.asNumber(obj.flatpak !== undefined ? obj.flatpak : obj.updFlatpak, 0);
        var total = root.asNumber(obj.total !== undefined ? obj.total : obj.updTotal, pacman + aur + flatpak);
        var now = root.asNumber(obj.updLastMs, Date.now());
        var lastTs = obj.updLastTs !== undefined ? String(obj.updLastTs || "") : Qt.formatDateTime(new Date(now), "HH:mm");

        ArchState.ArchToolsState.updatePacman = pacman;
        ArchState.ArchToolsState.updateAur = aur;
        ArchState.ArchToolsState.updateFlatpak = flatpak;
        ArchState.ArchToolsState.updateTotal = total;
        ArchState.ArchToolsState.updatesLastTs = lastTs;
        ArchState.ArchToolsState.updatesLastMs = now;

        root.mergeCacheFields({
            updPacman: pacman,
            updAur: aur,
            updFlatpak: flatpak,
            updTotal: total,
            updLastTs: ArchState.ArchToolsState.updatesLastTs,
            updLastMs: now
        });

        if (persist)
            root.saveCache();
    }

    function applyDotfilesStatus(obj, persist) {
        if (!obj || obj.unread === undefined)
            return;

        var unread = root.asNumber(obj.unread, 0);
        ArchState.ArchToolsState.unreadDotfiles = unread;
        root.mergeCacheFields({ unreadDotfiles: unread });

        if (persist)
            root.saveCache();
    }

    function startUpdatesCheck() {
        if (!updatesCheckProc.running)
            updatesCheckProc.running = true;
    }

    function startDotfilesFetch() {
        if (!dotfilesFetchProc.running)
            dotfilesFetchProc.running = true;
    }

    Component.onCompleted: {
        loadCacheProc.running = true;
    }

    Io.Process {
        id: loadCacheProc
        command: ["bash", "-lc", "cat -- \"$1\" 2>/dev/null || printf '{}\\n'", "archtools-cache-load", root.cacheFile]
        stdout: Io.StdioCollector {
            id: loadCacheOut
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            var obj = root.parseLastJson(loadCacheOut.text);
            root.applyCacheObject(obj || ({}));
        }
    }

    Timer {
        id: delayedUpdatesCheckTimer
        interval: 12000
        repeat: false
        running: true
        onTriggered: root.startUpdatesCheck()
    }

    Timer {
        interval: root.updatesRefreshIntervalMs
        repeat: true
        running: true
        onTriggered: root.startUpdatesCheck()
    }

    Io.Process {
        id: updatesCheckProc
        command: ["bash", "-lc", root.scriptRunCommand("updates-check.sh")]
        stdout: Io.StdioCollector {
            id: updatesCheckOut
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            var obj = root.parseLastJson(updatesCheckOut.text);
            root.applyUpdateCounts(obj, true);
        }
    }

    Timer {
        id: delayedDotfilesFetchTimer
        interval: 15000
        repeat: false
        running: true
        onTriggered: root.startDotfilesFetch()
    }

    Timer {
        interval: root.dotfilesRefreshIntervalMs
        repeat: true
        running: true
        onTriggered: root.startDotfilesFetch()
    }

    Io.Process {
        id: dotfilesFetchProc
        command: ["bash", "-lc", root.scriptRunCommand("dotfiles-updates.py", ["--fetch"])]
        stdout: Io.StdioCollector {
            id: dotfilesFetchOut
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            var obj = root.parseLastJson(dotfilesFetchOut.text);
            root.applyDotfilesStatus(obj, true);
        }
    }

    Io.Process {
        id: cacheSaveProc
        onExited: function(exitCode, exitStatus) {
            if (!root.cacheSaveQueued)
                return;
            root.cacheSaveQueued = false;
            root.saveCache();
        }
    }
}
