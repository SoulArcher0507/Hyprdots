local mainMod = "SUPER"
local terminal = "kitty"

local function bind(keys, dispatcher, flags)
    hl.bind(keys, dispatcher, flags)
end

-- Quickshell
-- @bind Quickshell :: SUPER + CTRL + space :: hl.dsp.exec_cmd([[qs ipc -p ~/.config/quickshell/launcher call launcher toggle]]) :: Open Launcher
bind(mainMod .. " + CTRL + space", hl.dsp.exec_cmd("qs ipc -p ~/.config/quickshell/launcher call launcher toggle"))
-- @bind Quickshell :: SUPER + CTRL + ALT + space :: hl.dsp.exec_cmd([[qs ipc -p ~/.config/quickshell/gamelauncher call gamelauncher toggle]]) :: Open Game Launcher
bind(mainMod .. " + CTRL + ALT + space", hl.dsp.exec_cmd("qs ipc -p ~/.config/quickshell/gamelauncher call gamelauncher toggle"))
-- @bind Quickshell :: SUPER + A :: hl.dsp.exec_cmd([[qs ipc -c ~/.config/quickshell/overview call overview toggle]]) :: Open Workspaces Overview
bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc -c ~/.config/quickshell/overview call overview toggle"))
-- @bind Quickshell :: SUPER + W :: hl.dsp.exec_cmd([[qs ipc call wallpaper toggle]]) :: Open Wallpaper Picker
bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
-- @bind Quickshell :: SUPER + C :: hl.dsp.exec_cmd([[qs ipc call calendar toggle]]) :: Open Calendar Popup
bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc call calendar toggle"))
-- @bind Quickshell :: SUPER + CTRL + Q :: hl.dsp.exec_cmd([[qs ipc call power toggle]]) :: Power Options
bind(mainMod .. " + CTRL + Q", hl.dsp.exec_cmd("qs ipc call power toggle"))
-- @bind Quickshell :: SUPER + PRINT :: hl.dsp.exec_cmd([[qs ipc call hyprshot open]]) :: Take a Screenshot
bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("qs ipc call hyprshot open"))
-- @bind Quickshell :: SUPER + SHIFT + S :: hl.dsp.exec_cmd([[qs ipc call hyprshot open]]) :: Take a Screenshot
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs ipc call hyprshot open"))
-- @bind Quickshell :: SUPER + V :: hl.dsp.exec_cmd([[qs ipc call cliphist toggle]]) :: Open Clipboard Manager
bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call cliphist toggle"))
-- @bind Quickshell :: SUPER + M :: hl.dsp.exec_cmd([[qs ipc call music toggle]]) :: Open Music Popup
bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call music toggle"))
-- @bind Quickshell :: SUPER + O :: hl.dsp.exec_cmd([[qs ipc call arch toggle]]) :: Open Arch Tools
bind(mainMod .. " + O", hl.dsp.exec_cmd("qs ipc call arch toggle"))
-- @bind Quickshell :: SUPER + CTRL + F :: hl.dsp.exec_cmd([[qs ipc call focustime toggle]]) :: Open Focus Time Popup
bind(mainMod .. " + CTRL + F", hl.dsp.exec_cmd("qs ipc call focustime toggle"))
-- @bind Quickshell :: SUPER + CTRL + M :: hl.dsp.exec_cmd([[qs ipc call monitor toggle]]) :: Open Monitor Settings
bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd("qs ipc call monitor toggle"))
-- @bind Quickshell :: SUPER + SHIFT + B :: hl.dsp.exec_cmd([[qs ipc call battery toggle]]) :: Open Battery Popup
bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("qs ipc call battery toggle"))
-- @bind Quickshell :: SUPER + N :: hl.dsp.exec_cmd([[qs ipc call notifications toggle]]) :: Open Notification Popup
bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle"))
-- @bind Quickshell :: SUPER + SHIFT + N :: hl.dsp.exec_cmd([[qs ipc call network toggle]]) :: Open Network Panel
bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("qs ipc call network toggle"))
-- @bind Quickshell :: SUPER + CTRL + N :: hl.dsp.exec_cmd([[qs ipc call notificationsound toggle]]) :: Open Notification Sound Settings
bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("qs ipc call notificationsound toggle"))
-- @bind Quickshell :: SUPER + SHIFT + V :: hl.dsp.exec_cmd([[qs ipc call volume toggle]]) :: Open Volume Settings
bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call volume toggle"))
-- @bind Quickshell :: SUPER + SHIFT + K :: hl.dsp.exec_cmd([[qs ipc call keybindings toggle]]) :: Open Keybindings List
bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("qs ipc call keybindings toggle"))

-- Applications
-- @bind Applications :: SUPER + RETURN :: hl.dsp.exec_cmd([[kitty]]) :: Open Terminal
bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
-- @bind Applications :: SUPER + B :: hl.dsp.exec_cmd([[vivaldi]]) :: Open Browser
bind(mainMod .. " + B", hl.dsp.exec_cmd("vivaldi"))
-- @bind Applications :: SUPER + E :: hl.dsp.exec_cmd([[dolphin --new-window]]) :: Open Filemanager
bind(mainMod .. " + E", hl.dsp.exec_cmd("dolphin --new-window"))
-- @bind Applications :: SUPER + SHIFT + O :: hl.dsp.exec_cmd([[kitty -e nvim Sync/Università-Typst]]) :: Open University Notes
bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(terminal .. " -e nvim Sync/Università-Typst"))
-- @bind Applications :: SUPER + SHIFT + C :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/reload.sh]]) :: Reload Configuration
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))
-- @bind Applications :: SUPER + space :: hl.dsp.exec_cmd([[$HOME/.config/hypr/scripts/gpt.sh]]) :: Open ChatGPT
bind(mainMod .. " + space", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/gpt.sh"))
-- @bind Applications :: SUPER + SHIFT + space :: hl.dsp.exec_cmd([[$HOME/.config/hypr/scripts/gemini.sh]]) :: Open Gemini
bind(mainMod .. " + SHIFT + space", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/gemini.sh"))
-- @bind Applications :: SUPER + ALT + space :: hl.dsp.exec_cmd([[$HOME/.config/hypr/scripts/notebooklm.sh]]) :: Open NotebookLM
bind(mainMod .. " + ALT + space", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/notebooklm.sh"))
-- @bind Applications :: SUPER + S :: hl.dsp.exec_cmd([[kitty -e btop]]) :: Open Btop
bind(mainMod .. " + S", hl.dsp.exec_cmd(terminal .. " -e btop"))
-- @bind Applications :: SUPER + CTRL + S :: hl.dsp.exec_cmd([[kitty -e nvtop]]) :: Open Nvtop
bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd(terminal .. " -e nvtop"))

-- Windows
-- @bind Windows :: SUPER + Q :: hl.dsp.window.close() :: Quit Active Window
bind(mainMod .. " + Q", hl.dsp.window.close())
-- @bind Windows :: SUPER + SHIFT + Q :: hl.dsp.exec_cmd([=[hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill]=]) :: Kill Active Window and All Open Instances
bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"))
-- @bind Windows :: SUPER + F :: hl.dsp.window.fullscreen({ mode = [[fullscreen]] }) :: Set Active Window Fullscreen
bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- @bind Windows :: SUPER + SHIFT + F :: hl.dsp.window.fullscreen({ mode = [[maximized]] }) :: Maximize Window
bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
-- @bind Windows :: SUPER + T :: hl.dsp.window.float({ action = [[toggle]] }) :: Toggle Active Windows into Floating Mode
bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
-- @bind Windows :: SUPER + left :: hl.dsp.focus({ direction = [[l]] }) :: Move Focus Left
bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
-- @bind Windows :: SUPER + right :: hl.dsp.focus({ direction = [[r]] }) :: Move Focus Right
bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
-- @bind Windows :: SUPER + up :: hl.dsp.focus({ direction = [[u]] }) :: Move Focus Up
bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
-- @bind Windows :: SUPER + down :: hl.dsp.focus({ direction = [[d]] }) :: Move Focus Down
bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))
-- @bind Windows :: SUPER + mouse:272 :: hl.dsp.window.drag() :: Move Window with Mouse
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- @bind Windows :: SUPER + mouse:273 :: hl.dsp.window.resize() :: Resize Window with Mouse
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- @bind Windows :: SUPER + SHIFT + right :: hl.dsp.window.resize({ x = 100, y = 0, relative = true }) :: Increase Window Width to Right
bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
-- @bind Windows :: SUPER + SHIFT + left :: hl.dsp.window.resize({ x = -100, y = 0, relative = true }) :: Increase Window Width to Left
bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
-- @bind Windows :: SUPER + SHIFT + down :: hl.dsp.window.resize({ x = 0, y = 100, relative = true }) :: Increase Window Width to Up
bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))
-- @bind Windows :: SUPER + SHIFT + up :: hl.dsp.window.resize({ x = 0, y = -100, relative = true }) :: Inrease Window Width to Down
bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
-- @bind Windows :: SUPER + K :: hl.dsp.layout([[swapsplit]]) :: Swapsplit
bind(mainMod .. " + K", hl.dsp.layout("swapsplit"))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- @bind Workspaces :: SUPER + 1 :: hl.dsp.focus({ workspace = 1 }) :: Open Workspace 1
-- @bind Workspaces :: SUPER + 2 :: hl.dsp.focus({ workspace = 2 }) :: Open Workspace 2
-- @bind Workspaces :: SUPER + 3 :: hl.dsp.focus({ workspace = 3 }) :: Open Workspace 3
-- @bind Workspaces :: SUPER + 4 :: hl.dsp.focus({ workspace = 4 }) :: Open Workspace 4
-- @bind Workspaces :: SUPER + 5 :: hl.dsp.focus({ workspace = 5 }) :: Open Workspace 5
-- @bind Workspaces :: SUPER + 6 :: hl.dsp.focus({ workspace = 6 }) :: Open Workspace 6
-- @bind Workspaces :: SUPER + 7 :: hl.dsp.focus({ workspace = 7 }) :: Open Workspace 7
-- @bind Workspaces :: SUPER + 8 :: hl.dsp.focus({ workspace = 8 }) :: Open Workspace 8
-- @bind Workspaces :: SUPER + 9 :: hl.dsp.focus({ workspace = 9 }) :: Open Workspace 9
-- @bind Workspaces :: SUPER + 0 :: hl.dsp.focus({ workspace = 10 }) :: Open Workspace 10
-- @bind Workspaces :: SUPER + SHIFT + 1 :: hl.dsp.window.move({ workspace = 1 }) :: Move Active Window to Workspace 1
-- @bind Workspaces :: SUPER + SHIFT + 2 :: hl.dsp.window.move({ workspace = 2 }) :: Move Active Window to Workspace 2
-- @bind Workspaces :: SUPER + SHIFT + 3 :: hl.dsp.window.move({ workspace = 3 }) :: Move Active Window to Workspace 3
-- @bind Workspaces :: SUPER + SHIFT + 4 :: hl.dsp.window.move({ workspace = 4 }) :: Move Active Window to Workspace 4
-- @bind Workspaces :: SUPER + SHIFT + 5 :: hl.dsp.window.move({ workspace = 5 }) :: Move Active Window to Workspace 5
-- @bind Workspaces :: SUPER + SHIFT + 6 :: hl.dsp.window.move({ workspace = 6 }) :: Move Active Window to Workspace 6
-- @bind Workspaces :: SUPER + SHIFT + 7 :: hl.dsp.window.move({ workspace = 7 }) :: Move Active Window to Workspace 7
-- @bind Workspaces :: SUPER + SHIFT + 8 :: hl.dsp.window.move({ workspace = 8 }) :: Move Active Window to Workspace 8
-- @bind Workspaces :: SUPER + SHIFT + 9 :: hl.dsp.window.move({ workspace = 9 }) :: Move Active Window to Workspace 9
-- @bind Workspaces :: SUPER + SHIFT + 0 :: hl.dsp.window.move({ workspace = 10 }) :: Move Active Wwindow to Workspace 10

-- @bind Workspaces :: SUPER + Tab :: hl.dsp.focus({ workspace = [[m+1]] }) :: Open Next Workspace
bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
-- @bind Workspaces :: SUPER + SHIFT + Tab :: hl.dsp.focus({ workspace = [[m-1]] }) :: Open Previous Workspace
bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))

for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + CTRL + " .. key, hl.dsp.exec_cmd("~/.config/hypr/scripts/moveTo.sh " .. i))
end

-- @bind Workspaces :: SUPER + CTRL + 1 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 1]]) :: Move All Windows to Workspace 1
-- @bind Workspaces :: SUPER + CTRL + 2 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 2]]) :: Move All Windows to Workspace 2
-- @bind Workspaces :: SUPER + CTRL + 3 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 3]]) :: Move All Windows to Workspace 3
-- @bind Workspaces :: SUPER + CTRL + 4 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 4]]) :: Move All Windows to Workspace 4
-- @bind Workspaces :: SUPER + CTRL + 5 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 5]]) :: Move All Windows to Workspace 5
-- @bind Workspaces :: SUPER + CTRL + 6 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 6]]) :: Move All Windows to Workspace 6
-- @bind Workspaces :: SUPER + CTRL + 7 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 7]]) :: Move All Windows to Workspace 7
-- @bind Workspaces :: SUPER + CTRL + 8 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 8]]) :: Move All Windows to Workspace 8
-- @bind Workspaces :: SUPER + CTRL + 9 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 9]]) :: Move All Windows to Workspace 9
-- @bind Workspaces :: SUPER + CTRL + 0 :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/moveTo.sh 10]]) :: Move All Windows to Workspace 10

-- Media
-- @bind Media :: XF86MonBrightnessUp :: hl.dsp.exec_cmd([[bash ~/.config/hypr/scripts/quickshell/brightness/brightness_control.sh inc 10]]) :: Brightness Up
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/quickshell/brightness/brightness_control.sh inc 10"))
-- @bind Media :: XF86MonBrightnessDown :: hl.dsp.exec_cmd([[bash ~/.config/hypr/scripts/quickshell/brightness/brightness_control.sh dec 10]]) :: Brightness Down
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/quickshell/brightness/brightness_control.sh dec 10"))
-- @bind Media :: XF86AudioRaiseVolume :: hl.dsp.exec_cmd([[bash ~/.config/hypr/scripts/quickshell/volume/audio_control.sh set-volume sink @DEFAULT_SINK@ +5]]) :: Volume Up
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/quickshell/volume/audio_control.sh set-volume sink @DEFAULT_SINK@ +5"))
-- @bind Media :: XF86AudioLowerVolume :: hl.dsp.exec_cmd([[bash ~/.config/hypr/scripts/quickshell/volume/audio_control.sh set-volume sink @DEFAULT_SINK@ -5]]) :: Volume Down
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/quickshell/volume/audio_control.sh set-volume sink @DEFAULT_SINK@ -5"))
-- @bind Media :: XF86AudioMute :: hl.dsp.exec_cmd([[bash ~/.config/hypr/scripts/quickshell/volume/audio_control.sh toggle-mute sink @DEFAULT_SINK@]]) :: Toggle Mute
bind("XF86AudioMute", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/quickshell/volume/audio_control.sh toggle-mute sink @DEFAULT_SINK@"))
-- @bind Media :: XF86AudioPlay :: hl.dsp.exec_cmd([[playerctl play-pause]]) :: Play Pause
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
-- @bind Media :: XF86AudioPause :: hl.dsp.exec_cmd([[playerctl pause]]) :: Pause
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"))
-- @bind Media :: XF86AudioNext :: hl.dsp.exec_cmd([[playerctl next]]) :: Next Track
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
-- @bind Media :: XF86AudioPrev :: hl.dsp.exec_cmd([[playerctl previous]]) :: Previous Track
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
-- @bind Media :: XF86AudioMicMute :: hl.dsp.exec_cmd([[pactl set-source-mute @DEFAULT_SOURCE@ toggle]]) :: Toggle Microphone Mute
bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
-- @bind Media :: XF86ScreenSaver :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/quickshell/lock/lock_screen.sh]]) :: Lock Screen
bind("XF86ScreenSaver", hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell/lock/lock_screen.sh"))
-- @bind Media :: SUPER + L :: hl.dsp.exec_cmd([[~/.config/hypr/scripts/quickshell/lock/lock_screen.sh]]) :: Lock Screen
bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell/lock/lock_screen.sh"))
-- @bind Media :: code:238 :: hl.dsp.exec_cmd([[brightnessctl -d smc::kbd_backlight s +10]]) :: Keyboard Brightness Up
bind("code:238", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight s +10"))
-- @bind Media :: code:237 :: hl.dsp.exec_cmd([[brightnessctl -d smc::kbd_backlight s 10-]]) :: Keyboard Brightness Down
bind("code:237", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight s 10-"))
