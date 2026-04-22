import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.settings 1.1 as LabsSettings
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../theme" as ThemePkg

Item {
    id: window
    focus: true
    Keys.priority: Keys.BeforeItem

    property color workspaceInactiveColor
    property color moduleBorderColor
    property color moduleFontColor
    property var switcher

    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property int scrollThreshold: 300

    property string currentFilter: "All"
    property string searchQuery: ""
    readonly property int overlayEnterDuration: 215
    readonly property int overlayExitDuration: 220
    property bool popupTargetVisible: false
    property bool popupClosing: false
    property real popupContentOpacity: 0.0
    property real popupContentScaleX: 0.84
    property real popupContentScaleY: 0.70
    property real popupContentLift: 18
    property real popupContentInsetX: 104
    property real popupContentInsetY: 68
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity

    property color t_mantle: ThemePkg.Theme.surface(0.05)
    property color t_surface1: ThemePkg.Theme.surface(0.15)
    property color t_surface2: ThemePkg.Theme.surface(0.25)
    property color t_text: ThemePkg.Theme.foreground

    property var rawFiles: []
    property bool listLoaded: false
    property bool isReady: listLoaded
    property bool isStartup: !listLoaded

    property string _lastFilter: "All"
    property bool isOnlineSearch: false
    property bool isSearchPaused: false
    property bool hasSearched: false
    property bool isDownloadingWallpaper: false
    property string currentDownloadName: ""
    property bool isApplying: false

    property string lastSearchName: ""
    property bool isModelChanging: false
    property bool searchIndexRestored: false

    property bool isScrollingBlocked: window.currentFilter === "Search" && window.hasSearched && window.isSearchActive && !window.isSearchPaused
    property bool jumpToLastOnFilterChange: false

    property bool isSearchActive: window.currentFilter === "Search" && window.hasSearched && searchFolderModel.status === FolderListModel.Loading

    property var colorMap: ({})
    property int cacheVersion: 0
    readonly property string quickshellStateFile: Quickshell.env("HOME") + "/.cache/quickshell/state.ini"

    LabsSettings.Settings {
        id: searchState
        fileName: window.quickshellStateFile
        category: "QS_WallpaperPicker"
        property string query: ""
        property bool searched: false
        property string lastName: ""
    }

    onIsSearchPausedChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + (isSearchPaused ? "pause" : "run") + "' > /tmp/ddg_search_control"]);
    }

    readonly property var filterData: [
        {
            name: "All",
            hex: "",
            label: "All"
        },
        {
            name: "Video",
            hex: "",
            label: "Vid"
        },
        {
            name: "Red",
            hex: "#FF4500",
            label: ""
        },
        {
            name: "Orange",
            hex: "#FFA500",
            label: ""
        },
        {
            name: "Yellow",
            hex: "#FFD700",
            label: ""
        },
        {
            name: "Green",
            hex: "#32CD32",
            label: ""
        },
        {
            name: "Blue",
            hex: "#1E90FF",
            label: ""
        },
        {
            name: "Purple",
            hex: "#8A2BE2",
            label: ""
        },
        {
            name: "Pink",
            hex: "#FF69B4",
            label: ""
        },
        {
            name: "Monochrome",
            hex: "#A9A9A9",
            label: ""
        },
        {
            name: "Search",
            hex: "",
            label: "Search"
        }
    ]

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\"'\"'") + "'";
    }

    readonly property string searchDir: Quickshell.env("HOME") + "/.cache/wallpaper_picker/search_thumbs"

    function isDownloaded(name) {
        if (!name)
            return false;
        let p = proxyModel;
        for (let i = 0; i < window.rawFiles.length; i++) {
            if (window.rawFiles[i].name === name)
                return true;
        }
        return false;
    }

    function closePicker() {
        if (window.popupClosing)
            return;
        window.popupClosing = true;
        window.popupTargetVisible = false;
        popupEnterAnim.stop();
        popupExitAnim.stop();
        popupExitAnim.start();
        popupCloseFinalize.restart();
    }

    function _finalizeClosePicker() {
        if (window.switcher) {
            window.switcher.close();
        } else {
            ThemePkg.Theme.globalToggleWallpaper();
        }
    }

    function _showPickerPopup() {
        window.popupClosing = false;
        window.popupTargetVisible = true;
        popupCloseFinalize.stop();
        popupExitAnim.stop();
        if (!popupEnterAnim.running && window.popupContentOpacity >= 0.999)
            return;
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function cancelOverlayClose() {
        window.popupClosing = false;
        window.popupTargetVisible = true;
        popupCloseFinalize.stop();
        popupExitAnim.stop();
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function applyWallpaper(absPath) {
        if (window.isApplying)
            return;
        window.isApplying = true;

        if (window.currentFilter === "Search" && window.hasSearched) {
            let safeFileName = String(absPath).split('/').pop();
            let destFile = window.srcDir + "/" + safeFileName;
            let tempThumb = window.searchDir + "/" + safeFileName;
            let mapFile = Quickshell.env("HOME") + "/.cache/wallpaper_picker/search_map.txt";

            let alreadyExists = window.isDownloaded(safeFileName);

            const bashEscape = str => String(str).replace(/(["\\$`])/g, '\\$1');

            if (alreadyExists) {
                const applyScript = `
                    (
                        export DEST_FILE="${bashEscape(destFile)}"
                        "$HOME/.config/awww/wallpaper.sh" "$DEST_FILE"
                    ) </dev/null >/dev/null 2>&1 & disown
                `;

                Quickshell.execDetached(["bash", "-c", applyScript]);
            } else {
                window.isDownloadingWallpaper = true;
                window.currentDownloadName = safeFileName;

                const downloadScript = `
                    export SAFE_NAME="${bashEscape(safeFileName)}"
                    export DEST_FILE="${bashEscape(destFile)}"
                    export MAP_FILE="${bashEscape(mapFile)}"
                    export TEMP_THUMB="${bashEscape(tempThumb)}"

                    (
                        URL=$(awk -F'|' -v fname="$SAFE_NAME" '$1 == fname {print $2; exit}' "$MAP_FILE")
                        if [ -n "$URL" ]; then
                            curl -s -L -A "Mozilla/5.0" "$URL" -o "$DEST_FILE.tmp"

                            if file "$DEST_FILE.tmp" | grep -iq "webp"; then
                                magick "$DEST_FILE.tmp" "$DEST_FILE"
                                rm -f "$DEST_FILE.tmp"
                            else
                                mv "$DEST_FILE.tmp" "$DEST_FILE"
                            fi

                            "$HOME/.config/awww/wallpaper.sh" "$DEST_FILE"
                        fi
                    ) </dev/null >/dev/null 2>&1 & disown
                `;

                Quickshell.execDetached(["bash", "-c", downloadScript]);
            }

            window.closePicker();
            return;
        }

        const cmd = "$HOME/.config/awww/wallpaper.sh " + window.shQuote(absPath);
        Quickshell.execDetached(["bash", "-lc", cmd]);
        window.closePicker();
    }

    property string listCmd: "find \"$HOME/Pictures/Wallpapers\" -follow -regextype posix-extended -type f -iregex \".*\\\\.(jpe?g|png|webp|bmp|gif|avif|heic|mp4|mkv|mov|webm)$\" -printf \"%f\\t%p\\n\" | LC_ALL=C sort"

    property var _rawFilesBuffer: []
    Process {
        id: actualListProc
        command: ["bash", "-lc", listCmd]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line || line.trim().length === 0)
                    return;
                const parts = line.split("\t");
                if (parts.length < 2)
                    return;
                
                window._rawFilesBuffer.push({
                    name: parts[0],
                    path: parts[1],
                    url: "file://" + parts[1]
                });
            }
        }
        onExited: {
            window.rawFiles = window._rawFilesBuffer;
            window.listLoaded = true;
            window.syncProxyModel();
        }
    }

    onVisibleChanged: {
        if (visible) {
            window._showPickerPopup();
            window.forceActiveFocus();
            window.resetSearchSession();
            window.applyFilters();
            view.forceActiveFocus();
        }
    }

    onHostLoaderOpacityChanged: {
        if (hostLoaderOpacity < lastHostLoaderOpacity - 0.001 && window.popupTargetVisible && !window.popupClosing) {
            window.popupClosing = true;
            window.popupTargetVisible = false;
            popupCloseFinalize.stop();
            popupEnterAnim.stop();
            if (!popupExitAnim.running)
                popupExitAnim.start();
        }
        lastHostLoaderOpacity = hostLoaderOpacity;
    }

    property bool isLoading: !listLoaded
    property bool showSpinner: window.isLoading || window.isSearchActive || window.isDownloadingWallpaper || window.isApplying
    property string currentNotification: {
        if (isLoading)
            return "Loading wallpapers...";
        if (window.visibleItemCount === 0)
            return "No wallpapers found";
        if (window.currentFilter === "All")
            return "";
        if (window.currentFilter === "Search")
            return searchQuery !== "" ? "Search results" : "Type to search...";
        if (window.currentFilter === "Video")
            return "Videos";
        return window.currentFilter;
    }
    property bool showNotification: !window.isStartup && currentNotification !== ""

    readonly property string srcDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    function getHexBucket(hexStr) {
        if (!hexStr)
            return "Monochrome";
        hexStr = String(hexStr).trim().replace(/#/g, '');
        if (hexStr.length > 6)
            hexStr = hexStr.substring(0, 6);
        if (hexStr.length !== 6)
            return "Monochrome";

        let r = parseInt(hexStr.substring(0, 2), 16) / 255;
        let g = parseInt(hexStr.substring(2, 4), 16) / 255;
        let b = parseInt(hexStr.substring(4, 6), 16) / 255;

        let max = Math.max(r, g, b), min = Math.min(r, g, b);
        let d = max - min;

        let h = 0;
        let s = max === 0 ? 0 : d / max;
        let v = max;

        if (max !== min) {
            if (max === r)
                h = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g)
                h = (b - r) / d + 2;
            else
                h = (r - g) / d + 4;
            h /= 6;
        }
        h = h * 360;

        if (s < 0.05 || v < 0.08)
            return "Monochrome";
        if (h >= 345 || h < 15)
            return "Red";
        if (h >= 15 && h < 45)
            return "Orange";
        if (h >= 45 && h < 75)
            return "Yellow";
        if (h >= 75 && h < 165)
            return "Green";
        if (h >= 165 && h < 260)
            return "Blue";
        if (h >= 260 && h < 315)
            return "Purple";
        if (h >= 315 && h < 345)
            return "Pink";

        return "Monochrome";
    }

    function checkItemMatchesFilter(fileName, isVid, cv, filter) {
        if (filter === "Search") {
            if (window.searchQuery.trim() === "")
                return true;
            return String(fileName).toLowerCase().indexOf(window.searchQuery.toLowerCase()) !== -1;
        }
        if (filter === "All")
            return true;
        if (filter === "Video")
            return isVid;
        let hexColor = window.colorMap[String(fileName)];
        if (!hexColor)
            return filter === "Monochrome";
        return window.getHexBucket(hexColor) === filter;
    }

    FolderListModel {
        id: markerModel
        folder: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_picker/colors_markers"
        showDirs: false
        nameFilters: ["*_HEX_*"]
        onCountChanged: markerDebounce.restart()
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                markerDebounce.restart();
        }
    }

    Timer {
        id: markerDebounce
        interval: 100
        repeat: false
        onTriggered: window.processMarkers()
    }

    function processMarkers() {
        let newMap = {};
        for (let i = 0; i < markerModel.count; i++) {
            let markerName = markerModel.get(i, "fileName") || "";
            if (!markerName)
                continue;
            let splitIdx = markerName.lastIndexOf("_HEX_");
            if (splitIdx !== -1) {
                let fName = markerName.substring(0, splitIdx);
                let hexCode = markerName.substring(splitIdx + 5);
                newMap[fName] = "#" + hexCode;
            }
        }
        window.colorMap = newMap;
        window.cacheVersion++;
        window.syncProxyModel();
    }

    function triggerThumbnailAndColorExtraction() {
        const extractScript = `
            COLOR_DIR="$HOME/.cache/wallpaper_picker/colors_markers"
            THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"
            WALL_DIR="$HOME/Pictures/Wallpapers"
            LOCK_DIR="$HOME/.cache/wallpaper_picker/cache_build.lock"
            mkdir -p "$COLOR_DIR" "$THUMB_DIR"
            if ! mkdir "$LOCK_DIR" 2>/dev/null; then
                exit 0
            fi
            trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

            if command -v magick >/dev/null 2>&1; then
                CMD="magick"
            else
                CMD="convert"
            fi

            export MAGICK_THREAD_LIMIT=1
            export MAGICK_MEMORY_LIMIT=256MiB
            export MAGICK_MAP_LIMIT=512MiB
            export MAGICK_DISK_LIMIT=1GiB
            export OMP_NUM_THREADS=1

            find "$WALL_DIR" -path "$WALL_DIR/active" -prune -o -follow -regextype posix-extended -type f -iregex '.*\\.(jpe?g|png|webp|bmp|gif|avif|heic|mp4|mkv|mov|webm)$' -print0 |
            while IFS= read -r -d '' file; do
                filename=$(basename "$file")
                thumb="$THUMB_DIR/$filename.jpg"

                if [ ! -f "$thumb" ]; then
                    case "$file" in
                        *.mp4|*.mkv|*.mov|*.webm|*.MP4|*.MKV|*.MOV|*.WEBM)
                            ffmpeg -y -v error -i "$file" -vframes 1 -vf "scale='min(960,iw)':-2" "$thumb" 2>/dev/null || true
                            ;;
                        *.gif|*.GIF|*.webp|*.WEBP|*.avif|*.AVIF)
                            "$CMD" "$file[0]" -auto-orient -limit thread 1 -limit memory 256MiB -limit map 512MiB -limit disk 1GiB -thumbnail "960x960>" -strip -quality 82 "$thumb" 2>/dev/null || true
                            ;;
                        *)
                            "$CMD" "$file" -auto-orient -limit thread 1 -limit memory 256MiB -limit map 512MiB -limit disk 1GiB -thumbnail "960x960>" -strip -quality 82 "$thumb" 2>/dev/null || true
                            ;;
                    esac
                fi

                found=0
                for marker in "$COLOR_DIR/$filename"_HEX_*; do
                    if [ -e "$marker" ]; then
                        found=1
                        break
                    fi
                done

                if [ "$found" -eq 0 ] && [ -f "$thumb" ]; then
                    hex=$("$CMD" "$thumb" -limit thread 1 -limit memory 128MiB -limit map 256MiB -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)
                    if [ -n "$hex" ]; then
                        touch "$COLOR_DIR/$filename""_HEX_$hex"
                    fi
                fi
            done
        `;

        Quickshell.execDetached(["bash", "-c", extractScript]);
    }

    function updateVisibleCount() {
        let count = 0;
        let targetModel = window.currentFilter === "Search" ? searchProxyModel : proxyModel;

        if (!targetModel || targetModel.count === 0) {
            window.visibleItemCount = 0;
            return;
        }

        if (window.currentFilter === "Search") {
            window.visibleItemCount = targetModel.count;
            return;
        }

        for (let i = 0; i < window.rawFiles.length; i++) {
            let fn = window.rawFiles[i].name;
            let isVid = String(fn).match(/\.(mp4|mkv|mov|webm)$/i) !== null;
            if (window.checkItemMatchesFilter(fn, isVid, window.cacheVersion, window.currentFilter)) {
                count++;
            }
        }
        window.visibleItemCount = count;
    }

    function triggerOnlineSearch() {
        if (searchInput.text.trim() === "")
            return;

        window.isModelChanging = true;
        searchProxyModel.clear();
        window.lastSearchName = "";
        searchState.lastName = "";

        if (window.currentFilter === "Search") {
            view.currentIndex = 0;
            view.positionViewAtIndex(0, ListView.Center);
        }
        window.isModelChanging = false;

        window.searchIndexRestored = true;
        window.isOnlineSearch = true;
        window.hasSearched = true;
        window.visibleItemCount = 0;

        searchState.searched = true;
        searchState.query = searchInput.text.trim();

        window.isSearchPaused = false;
        window.searchQuery = searchInput.text.trim();

        let rawSearchDir = window.searchDir;
        let scriptPath = "$HOME/.config/awww/online_search/ddg_search.sh";

        const cmd = `
            export PATH=$PATH:/run/current-system/sw/bin
            echo 'stop' > /tmp/ddg_search_control

            for p in $(pgrep -f ddg_search.sh); do
                if [ "$p" != "$$" ] && [ "$p" != "$BASHPID" ]; then
                    kill -9 $p 2>/dev/null || true
                fi
            done
            pkill -f "[g]et_ddg_links.py" || true
            sleep 0.2

            rm -rf "${rawSearchDir}"/* || true
            rm -f "$HOME/.cache/wallpaper_picker/search_map.txt" || true

            echo 'run' > /tmp/ddg_search_control
            bash "${scriptPath}" "${window.searchQuery}" &
        `;

        Quickshell.execDetached(["bash", "-c", cmd]);

        searchInput.focus = false;
        view.forceActiveFocus();
    }

    function focusSearchInput() {
        window.currentFilter = "Search";
        Qt.callLater(() => {
            searchInput.forceActiveFocus();
            searchInput.cursorPosition = searchInput.text.length;
        });
    }

    function selectShortcutFilter(filterName) {
        if (filterName === "Search") {
            window.focusSearchInput();
            return;
        }

        window.currentFilter = filterName;
        searchInput.focus = false;
        view.forceActiveFocus();
    }

    function resetSearchSession() {
        window.isModelChanging = true;
        searchProxyModel.clear();
        window.isModelChanging = false;

        window.currentFilter = "All";
        window.searchQuery = "";
        window.hasSearched = false;
        window.isOnlineSearch = false;
        window.isSearchPaused = false;
        window.lastSearchName = "";
        window.searchIndexRestored = false;
        window.currentDownloadName = "";
        searchInput.text = "";

        searchState.query = "";
        searchState.searched = false;
        searchState.lastName = "";

        const cmd = `
            echo 'stop' > /tmp/ddg_search_control

            for p in $(pgrep -f ddg_search.sh); do
                if [ "$p" != "$$" ] && [ "$p" != "$BASHPID" ]; then
                    kill -9 $p 2>/dev/null || true
                fi
            done
            pkill -f "[g]et_ddg_links.py" || true
            rm -rf "${window.searchDir}"/* || true
            rm -f "$HOME/.cache/wallpaper_picker/search_map.txt" || true
            echo 'run' > /tmp/ddg_search_control
        `;

        Quickshell.execDetached(["bash", "-c", cmd]);
        window.updateVisibleCount();
    }

    FolderListModel {
        id: searchFolderModel
        folder: "file://" + window.searchDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false

        onFolderChanged: {
            window.isModelChanging = true;
            searchProxyModel.clear();
            window.isModelChanging = false;
        }

        onCountChanged: searchSyncDebounce.restart()
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                searchSyncDebounce.restart();
        }
    }

    Timer {
        id: searchSyncDebounce
        interval: 100
        repeat: false
        onTriggered: window.syncSearchModel()
    }

    function trySearchFocus() {
        if (window.searchIndexRestored || searchProxyModel.count === 0)
            return;

        if (window.lastSearchName === "") {
            window.searchIndexRestored = true;
            return;
        }

        for (let i = 0; i < searchProxyModel.count; i++) {
            let fname = searchProxyModel.get(i).fileName || "";
            if (fname === window.lastSearchName) {
                window.isModelChanging = true;
                view.forceLayout();
                view.positionViewAtIndex(i, ListView.Center);
                view.currentIndex = i;
                window.searchIndexRestored = true;
                window.isModelChanging = false;
                window.initialFocusSet = true;
                return;
            }
        }

        if (searchFolderModel.status === FolderListModel.Ready && searchProxyModel.count === searchFolderModel.count) {
            window.searchIndexRestored = true;
        }
    }

    function syncSearchModel() {
        let startIdx = searchProxyModel.count;
        let endIdx = searchFolderModel.count;

        if (endIdx < startIdx) {
            window.isModelChanging = true;
            searchProxyModel.clear();
            startIdx = 0;
            window.isModelChanging = false;
        }

        for (let i = startIdx; i < endIdx; i++) {
            let fn = searchFolderModel.get(i, "fileName");
            let fu = searchFolderModel.get(i, "fileUrl");
            let fp = searchFolderModel.get(i, "filePath");
            if (fn !== undefined) {
                searchProxyModel.append({
                    "fileName": fn,
                    "fileUrl": String(fu),
                    "filePath": String(fp),
                    "isVideo": false
                });
            }
        }

        if (window.currentFilter === "Search")
            window.updateVisibleCount();

        if (window.currentFilter === "Search" && window.hasSearched) {
            if (!window.searchIndexRestored) {
                window.trySearchFocus();
            }

            if (window.isScrollingBlocked && startIdx === 0 && searchProxyModel.count > 0 && window.lastSearchName === "") {
                view.forceLayout();
                view.currentIndex = 0;
                view.positionViewAtIndex(0, ListView.Center);
            }
        }
    }

    ListModel {
        id: searchProxyModel
    }

    readonly property var activeModel: window.currentFilter === "Search" ? searchProxyModel : proxyModel

    ListModel {
        id: proxyModel
    }

    function syncProxyModel() {
        if (!listLoaded)
            return;

        let targetIndex = -1;
        if (view.currentItem) {
            targetIndex = view.currentIndex;
        }

        let newItems = [];
        let count = 0;

        for (let i = 0; i < window.rawFiles.length; i++) {
            let fn = window.rawFiles[i].name;
            let fu = window.rawFiles[i].url;
            let fp = window.rawFiles[i].path;

            let isVid = String(fn).match(/\.(mp4|mkv|mov|webm)$/i) !== null;
            if (window.checkItemMatchesFilter(fn, isVid, window.cacheVersion, window.currentFilter)) {
                newItems.push({
                    "fileName": fn,
                    "fileUrl": String(fu),
                    "filePath": String(fp),
                    "isVideo": isVid
                });
                count++;
            }
        }
        proxyModel.clear();
        if (newItems.length > 0) {
            proxyModel.append(newItems);
        }
        window.visibleItemCount = count;
        if (targetIndex !== -1 && count > 0) {
            view.currentIndex = Math.min(targetIndex, count - 1);
        } else if (count > 0) {
            view.currentIndex = 0;
            window.initialFocusSet = true;
        }
    }

    function applyFilters() {
        if (window.currentFilter !== "Search") {
            window.syncProxyModel();
        } else {
            window.updateVisibleCount();
        }
    }
    onCurrentFilterChanged: {
        let returningFromSearch = (window._lastFilter === "Search" && window.currentFilter !== "Search");
        window._lastFilter = window.currentFilter;

        if (returningFromSearch) {
            window.searchIndexRestored = false;
        }

        Qt.callLater(() => {
            view.forceActiveFocus();
            if (window.currentFilter === "Search" && window.hasSearched) {
                window.searchIndexRestored = false;
                window.isSearchPaused = true;
                window.trySearchFocus();
                window.syncSearchModel();
            } else {
                window.applyFilters();
            }
        });
    }
    onSearchQueryChanged: {
        if (window.currentFilter === "Search")
            Qt.callLater(() => {
                window.applyFilters();
            });
    }

    readonly property int itemWidth: 400
    readonly property int itemHeight: 420
    readonly property int borderWidth: 3
    readonly property int spacing: 10
    readonly property real skewFactor: -0.35
    readonly property int currentItemDisplayHeight: window.itemHeight + 30
    readonly property int currentItemVerticalOffset: 15
    readonly property int overlayBarGap: 12
    readonly property int closeOutsideSideMargin: 72
    readonly property int closeOutsideTopMargin: 120
    readonly property int closeOutsideBottomMargin: 120

    readonly property var shortcutHints: [
        {
            key: "W",
            label: "Static",
            filter: "All"
        },
        {
            key: "L",
            label: "Live",
            filter: "Video"
        },
        {
            key: "S",
            label: "Search",
            filter: "Search"
        }
    ]

    Timer {
        id: scrollThrottle
        interval: 150
    }

    Timer {
        id: popupCloseFinalize
        interval: window.overlayExitDuration
        repeat: false
        onTriggered: window._finalizeClosePicker()
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 0.968; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 0.905; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: 30; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: 20; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentLift"; to: 12; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: 0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: 0; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 1.06; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 0.93; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: -22; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: -12; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentLift"; to: 8; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 0.76; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 0.58; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: 132; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: 88; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentLift"; to: 30; duration: 200; easing.type: Easing.InCubic }
        }
    }

    Shortcut {
        sequence: "Left"
        enabled: !window.isScrollingBlocked
        onActivated: view.decrementCurrentIndex()
    }
    Shortcut {
        sequence: "Right"
        enabled: !window.isScrollingBlocked
        onActivated: view.incrementCurrentIndex()
    }
    Shortcut {
        sequence: "Return"
        enabled: !searchInput.activeFocus
        onActivated: {
            if (view.currentItem)
                view.currentItem.pickWallpaper();
        }
    }
    Shortcut {
        sequence: "w"
        enabled: !searchInput.activeFocus
        onActivated: window.selectShortcutFilter("All")
    }
    Shortcut {
        sequence: "l"
        enabled: !searchInput.activeFocus
        onActivated: window.selectShortcutFilter("Video")
    }
    Shortcut {
        sequence: "s"
        enabled: window.currentFilter !== "Search" || !searchInput.activeFocus
        onActivated: window.focusSearchInput()
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Escape) {
            window.closePicker();
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: !!window.switcher
        acceptedButtons: Qt.LeftButton
        onClicked: window.closePicker()
    }

    ListView {
        id: view
        z: 10
        anchors.fill: parent
        anchors.leftMargin: window.closeOutsideSideMargin + window.popupContentInsetX
        anchors.rightMargin: window.closeOutsideSideMargin + window.popupContentInsetX
        anchors.topMargin: window.closeOutsideTopMargin + window.popupContentInsetY
        anchors.bottomMargin: window.closeOutsideBottomMargin + window.popupContentInsetY
        opacity: window.isReady ? window.popupContentOpacity : 0.0
        transform: [
            Scale {
                origin.x: view.width / 2
                origin.y: view.height / 2
                xScale: window.popupContentScaleX
                yScale: window.popupContentScaleY
            },
            Translate { y: window.popupContentLift }
        ]
        spacing: 0
        orientation: ListView.Horizontal
        interactive: true
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2)
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2)
        highlightMoveDuration: window.initialFocusSet ? 500 : 0
        focus: true
        cacheBuffer: 1200
        displayMarginBeginning: 600
        displayMarginEnd: 600

        header: Item {
            width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5) / 2))
        }
        footer: Item {
            width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5) / 2))
        }

        model: window.activeModel

        onCurrentIndexChanged: {
            if (view.model !== searchProxyModel || window.currentFilter !== "Search")
                return;

            if (!window.isModelChanging && window.hasSearched && window.searchIndexRestored) {
                if (currentIndex >= 0 && currentIndex < searchProxyModel.count) {
                    let fname = searchProxyModel.get(currentIndex).fileName;
                    if (fname !== undefined && fname !== "") {
                        window.lastSearchName = String(fname);
                        searchState.lastName = String(fname);
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (scrollThrottle.running) {
                    wheel.accepted = true;
                    return;
                }
                let delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                scrollAccum += delta;
                if (Math.abs(scrollAccum) >= scrollThreshold) {
                    if (scrollAccum > 0)
                        view.decrementCurrentIndex();
                    else
                        view.incrementCurrentIndex();
                    scrollAccum = 0;
                    scrollThrottle.start();
                }
                wheel.accepted = true;
            }
        }

        delegate: Item {
            id: delegateRoot
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property real targetWidth: isCurrent ? (window.itemWidth * 1.5) : (window.itemWidth * 0.5)
            readonly property real targetHeight: isCurrent ? window.currentItemDisplayHeight : window.itemHeight

            property string thumbUrl: fileUrl !== undefined ? "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_picker/thumbs/" + model.fileName + ".jpg" : ""
            property string activeSource: thumbUrl

            width: targetWidth + window.spacing
            height: targetHeight
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: window.currentItemVerticalOffset
            z: isCurrent ? 10 : 1

            Behavior on width {
                enabled: window.initialFocusSet
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on height {
                enabled: window.initialFocusSet
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
            }

            function pickWallpaper() {
                window.applyWallpaper(model.filePath);
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    view.currentIndex = index;
                    delegateRoot.pickWallpaper();
                }
            }

            Item {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((window.itemHeight - height) / 2) * window.skewFactor
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + window.spacing)) : 0
                height: parent.height

                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
                layer.enabled: true
                layer.smooth: true

                Image {
                    anchors.fill: parent
                    source: delegateRoot.activeSource
                    sourceSize: Qt.size(1024, 1024)
                    fillMode: Image.Stretch
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error && delegateRoot.activeSource === delegateRoot.thumbUrl) {
                            delegateRoot.activeSource = fileUrl !== undefined ? fileUrl : "";
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                    }
                    clip: true

                    Image {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -50
                        width: (window.itemWidth * 1.5) + (window.currentItemDisplayHeight * Math.abs(window.skewFactor)) + 50
                        height: window.currentItemDisplayHeight
                        fillMode: Image.PreserveAspectCrop
                        source: delegateRoot.activeSource
                        sourceSize: Qt.size(1024, 1024)
                        asynchronous: true
                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }
                }
            }
        }
    }

    Item {
        id: currentWallpaperBounds
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: view.verticalCenter
        anchors.verticalCenterOffset: window.currentItemVerticalOffset
        width: 1
        height: window.currentItemDisplayHeight
        visible: false
    }

    Rectangle {
        id: filterBarBackground
        anchors.bottom: currentWallpaperBounds.top
        anchors.bottomMargin: window.isReady ? window.overlayBarGap : -filterBarBackground.height
        opacity: window.isReady ? window.popupContentOpacity : 0.0
        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutExpo
            }
        }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: 56
        width: filterRow.width + 24
        radius: 14
        transform: [
            Scale {
                origin.x: filterBarBackground.width / 2
                origin.y: filterBarBackground.height / 2
                xScale: window.popupContentScaleX
                yScale: window.popupContentScaleY
            },
            Translate { y: window.popupContentLift }
        ]
        color: ThemePkg.Theme.surface(0.1)
        border.color: ThemePkg.Theme.surface(0.3)
        border.width: 1

        ElectricBorder {
            anchors.fill: parent
            radius: parent.radius
            borderWidth: parent.border.width
            accentColor: window.moduleFontColor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
        }

        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                id: notifDrawer
                height: 44
                property real targetWidth: window.showNotification ? Math.min(notifTextDrawer.implicitWidth + 36, 300) : 0
                width: targetWidth
                visible: width > 0.1
                radius: 10
                clip: true
                color: window.showNotification ? Qt.rgba(t_surface2.r, t_surface2.g, t_surface2.b, 0.5) : "transparent"
                border.color: window.showNotification ? Qt.rgba(t_surface1.r, t_surface1.g, t_surface1.b, 0.8) : "transparent"
                border.width: 1
                Behavior on width {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.5
                    }
                }
                Item {
                    visible: window.showSpinner
                    width: 44
                    height: 44
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: notifSpinner
                        width: 14
                        height: 14
                        anchors.centerIn: parent
                        property real scaleTrigger: 1
                        onScaleTriggerChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 2;
                            ctx.strokeStyle = Qt.rgba(t_text.r, t_text.g, t_text.b, 0.3);
                            ctx.beginPath();
                            ctx.arc(7, 7, 5, 0, Math.PI * 2);
                            ctx.stroke();

                            ctx.strokeStyle = Qt.rgba(t_text.r, t_text.g, t_text.b, 0.9);
                            ctx.beginPath();
                            ctx.arc(7, 7, 5, 0, Math.PI * 0.5);
                            ctx.stroke();
                        }
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                            running: window.showSpinner && window.showNotification
                        }
                    }
                }

                Text {
                    id: notifTextDrawer
                    anchors.left: parent.left
                    anchors.leftMargin: window.showSpinner ? 40 : 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: window.currentNotification
                    color: t_text
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    font.bold: true
                    opacity: window.showNotification ? 0.9 : 0.0
                    Behavior on anchors.leftMargin {
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.5
                        }
                    }
                }
            }

            Repeater {
                model: window.filterData
                delegate: Item {
                    visible: modelData.name !== "Search"
                    width: !visible ? 0 : ((modelData.name === "Video" || modelData.name === "All") ? 44 : (modelData.hex === "" ? filterText.contentWidth + 24 : 36))
                    height: !visible ? 0 : 36
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: modelData.hex === "" ? (window.currentFilter === modelData.name ? t_surface2 : "transparent") : modelData.hex
                        border.color: window.currentFilter === modelData.name ? t_text : Qt.rgba(t_surface1.r, t_surface1.g, t_surface1.b, 0.6)
                        border.width: window.currentFilter === modelData.name ? 2 : 1
                        scale: window.currentFilter === modelData.name ? 1.15 : (filterMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }

                        Text {
                            id: filterText
                            visible: modelData.hex === "" && modelData.name !== "Video" && modelData.name !== "All"
                            text: modelData.label
                            anchors.centerIn: parent
                            color: window.currentFilter === modelData.name ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.7)
                            font.family: "JetBrains Mono"
                            font.bold: window.currentFilter === modelData.name
                        }

                        Text {
                            visible: modelData.name === "Video"
                            text: "▶"
                            anchors.centerIn: parent
                            color: window.currentFilter === modelData.name ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.7)
                        }
                        Text {
                            visible: modelData.name === "All"
                            text: "■■"
                            anchors.centerIn: parent
                            font.pixelSize: 10
                            color: window.currentFilter === modelData.name ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.7)
                        }
                    }
                    MouseArea {
                        id: filterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.currentFilter = modelData.name
                    }
                }
            }

            Rectangle {
                id: searchControlBtn
                visible: window.currentFilter === "Search" && window.hasSearched
                width: visible ? 44 : 0
                height: 44
                radius: 10
                clip: true
                color: window.isSearchPaused ? t_surface2 : "transparent"
                border.color: window.isSearchPaused ? t_text : Qt.rgba(t_surface1.r, t_surface1.g, t_surface1.b, 0.6)
                border.width: window.isSearchPaused ? 2 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.5
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 400
                        easing.type: Easing.OutQuart
                    }
                }

                MouseArea {
                    id: scMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !window.isApplying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.isSearchPaused = !window.isSearchPaused
                }

                Canvas {
                    width: 44
                    height: 44
                    anchors.centerIn: parent
                    property bool paused: window.isSearchPaused
                    property string activeColor: paused ? t_text : (scMouse.containsMouse ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.7))
                    onActiveColorChanged: requestPaint()
                    onPausedChanged: requestPaint()
                    property real scaleTrigger: 1
                    onScaleTriggerChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = activeColor;
                        if (!paused) {
                            ctx.fillRect(15, 14, 4, 16);
                            ctx.fillRect(25, 14, 4, 16);
                        } else {
                            ctx.beginPath();
                            ctx.moveTo(16, 12);
                            ctx.lineTo(32, 22);
                            ctx.lineTo(16, 32);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }
            }

            Rectangle {
                id: searchBox
                height: 44
                width: window.currentFilter === "Search" ? 360 : 44
                radius: 10
                clip: true
                color: window.currentFilter === "Search" ? Qt.rgba(t_surface2.r, t_surface2.g, t_surface2.b, 0.8) : "transparent"
                border.color: window.currentFilter === "Search" ? Qt.rgba(t_text.r, t_text.g, t_text.b, 0.5) : Qt.rgba(t_surface1.r, t_surface1.g, t_surface1.b, 0.6)
                border.width: window.currentFilter === "Search" ? 2 : 1
                Behavior on width {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.5
                    }
                }

                MouseArea {
                    id: searchMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.currentFilter = window.currentFilter !== "Search" ? "Search" : "All";
                        if (window.currentFilter === "Search")
                            window.focusSearchInput();
                    }
                }

                Text {
                    id: searchIcon
                    anchors.left: window.currentFilter === "Search" ? parent.left : undefined
                    anchors.leftMargin: window.currentFilter === "Search" ? 12 : 0
                    anchors.horizontalCenter: window.currentFilter === "Search" ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: ""
                    font.family: "Font Awesome 6 Pro Solid"
                    font.pixelSize: 16
                    color: window.currentFilter === "Search" ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.7)
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.right: submitBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    opacity: window.currentFilter === "Search" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutQuad
                        }
                    }

                    color: t_text
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    clip: true

                    onTextEdited: {
                        window.hasSearched = false;
                        searchState.searched = false;
                    }

                    onAccepted: {
                        window.triggerOnlineSearch();
                        searchInput.focus = false;
                        view.forceActiveFocus();
                    }
                }

                Rectangle {
                    id: submitBtn
                    width: 32
                    height: 32
                    radius: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: window.currentFilter === "Search" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                    color: submitMouseArea.containsMouse ? Qt.rgba(t_text.r, t_text.g, t_text.b, 0.1) : "transparent"
                    border.color: submitMouseArea.containsMouse ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.3)
                    border.width: 1

                    MouseArea {
                        id: submitMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: window.triggerOnlineSearch()
                    }

                    Canvas {
                        width: 16
                        height: 16
                        anchors.centerIn: parent
                        property string activeColor: submitMouseArea.containsMouse ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.7)
                        onActiveColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 2;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.strokeStyle = activeColor;
                            ctx.beginPath();
                            ctx.moveTo(2, 8); ctx.lineTo(14, 8);
                            ctx.moveTo(9, 3); ctx.lineTo(14, 8); ctx.lineTo(9, 13);
                            ctx.stroke();
                        }
                    }
                }
            }

        }
    }

    Rectangle {
        id: shortcutBarBackground
        anchors.top: currentWallpaperBounds.bottom
        anchors.topMargin: window.isReady ? window.overlayBarGap : -shortcutBarBackground.height
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: 46
        width: shortcutRow.width + 24
        radius: 12
        opacity: window.isReady ? window.popupContentOpacity : 0.0
        transform: [
            Scale {
                origin.x: shortcutBarBackground.width / 2
                origin.y: shortcutBarBackground.height / 2
                xScale: window.popupContentScaleX
                yScale: window.popupContentScaleY
            },
            Translate { y: window.popupContentLift }
        ]
        color: ThemePkg.Theme.surface(0.1)
        border.color: ThemePkg.Theme.surface(0.3)
        border.width: 1

        ElectricBorder {
            anchors.fill: parent
            radius: parent.radius
            borderWidth: parent.border.width
            accentColor: window.moduleFontColor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
        }

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutExpo
            }
        }
        Row {
            id: shortcutRow
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: window.shortcutHints
                delegate: Rectangle {
                    readonly property bool isActive: modelData.filter === "Search" ? window.currentFilter === "Search" : window.currentFilter === modelData.filter

                    width: shortcutContent.width + 20
                    height: 30
                    radius: 9
                    color: isActive ? Qt.rgba(t_surface2.r, t_surface2.g, t_surface2.b, 0.8) : "transparent"
                    border.color: isActive ? Qt.rgba(t_text.r, t_text.g, t_text.b, 0.55) : Qt.rgba(t_surface1.r, t_surface1.g, t_surface1.b, 0.6)
                    border.width: isActive ? 2 : 1

                    Row {
                        id: shortcutContent
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 6
                            color: Qt.rgba(t_text.r, t_text.g, t_text.b, isActive ? 0.15 : 0.08)
                            border.color: Qt.rgba(t_text.r, t_text.g, t_text.b, isActive ? 0.35 : 0.18)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.key
                                color: t_text
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: isActive ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.78)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            font.bold: isActive
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.selectShortcutFilter(modelData.filter)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + window.searchDir + "'"]);

        window.processMarkers();
        startupGraceTimer.start();
    }

    Timer {
        id: startupGraceTimer
        interval: 50
        repeat: false
        onTriggered: {
            window.triggerThumbnailAndColorExtraction();
            actualListProc.running = true;
        }
    }

    Component.onDestruction: {
        searchState.query = "";
        searchState.searched = false;
        searchState.lastName = "";
        
        Quickshell.execDetached(["bash", "-c", "echo 'stop' > /tmp/ddg_search_control; for p in $(pgrep -f ddg_search.sh); do if [ \"$p\" != \"$$\" ] && [ \"$p\" != \"$BASHPID\" ]; then kill -9 $p 2>/dev/null || true; fi; done; pkill -f '[g]et_ddg_links.py'"]);
    }
}
