-- hyprctl clients: window titles/classes
-- hyprctl layers: layer addresses

hl.window_rule({ match = { title = "^.*All Files.*$" }, float = true })
hl.window_rule({ match = { title = "^(Open Files|Send file to .*)$" }, float = true })
hl.window_rule({ match = { title = "^(KDE Connect Screen.*)$" }, float = true })
hl.window_rule({ match = { title = "^(Choose notification sounds|Choose SDDM Image/Video|Choose Profile Avatar|Choose GRUB Background)$" }, float = true })
hl.window_rule({ match = { title = "^(ArchTools Update Output)$" }, float = true })
hl.window_rule({ match = { title = "Typst Preview — Zen Browser Private Browsing" }, opacity = "1.2" })

-- Browser Picture in Picture
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, pin = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, move = "69.5% 4%" })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, opacity = "1.2" })

-- idleinhibit
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- workspaces
hl.window_rule({ match = { class = "^(discord|vesktop)$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^steam$" }, workspace = "4 silent" })
hl.window_rule({ match = { class = "^(.*Spotify.*)$" }, workspace = "4", tile = true })
hl.window_rule({ match = { class = "^(.*feishin.*)$" }, workspace = "4", tile = true })
hl.window_rule({ match = { title = "^(.*Steam\\sBig\\sPicture\\sMode.*)$" }, workspace = "1" })
hl.window_rule({ match = { initial_class = "^steam_app_\\d+$" }, workspace = "1" })
