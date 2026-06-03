local M = {}

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end

    return value:match("^%s*(.-)%s*$")
end

local function read_first_line(path)
    local file = io.open(path, "r")
    if file == nil then
        return nil
    end

    local line = file:read("*l")
    file:close()

    return trim(line)
end

local function normalize_profile(value)
    value = trim(value)
    if value == nil or value == "" then
        return nil
    end

    value = value:lower()
    if value == "pc" or value == "desktop" then
        return "desktop"
    end

    if value == "laptop" or value == "notebook" or value == "portable" then
        return "laptop"
    end

    return nil
end

local laptop_chassis_types = {
    ["8"] = true,  -- portable
    ["9"] = true,  -- laptop
    ["10"] = true, -- notebook
    ["14"] = true, -- sub-notebook
    ["30"] = true, -- tablet
    ["31"] = true, -- convertible
    ["32"] = true, -- detachable
}

local desktop_chassis_types = {
    ["3"] = true,  -- desktop
    ["4"] = true,  -- low profile desktop
    ["5"] = true,  -- pizza box
    ["6"] = true,  -- mini tower
    ["7"] = true,  -- tower
    ["13"] = true, -- all-in-one
    ["15"] = true, -- space-saving
    ["16"] = true, -- lunch box
    ["35"] = true, -- mini PC
    ["36"] = true, -- stick PC
}

local function has_lid()
    return read_first_line("/proc/acpi/button/lid/LID/state") ~= nil
        or read_first_line("/proc/acpi/button/lid/LID0/state") ~= nil
end

local function has_internal_battery()
    local ok, pipe = pcall(io.popen, "ls -1 /sys/class/power_supply 2>/dev/null")
    if not ok or pipe == nil then
        return false
    end

    for name in pipe:lines() do
        local supply_type = read_first_line("/sys/class/power_supply/" .. name .. "/type")
        if supply_type == "Battery" or name:match("^BAT%d*$") then
            pipe:close()
            return true
        end
    end

    pipe:close()
    return false
end

local function detect_profile()
    local override = normalize_profile(os.getenv("HYPRDOTS_DEVICE_PROFILE"))
        or normalize_profile(os.getenv("HYPRDOTS_PROFILE"))

    if override ~= nil then
        return override
    end

    local chassis_type = read_first_line("/sys/class/dmi/id/chassis_type")
    if laptop_chassis_types[chassis_type] then
        return "laptop"
    end

    if desktop_chassis_types[chassis_type] then
        return "desktop"
    end

    if has_lid() or has_internal_battery() then
        return "laptop"
    end

    return "desktop"
end

M.profile = detect_profile()

function M.is_laptop()
    return M.profile == "laptop"
end

function M.is_desktop()
    return M.profile == "desktop"
end

return M
