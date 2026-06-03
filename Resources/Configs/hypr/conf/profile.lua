local device = require("conf.device")

local M = {
    name = device.profile,
}

function M.load(module_name)
    return require("conf.profiles." .. M.name .. "." .. module_name)
end

return M
