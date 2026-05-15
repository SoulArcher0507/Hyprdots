local defaults = {
    bg = "rgb(111111)",
    fg = "rgb(cccccc)",
    cursor = "rgb(cccccc)",
    color0 = "rgb(111111)",
    color1 = "rgb(dc2f2f)",
    color2 = "rgb(98c379)",
    color3 = "rgb(d19a66)",
    color4 = "rgb(61afef)",
    color5 = "rgb(c678dd)",
    color6 = "rgb(56b6c2)",
    color7 = "rgb(abb2bf)",
    color8 = "rgb(3e4451)",
    color9 = "rgb(e06c75)",
    color10 = "rgb(98c379)",
    color11 = "rgb(d19a66)",
    color12 = "rgb(61afef)",
    color13 = "rgb(c678dd)",
    color14 = "rgb(56b6c2)",
    color15 = "rgb(ffffff)",
    accent = "rgb(61afef)",
    accent2 = "rgb(56b6c2)",
    success = "rgb(98c379)",
    warning = "rgb(d19a66)",
    danger = "rgb(dc2f2f)",
    muted = "rgb(3e4451)",
}

local function merge(base, override)
    if type(override) ~= "table" then
        return base
    end

    for key, value in pairs(override) do
        if type(value) == "string" and value ~= "" then
            base[key] = value
        end
    end

    return base
end

local palette = merge({}, defaults)

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local generated_path = config_home .. "/hypr/colors.lua"
local generated_file = io.open(generated_path, "r")

if generated_file ~= nil then
    generated_file:close()
    local ok, generated = pcall(dofile, generated_path)
    if ok then
        merge(palette, generated)
    end
end

return {
    palette = palette,
}
