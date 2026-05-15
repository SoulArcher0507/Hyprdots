
local modules = {
    "conf.environment",
    "conf.monitor",
    "conf.cursor",
    "conf.keyboard",
    "conf.autostart",
    "conf.windows",
    "conf.decoration",
    "conf.layout",
    "conf.workspace",
    "conf.misc",
    "conf.keybindings",
    "conf.windowrules",
    "conf.animation",
}

for _, module in ipairs(modules) do
    require(module)
end
