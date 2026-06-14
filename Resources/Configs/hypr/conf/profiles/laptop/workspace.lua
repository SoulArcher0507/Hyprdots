hl.config({
    gestures = {
        workspace_swipe_create_new = true,
        workspace_swipe_invert = true,
        workspace_swipe_forever = false,
    },
})

for workspace = 5, 10 do
    hl.workspace_rule({ workspace = tostring(workspace), monitor = "SUNSHINE-TABLET" })
end

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical", action = "fullscreen" })
