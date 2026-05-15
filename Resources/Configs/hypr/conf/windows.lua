local colors = require("conf.colors").palette

hl.config({
    general = {
        border_size = 2,
        gaps_in = 3,
        gaps_out = 10,
        col = {
            active_border = colors.color12,
            inactive_border = colors.color13,
        },
        layout = "dwindle",
        resize_on_border = true,
        snap = {
            enabled = true,
        },
    },
})
