-- hyprctl clients: window titles/classes
-- hyprctl layers: layer addresses

hl.window_rule({ match = { title = "^.*Open Files.*$" }, float = true })
hl.window_rule({ match = { title = "Typst Preview — Mozilla Firefox" }, opacity = "1.3" })

-- Browser Picture in Picture
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, pin = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, move = "69.5% 4%" })

-- idleinhibit
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
