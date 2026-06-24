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
    readonly property int overlayEnterDuration: 515
    readonly property int overlayExitDuration: 375
    readonly property bool overlayOwnsCloseAnimation: true
    property bool popupTargetVisible: false
    property bool popupClosing: false
    property real popupContentOpacity: 0.0
    property real popupContentScaleX: 0.42
    property real popupContentScaleY: 0.24
    property real popupContentLift: 8.5
    property real popupContentInsetX: 104
    property real popupContentInsetY: 68
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity

    property color t_mantle: ThemePkg.Theme.surface(0.05)
    property color t_surface1: ThemePkg.Theme.surface(0.15)
    property color t_surface2: ThemePkg.Theme.surface(0.25)
    property color t_text: ThemePkg.Theme.foreground
    readonly property string textFont: "Fira Sans"

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
    property string currentFolderPath: ""
    property string currentFolderName: ""

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
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/wallpaper_picker/thumbs"

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

    function normalizePath(path) {
        return String(path || "").replace(/^file:\/\//, "");
    }

    function relativeWallpaperPath(absPath) {
        let path = window.normalizePath(absPath);
        let base = window.normalizePath(window.srcDir);
        if (path.indexOf(base + "/") === 0)
            return path.substring(base.length + 1);
        return path;
    }

    function isGroupedWallpaperRoot(name) {
        let root = String(name || "").toLowerCase();
        return root === "static" || root === "dynamic" || root === "live";
    }

    function isDynamicWallpaperRoot(name) {
        let root = String(name || "").toLowerCase();
        return root === "dynamic" || root === "live";
    }

    function wallpaperRootForPath(absPath) {
        let rel = window.relativeWallpaperPath(absPath);
        let parts = rel.split("/").filter(part => part.length > 0);
        return parts.length > 0 ? String(parts[0]).toLowerCase() : "";
    }

    function folderInfoForPath(absPath) {
        let rel = window.relativeWallpaperPath(absPath);
        let parts = rel.split("/").filter(part => part.length > 0);
        if (parts.length >= 3 && window.isGroupedWallpaperRoot(parts[0])) {
            return {
                path: window.srcDir + "/" + parts[0] + "/" + parts[1],
                name: parts[1],
                category: parts[0]
            };
        }
        return {
            path: "",
            name: "",
            category: ""
        };
    }

    function enrichRawFile(fileName, filePath) {
        let folder = window.folderInfoForPath(filePath);
        return {
            name: fileName,
            path: filePath,
            url: "file://" + filePath,
            folderPath: folder.path,
            folderName: folder.name,
            folderCategory: folder.category,
            rootCategory: window.wallpaperRootForPath(filePath)
        };
    }

    function thumbUrlForName(fileName) {
        return "file://" + window.thumbDir + "/" + fileName + ".jpg";
    }

    function openFolder(folderPath, folderName) {
        if (!folderPath)
            return;
        window.currentFolderPath = String(folderPath);
        window.currentFolderName = String(folderName || "");
        window.syncProxyModel();
        Qt.callLater(() => {
            let targetIndex = proxyModel.count > 1 ? 1 : 0;
            view.currentIndex = targetIndex;
            view.positionViewAtIndex(targetIndex, ListView.Center);
            view.forceActiveFocus();
        });
    }

    function closeFolder() {
        if (window.currentFolderPath === "")
            return;
        window.currentFolderPath = "";
        window.currentFolderName = "";
        window.syncProxyModel();
        Qt.callLater(() => {
            view.currentIndex = 0;
            view.positionViewAtIndex(0, ListView.Center);
            view.forceActiveFocus();
        });
    }

    function closePicker() {
        if (window.switcher) {
            window.switcher.close();
            return;
        }
        window.beginOverlayClose();
        if (ThemePkg.Theme.popupAnimationsEnabled)
            popupCloseFinalize.restart();
        else
            Qt.callLater(window._finalizeClosePicker);
    }

    function beginOverlayClose() {
        if (window.popupClosing)
            return;
        window.popupClosing = true;
        window.popupTargetVisible = false;
        popupEnterAnim.stop();
        popupExitAnim.stop();
        if (!ThemePkg.Theme.popupAnimationsEnabled) {
            window.closeInstant();
            return;
        }
        popupExitAnim.start();
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
        if (ThemePkg.Theme.popupAnimationsEnabled)
            popupEnterAnim.start();
        else
            window.openInstant();
    }

    function cancelOverlayClose() {
        window.popupClosing = false;
        window.popupTargetVisible = true;
        popupCloseFinalize.stop();
        popupExitAnim.stop();
        popupEnterAnim.stop();
        if (ThemePkg.Theme.popupAnimationsEnabled)
            popupEnterAnim.start();
        else
            window.openInstant();
    }

    function openInstant() {
        popupExitAnim.stop();
        popupEnterAnim.stop();
        window.popupClosing = false;
        window.popupTargetVisible = true;
        ThemePkg.Theme.setPopupContentOpen(window);
    }

    function closeInstant() {
        popupEnterAnim.stop();
        popupExitAnim.stop();
        window.popupTargetVisible = false;
        ThemePkg.Theme.setPopupContentClosed(window);
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

    property string listCmd: "find \"$HOME/Pictures/Wallpapers\" -path \"$HOME/Pictures/Wallpapers/active\" -prune -o -follow -regextype posix-extended -type f -iregex \".*\\\\.(jpe?g|png|webp|bmp|gif|avif|heic|mp4|mkv|mov|webm|avi|m4v|ogv|ogg|flv|wmv|mpg|mpeg|apng)$\" -printf \"%f\\t%p\\n\" | LC_ALL=C sort"

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
                
                window._rawFilesBuffer.push(window.enrichRawFile(parts[0], parts[1]));
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
            if (!ThemePkg.Theme.popupAnimationsEnabled) {
                window.closeInstant();
                lastHostLoaderOpacity = hostLoaderOpacity;
                return;
            }
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
        if (window.currentFolderPath !== "" && window.currentFilter === "All")
            return window.currentFolderName;
        if (window.currentFolderPath !== "" && window.currentFilter !== "Search")
            return window.currentFolderName + " / " + window.currentFilter;
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

            find "$WALL_DIR" -path "$WALL_DIR/active" -prune -o -follow -regextype posix-extended -type f -iregex '.*\\.(jpe?g|png|webp|bmp|gif|avif|heic|mp4|mkv|mov|webm|avi|m4v|ogv|ogg|flv|wmv|mpg|mpeg|apng)$' -print0 |
            while IFS= read -r -d '' file; do
                filename=$(basename "$file")
                thumb="$THUMB_DIR/$filename.jpg"

                if [ ! -f "$thumb" ]; then
                    case "$file" in
                        *.mp4|*.mkv|*.mov|*.webm|*.avi|*.m4v|*.ogv|*.ogg|*.flv|*.wmv|*.mpg|*.mpeg|*.MP4|*.MKV|*.MOV|*.WEBM|*.AVI|*.M4V|*.OGV|*.OGG|*.FLV|*.WMV|*.MPG|*.MPEG)
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

    function isVideoFileName(fileName) {
        return String(fileName).match(/\.(mp4|mkv|mov|webm|avi|m4v|ogv|ogg|flv|wmv|mpg|mpeg|gif|apng)$/i) !== null;
    }

    function rawFileMatchesFilter(rawFile) {
        let fn = rawFile.name;
        let isVid = window.isVideoFileName(fn);
        let rootCategory = String(rawFile.rootCategory || "").toLowerCase();
        let isLiveRoot = window.isDynamicWallpaperRoot(rootCategory);
        let isStaticRoot = rootCategory === "" || rootCategory === "static";

        if (window.currentFilter === "Video")
            return isLiveRoot && isVid;

        if (window.currentFilter !== "Search" && (!isStaticRoot || isVid))
            return false;

        return window.checkItemMatchesFilter(fn, isVid, window.cacheVersion, window.currentFilter);
    }

    function emptyWallpaperItem(itemType) {
        return {
            "itemType": itemType,
            "fileName": "",
            "fileUrl": "",
            "filePath": "",
            "isVideo": false,
            "folderPath": "",
            "folderName": "",
            "folderCategory": "",
            "rootCategory": "",
            "folderCount": 0,
            "preview1Thumb": "",
            "preview1File": "",
            "preview2Thumb": "",
            "preview2File": "",
            "preview3Thumb": "",
            "preview3File": "",
            "preview4Thumb": "",
            "preview4File": "",
            "preview5Thumb": "",
            "preview5File": "",
            "preview6Thumb": "",
            "preview6File": "",
            "preview7Thumb": "",
            "preview7File": "",
            "preview8Thumb": "",
            "preview8File": ""
        };
    }

    function fileItemForRaw(rawFile) {
        let item = window.emptyWallpaperItem("file");
        item.fileName = rawFile.name;
        item.fileUrl = String(rawFile.url);
        item.filePath = String(rawFile.path);
        item.isVideo = window.isVideoFileName(rawFile.name);
        item.folderPath = rawFile.folderPath || "";
        item.folderName = rawFile.folderName || "";
        item.folderCategory = rawFile.folderCategory || "";
        item.rootCategory = rawFile.rootCategory || "";
        return item;
    }

    function backItem() {
        let item = window.emptyWallpaperItem("back");
        item.fileName = "Back";
        item.folderName = "Back";
        return item;
    }

    function folderItemForGroup(group) {
        let item = window.emptyWallpaperItem("folder");
        item.fileName = group.name;
        item.fileUrl = group.files.length > 0 ? String(group.files[0].url) : "";
        item.folderPath = group.path;
        item.folderName = group.name;
        item.folderCategory = group.category;
        item.folderCount = group.files.length;
        item.isVideo = group.hasVideo;

        for (let i = 0; i < Math.min(group.files.length, 8); i++) {
            let raw = group.files[i];
            item["preview" + (i + 1) + "Thumb"] = window.thumbUrlForName(raw.name);
            item["preview" + (i + 1) + "File"] = String(raw.url);
        }

        return item;
    }

    function compareByName(a, b) {
        let aa = String(a.sortName || a.name || a.fileName || "").toLowerCase();
        let bb = String(b.sortName || b.name || b.fileName || "").toLowerCase();
        if (aa < bb)
            return -1;
        if (aa > bb)
            return 1;
        return 0;
    }

    function updateVisibleCount() {
        let targetModel = window.currentFilter === "Search" ? searchProxyModel : proxyModel;

        if (!targetModel || targetModel.count === 0) {
            window.visibleItemCount = 0;
            return;
        }

        if (window.currentFilter === "Search") {
            window.visibleItemCount = targetModel.count;
            return;
        }

        let count = 0;
        for (let i = 0; i < proxyModel.count; i++) {
            let itemType = proxyModel.get(i).itemType || "file";
            if (itemType !== "back")
                count++;
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
        window.currentFolderPath = "";
        window.currentFolderName = "";
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
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.avif", "*.heic", "*.mp4", "*.mkv", "*.mov", "*.webm", "*.avi", "*.m4v", "*.ogv", "*.ogg", "*.flv", "*.wmv", "*.mpg", "*.mpeg", "*.apng"]
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
                let item = window.emptyWallpaperItem("file");
                item.fileName = fn;
                item.fileUrl = String(fu);
                item.filePath = String(fp);
                item.isVideo = false;
                searchProxyModel.append(item);
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

        if (window.currentFolderPath !== "") {
            let folderFiles = [];
            for (let i = 0; i < window.rawFiles.length; i++) {
                let raw = window.rawFiles[i];
                if (raw.folderPath === window.currentFolderPath && window.rawFileMatchesFilter(raw))
                    folderFiles.push(raw);
            }

            folderFiles.sort((a, b) => window.compareByName({
                fileName: a.name
            }, {
                fileName: b.name
            }));

            newItems.push(window.backItem());
            for (let f = 0; f < folderFiles.length; f++) {
                newItems.push(window.fileItemForRaw(folderFiles[f]));
                count++;
            }
        } else {
            let folderMap = ({});
            let folderGroups = [];
            let rootFiles = [];

            for (let i = 0; i < window.rawFiles.length; i++) {
                let raw = window.rawFiles[i];
                if (!window.rawFileMatchesFilter(raw))
                    continue;

                if (raw.folderPath !== "") {
                    if (folderMap[raw.folderPath] === undefined) {
                        folderMap[raw.folderPath] = {
                            path: raw.folderPath,
                            name: raw.folderName,
                            category: raw.folderCategory,
                            sortName: raw.folderCategory + "/" + raw.folderName,
                            hasVideo: false,
                            files: []
                        };
                        folderGroups.push(folderMap[raw.folderPath]);
                    }
                    folderMap[raw.folderPath].files.push(raw);
                    if (window.isVideoFileName(raw.name))
                        folderMap[raw.folderPath].hasVideo = true;
                } else {
                    rootFiles.push(raw);
                }
            }

            folderGroups.sort(window.compareByName);
            rootFiles.sort((a, b) => window.compareByName({
                fileName: a.name
            }, {
                fileName: b.name
            }));

            for (let g = 0; g < folderGroups.length; g++) {
                folderGroups[g].files.sort((a, b) => window.compareByName({
                    fileName: a.name
                }, {
                    fileName: b.name
                }));
                newItems.push(window.folderItemForGroup(folderGroups[g]));
                count++;
            }

            for (let f = 0; f < rootFiles.length; f++) {
                newItems.push(window.fileItemForRaw(rootFiles[f]));
                count++;
            }
        }

        proxyModel.clear();
        if (newItems.length > 0) {
            proxyModel.append(newItems);
        }
        window.visibleItemCount = count;
        if (targetIndex !== -1 && newItems.length > 0) {
            view.currentIndex = Math.min(targetIndex, newItems.length - 1);
        } else if (newItems.length > 0) {
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
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: 30; duration: 285; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: 20; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupContentLift"; to: 8; duration: 300; easing.type: Easing.OutCubic }
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
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: -22; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: -12; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupContentOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentInsetX"; to: 132; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentInsetY"; to: 88; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupContentLift"; to: 8.5; duration: 280; easing.type: Easing.InCubic }
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
        sequence: "Backspace"
        enabled: window.currentFolderPath !== "" && !searchInput.activeFocus
        onActivated: window.closeFolder()
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
            readonly property string modelType: model.itemType !== undefined ? model.itemType : "file"
            readonly property bool isFolder: modelType === "folder"
            readonly property bool isBack: modelType === "back"
            readonly property bool isFile: !isFolder && !isBack
            readonly property real targetWidth: isBack ? (window.itemWidth * 0.38) : (isCurrent ? (window.itemWidth * 1.5) : (window.itemWidth * 0.5))
            readonly property real targetHeight: isBack ? (window.itemHeight * 0.74) : (isCurrent ? window.currentItemDisplayHeight : window.itemHeight)
            readonly property real folderTextBandHeight: isCurrent ? 86 : 58
            readonly property real folderTextCenterOffset: (((window.itemHeight - targetHeight) / 2) * window.skewFactor) + ((targetHeight - (folderTextBandHeight / 2)) * window.skewFactor)
            readonly property real folderTextOverlayWidth: Math.max(isCurrent ? 240 : 96, targetWidth * (isCurrent ? 0.72 : 0.64))

            property string thumbUrl: isFile && fileUrl !== undefined ? window.thumbUrlForName(model.fileName) : ""
            property string activeSource: thumbUrl
            property string preview1Thumb: model.preview1Thumb !== undefined ? model.preview1Thumb : ""
            property string preview1File: model.preview1File !== undefined ? model.preview1File : ""
            property string preview2Thumb: model.preview2Thumb !== undefined ? model.preview2Thumb : ""
            property string preview2File: model.preview2File !== undefined ? model.preview2File : ""
            property string preview3Thumb: model.preview3Thumb !== undefined ? model.preview3Thumb : ""
            property string preview3File: model.preview3File !== undefined ? model.preview3File : ""
            property string preview4Thumb: model.preview4Thumb !== undefined ? model.preview4Thumb : ""
            property string preview4File: model.preview4File !== undefined ? model.preview4File : ""
            property string preview5Thumb: model.preview5Thumb !== undefined ? model.preview5Thumb : ""
            property string preview5File: model.preview5File !== undefined ? model.preview5File : ""
            property string preview6Thumb: model.preview6Thumb !== undefined ? model.preview6Thumb : ""
            property string preview6File: model.preview6File !== undefined ? model.preview6File : ""
            property string preview7Thumb: model.preview7Thumb !== undefined ? model.preview7Thumb : ""
            property string preview7File: model.preview7File !== undefined ? model.preview7File : ""
            property string preview8Thumb: model.preview8Thumb !== undefined ? model.preview8Thumb : ""
            property string preview8File: model.preview8File !== undefined ? model.preview8File : ""

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
                if (delegateRoot.isBack) {
                    window.closeFolder();
                    return;
                }
                if (delegateRoot.isFolder) {
                    window.openFolder(model.folderPath, model.folderName);
                    return;
                }
                window.applyWallpaper(model.filePath);
            }

            function previewThumbAt(previewIndex) {
                let previews = [delegateRoot.preview1Thumb, delegateRoot.preview2Thumb, delegateRoot.preview3Thumb, delegateRoot.preview4Thumb, delegateRoot.preview5Thumb, delegateRoot.preview6Thumb, delegateRoot.preview7Thumb, delegateRoot.preview8Thumb];
                return previews[Math.max(0, Math.min(previewIndex, previews.length - 1))];
            }

            function previewFileAt(previewIndex) {
                let previews = [delegateRoot.preview1File, delegateRoot.preview2File, delegateRoot.preview3File, delegateRoot.preview4File, delegateRoot.preview5File, delegateRoot.preview6File, delegateRoot.preview7File, delegateRoot.preview8File];
                return previews[Math.max(0, Math.min(previewIndex, previews.length - 1))];
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
                    visible: delegateRoot.isFile
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
                        visible: delegateRoot.isFile
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

                    Item {
                        visible: delegateRoot.isFolder
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -50
                        width: (window.itemWidth * 1.5) + (window.currentItemDisplayHeight * Math.abs(window.skewFactor)) + 50
                        height: window.currentItemDisplayHeight
                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }

                        Item {
                            id: folderCollage
                            anchors.fill: parent
                            readonly property int tileCount: 8
                            readonly property int tileColumns: delegateRoot.isCurrent ? 4 : 2
                            readonly property int tileRows: Math.ceil(tileCount / tileColumns)

                            Grid {
                                id: folderPreviewGrid
                                anchors.fill: parent
                                columns: folderCollage.tileColumns
                                spacing: 3

                                Repeater {
                                    model: folderCollage.tileCount
                                    delegate: Rectangle {
                                        width: Math.max(1, (folderPreviewGrid.width - folderPreviewGrid.spacing * (folderPreviewGrid.columns - 1)) / folderPreviewGrid.columns)
                                        height: Math.max(1, (folderPreviewGrid.height - folderPreviewGrid.spacing * (folderCollage.tileRows - 1)) / folderCollage.tileRows)
                                        radius: 0
                                        clip: true
                                        color: Qt.rgba(t_text.r, t_text.g, t_text.b, 0.08)

                                        property string primarySource: delegateRoot.previewThumbAt(index)
                                        property string fallbackSource: delegateRoot.previewFileAt(index)
                                        property string activePreviewSource: primarySource

                                        onPrimarySourceChanged: activePreviewSource = primarySource

                                        Image {
                                            anchors.fill: parent
                                            visible: parent.activePreviewSource !== ""
                                            source: parent.activePreviewSource
                                            sourceSize: Qt.size(512, 512)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            onStatusChanged: {
                                                if (status === Image.Error && parent.activePreviewSource === parent.primarySource)
                                                    parent.activePreviewSource = parent.fallbackSource;
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: delegateRoot.isCurrent ? 86 : 58
                                color: Qt.rgba(0, 0, 0, 0.56)
                            }
                        }
                    }

                    Item {
                        visible: delegateRoot.isBack
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -50
                        width: (window.itemWidth * 1.5) + (window.currentItemDisplayHeight * Math.abs(window.skewFactor)) + 50
                        height: window.currentItemDisplayHeight
                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }

                        Item {
                            anchors.centerIn: parent
                            width: 110
                            height: 150

                            Rectangle {
                                id: backButtonShape
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                width: 76
                                height: 76
                                radius: 12
                                color: Qt.rgba(t_surface2.r, t_surface2.g, t_surface2.b, 0.78)
                                border.color: delegateRoot.isCurrent ? Qt.rgba(t_text.r, t_text.g, t_text.b, 0.45) : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.18)
                                border.width: delegateRoot.isCurrent ? 2 : 1

                                Canvas {
                                    anchors.centerIn: parent
                                    width: 34
                                    height: 34
                                    property color arrowColor: t_text
                                    onArrowColorChanged: requestPaint()
                                    onPaint: {
                                        let ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.lineWidth = 3;
                                        ctx.lineCap = "round";
                                        ctx.lineJoin = "round";
                                        ctx.strokeStyle = arrowColor;
                                        ctx.beginPath();
                                        ctx.moveTo(21, 8);
                                        ctx.lineTo(11, 17);
                                        ctx.lineTo(21, 26);
                                        ctx.stroke();
                                    }
                                }
                            }

                            Text {
                                anchors.top: backButtonShape.bottom
                                anchors.topMargin: 14
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: "Back"
                                color: t_text
                                elide: Text.ElideRight
                                font.family: window.textFont
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }
                }
            }

            Item {
                visible: delegateRoot.isFolder
                z: 30
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: delegateRoot.folderTextCenterOffset
                anchors.bottom: parent.bottom
                anchors.bottomMargin: delegateRoot.isCurrent ? 30 : 29
                width: delegateRoot.folderTextOverlayWidth
                height: delegateRoot.isCurrent ? 54 : 24

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: folderOverlayCountText.visible ? folderOverlayCountText.top : parent.bottom
                    anchors.bottomMargin: folderOverlayCountText.visible ? 2 : 0
                    horizontalAlignment: Text.AlignHCenter
                    text: model.folderName
                    color: t_text
                    elide: Text.ElideRight
                    font.family: window.textFont
                    font.pixelSize: delegateRoot.isCurrent ? 23 : 14
                    font.bold: true
                    renderType: Text.NativeRendering
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.78)
                }

                Text {
                    id: folderOverlayCountText
                    visible: delegateRoot.isCurrent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    horizontalAlignment: Text.AlignHCenter
                    text: model.folderCount + (model.folderCount === 1 ? " wallpaper" : " wallpapers")
                    color: Qt.rgba(t_text.r, t_text.g, t_text.b, 0.72)
                    elide: Text.ElideRight
                    font.family: window.textFont
                    font.pixelSize: 12
                    font.bold: true
                    renderType: Text.NativeRendering
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.72)
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

        AnimatedBorder {
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
                    font.family: window.textFont
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
                            font.family: window.textFont
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
                    font.family: window.textFont
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

        AnimatedBorder {
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
                                font.family: window.textFont
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: isActive ? t_text : Qt.rgba(t_text.r, t_text.g, t_text.b, 0.78)
                            font.family: window.textFont
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
