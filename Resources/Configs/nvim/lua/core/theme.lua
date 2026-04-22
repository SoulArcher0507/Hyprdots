local M = {}

local uv = vim.uv or vim.loop
local kitty_colors_file = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/kitty/colors.conf"
local kitty_colors_dir = vim.fn.fnamemodify(kitty_colors_file, ":h")
local kitty_colors_basename = vim.fn.fnamemodify(kitty_colors_file, ":t")
local watcher = nil
local debounce_timer = nil
local setup_done = false

local last_mtime = nil

local defaults = {
  foreground = "#cdd6f4",
  background = "#1e1e2e",
  color0 = "#45475a",
  color1 = "#f38ba8",
  color2 = "#a6e3a1",
  color3 = "#f9e2af",
  color4 = "#89b4fa",
  color5 = "#f5c2e7",
  color6 = "#94e2d5",
  color7 = "#bac2de",
  color8 = "#585b70",
  color9 = "#f38ba8",
  color10 = "#a6e3a1",
  color11 = "#f9e2af",
  color12 = "#89b4fa",
  color13 = "#f5c2e7",
  color14 = "#94e2d5",
  color15 = "#a6adc8",
}

local state = {
  palette = vim.deepcopy(defaults),
  last_error = nil,
  source = "defaults",
  applied_mtime = nil,
}

local function normalize_hex(hex)
  if type(hex) ~= "string" then return nil end
  hex = hex:gsub("^%s+", ""):gsub("%s+$", "")
  if hex:match("^#%x%x%x$") then
    return ("#%s%s%s%s%s%s"):format(
      hex:sub(2, 2), hex:sub(2, 2),
      hex:sub(3, 3), hex:sub(3, 3),
      hex:sub(4, 4), hex:sub(4, 4)
    ):lower()
  end
  if hex:match("^#%x%x%x%x%x%x$") then
    return hex:lower()
  end
  return nil
end

local function file_mtime(path)
  local stat = uv.fs_stat(path)
  if not stat then return 0 end
  if type(stat.mtime) == "table" then
    local sec = stat.mtime.sec or 0
    local nsec = stat.mtime.nsec or 0
    return sec * 1000000000 + nsec
  end
  return tonumber(stat.mtime) or 0
end

local function hex_to_rgb(hex)
  hex = normalize_hex(hex) or "#000000"
  return {
    r = tonumber(hex:sub(2, 3), 16),
    g = tonumber(hex:sub(4, 5), 16),
    b = tonumber(hex:sub(6, 7), 16),
  }
end

local function rgb_to_hex(rgb)
  local function clamp(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end
  return string.format("#%02x%02x%02x", clamp(rgb.r), clamp(rgb.g), clamp(rgb.b))
end

local function blend(a, b, t)
  local ca, cb = hex_to_rgb(a), hex_to_rgb(b)
  return rgb_to_hex({
    r = ca.r * (1 - t) + cb.r * t,
    g = ca.g * (1 - t) + cb.g * t,
    b = ca.b * (1 - t) + cb.b * t,
  })
end

local function contrast(hex)
  local c = hex_to_rgb(hex)
  local function linear(x)
    x = x / 255
    if x <= 0.04045 then return x / 12.92 end
    return ((x + 0.055) / 1.055) ^ 2.4
  end
  local l = 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  return l > 0.45 and "#0b0f14" or "#f5f7fa"
end

local function looks_dark(hex)
  local c = hex_to_rgb(hex)
  local function linear(x)
    x = x / 255
    if x <= 0.04045 then return x / 12.92 end
    return ((x + 0.055) / 1.055) ^ 2.4
  end
  local l = 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  return l < 0.45
end

local function parse_kitty_palette()
  local palette = vim.deepcopy(defaults)
  local mtime = file_mtime(kitty_colors_file)
  local f = io.open(kitty_colors_file, "r")
  if not f then
    return {
      ok = false,
      palette = palette,
      mtime = mtime,
      source = "defaults",
      error = "File non leggibile: " .. kitty_colors_file,
    }
  end

  local seen = {}
  for raw_line in f:lines() do
    local line = raw_line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^#") then
      local key, value = line:match("^([%w_]+)%s+(#[%x]+)")
      if key and value then
        if key == "foreground"
          or key == "background"
          or key == "inactive_tab_background"
          or key == "active_tab_background"
          or key == "tab_bar_background"
          or key:match("^color%d+$")
        then
          local hex = normalize_hex(value)
          if hex then
            palette[key] = hex
            seen[key] = true
          end
        end
      end
    end
  end
  f:close()

  local found_any = next(seen) ~= nil
  return {
    ok = found_any,
    palette = palette,
    mtime = mtime,
    source = found_any and "file" or "defaults",
    error = found_any and nil or ("Nessun colore valido trovato in " .. kitty_colors_file),
  }
end

local function set_hl(name, spec)
  pcall(vim.api.nvim_set_hl, 0, name, spec)
end

local function apply_palette(c)
  vim.o.termguicolors = true
  vim.o.background = looks_dark(c.background) and "dark" or "light"

  local bg = c.background
  local fg = c.foreground
  local solid_bg = c.inactive_tab_background
    or c.active_tab_background
    or c.tab_bar_background
    or blend(bg, fg, 0.08)
  local accent = c.color4
  local accent2 = c.color6
  local red = c.color1
  local green = c.color2
  local yellow = c.color3
  local blue = c.color4
  local magenta = c.color5
  local cyan = c.color6
  local subtle = c.color8

  local float_bg = blend(solid_bg, fg, 0.06)
  local bg_alt = blend(solid_bg, fg, 0.08)
  local bg_alt2 = blend(solid_bg, fg, 0.12)
  local border = blend(solid_bg, fg, 0.18)
  local cursorline = blend(solid_bg, fg, 0.05)
  local visual_bg = blend(accent, solid_bg, 0.22)
  local pmenu_bg = blend(solid_bg, fg, 0.07)
  local pmenu_sel = blend(accent, solid_bg, 0.22)
  local search_bg = blend(yellow, solid_bg, 0.22)
  local nontext = blend(subtle, solid_bg, 0.35)

  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end

  set_hl("Normal", { fg = fg, bg = solid_bg })
  set_hl("NormalNC", { fg = fg, bg = solid_bg })
  set_hl("NormalFloat", { fg = fg, bg = float_bg })
  set_hl("FloatBorder", { fg = border, bg = float_bg })
  set_hl("FloatTitle", { fg = accent, bg = float_bg, bold = true })
  set_hl("WinSeparator", { fg = border, bg = solid_bg })
  set_hl("VertSplit", { fg = border, bg = solid_bg })
  set_hl("EndOfBuffer", { fg = solid_bg, bg = solid_bg })
  set_hl("NonText", { fg = nontext, bg = solid_bg })
  set_hl("Whitespace", { fg = nontext, bg = solid_bg })
  set_hl("LineNr", { fg = subtle, bg = solid_bg })
  set_hl("CursorLineNr", { fg = accent, bg = cursorline, bold = true })
  set_hl("SignColumn", { fg = subtle, bg = solid_bg })
  set_hl("FoldColumn", { fg = subtle, bg = solid_bg })
  set_hl("CursorLine", { bg = cursorline })
  set_hl("CursorColumn", { bg = cursorline })
  set_hl("ColorColumn", { bg = bg_alt })

  set_hl("StatusLine", { fg = fg, bg = bg_alt2 })
  set_hl("StatusLineNC", { fg = subtle, bg = bg_alt })
  set_hl("TabLine", { fg = fg, bg = bg_alt })
  set_hl("TabLineFill", { fg = subtle, bg = bg_alt2 })
  set_hl("TabLineSel", { fg = contrast(accent), bg = accent, bold = true })

  set_hl("Visual", { fg = contrast(visual_bg), bg = visual_bg })
  set_hl("VisualNOS", { fg = contrast(visual_bg), bg = visual_bg })
  set_hl("Search", { fg = contrast(search_bg), bg = search_bg })
  set_hl("IncSearch", { fg = contrast(accent), bg = accent, bold = true })
  set_hl("CurSearch", { fg = contrast(accent), bg = accent, bold = true })
  set_hl("MatchParen", { fg = yellow, bg = bg_alt2, bold = true })

  set_hl("Pmenu", { fg = fg, bg = pmenu_bg })
  set_hl("PmenuSel", { fg = contrast(pmenu_sel), bg = pmenu_sel, bold = true })
  set_hl("PmenuSbar", { bg = bg_alt })
  set_hl("PmenuThumb", { bg = border })

  set_hl("Comment", { fg = subtle, italic = true })
  set_hl("Constant", { fg = cyan })
  set_hl("String", { fg = green })
  set_hl("Character", { fg = green })
  set_hl("Number", { fg = yellow })
  set_hl("Boolean", { fg = yellow, bold = true })
  set_hl("Float", { fg = yellow })
  set_hl("Identifier", { fg = fg })
  set_hl("Function", { fg = blue, bold = true })
  set_hl("Statement", { fg = magenta, bold = true })
  set_hl("Conditional", { fg = magenta, bold = true })
  set_hl("Repeat", { fg = magenta, bold = true })
  set_hl("Label", { fg = magenta })
  set_hl("Operator", { fg = accent2 })
  set_hl("Keyword", { fg = magenta, italic = true })
  set_hl("Exception", { fg = red, bold = true })
  set_hl("PreProc", { fg = accent2 })
  set_hl("Include", { fg = magenta })
  set_hl("Define", { fg = magenta })
  set_hl("Macro", { fg = accent2 })
  set_hl("Type", { fg = yellow })
  set_hl("Special", { fg = accent2 })
  set_hl("Tag", { fg = blue })
  set_hl("Delimiter", { fg = fg })
  set_hl("Underlined", { fg = blue, underline = true })
  set_hl("Todo", { fg = contrast(yellow), bg = yellow, bold = true })
  set_hl("Error", { fg = red, bold = true })

  set_hl("DiagnosticError", { fg = red })
  set_hl("DiagnosticWarn", { fg = yellow })
  set_hl("DiagnosticInfo", { fg = blue })
  set_hl("DiagnosticHint", { fg = cyan })
  set_hl("DiagnosticOk", { fg = green })
  set_hl("DiagnosticVirtualTextError", { fg = red, bg = blend(red, bg, 0.88) })
  set_hl("DiagnosticVirtualTextWarn", { fg = yellow, bg = blend(yellow, bg, 0.88) })
  set_hl("DiagnosticVirtualTextInfo", { fg = blue, bg = blend(blue, bg, 0.88) })
  set_hl("DiagnosticVirtualTextHint", { fg = cyan, bg = blend(cyan, bg, 0.88) })

  set_hl("@comment", { link = "Comment" })
  set_hl("@string", { link = "String" })
  set_hl("@number", { link = "Number" })
  set_hl("@boolean", { link = "Boolean" })
  set_hl("@function", { link = "Function" })
  set_hl("@function.call", { link = "Function" })
  set_hl("@method", { link = "Function" })
  set_hl("@keyword", { link = "Keyword" })
  set_hl("@operator", { link = "Operator" })
  set_hl("@variable", { fg = fg })
  set_hl("@property", { fg = cyan })
  set_hl("@type", { link = "Type" })
  set_hl("@field", { fg = cyan })

  set_hl("TelescopeNormal", { fg = fg, bg = float_bg })
  set_hl("TelescopeBorder", { fg = border, bg = float_bg })
  set_hl("TelescopeSelection", { fg = contrast(pmenu_sel), bg = pmenu_sel, bold = true })
  set_hl("TelescopeMatching", { fg = accent, bold = true })

  set_hl("NvimTreeNormal", { fg = fg, bg = solid_bg })
  set_hl("NvimTreeNormalNC", { fg = fg, bg = solid_bg })
  set_hl("NvimTreeWinSeparator", { fg = border, bg = solid_bg })
  set_hl("NvimTreeRootFolder", { fg = accent, bold = true })
  set_hl("NvimTreeFolderName", { fg = blue })
  set_hl("NvimTreeFolderIcon", { fg = blue })

  set_hl("BufferLineFill", { fg = subtle, bg = bg_alt2 })
  set_hl("BufferLineBackground", { fg = subtle, bg = bg_alt })
  set_hl("BufferLineBufferVisible", { fg = fg, bg = bg_alt })
  set_hl("BufferLineBufferSelected", { fg = contrast(accent), bg = accent, bold = true })
  set_hl("BufferLineIndicatorSelected", { fg = accent, bg = accent })

  set_hl("CmpItemAbbr", { fg = fg, bg = pmenu_bg })
  set_hl("CmpItemAbbrMatch", { fg = accent, bg = pmenu_bg, bold = true })
  set_hl("CmpItemAbbrMatchFuzzy", { fg = accent2, bg = pmenu_bg, italic = true })
  set_hl("CmpItemKind", { fg = cyan, bg = pmenu_bg })
  set_hl("CmpItemMenu", { fg = subtle, bg = pmenu_bg })

  vim.g.colors_name = "kitty_dynamic"
  for i = 0, 15 do
    vim.g["terminal_color_" .. i] = c["color" .. i]
  end
end


local function stop_watcher()
  if watcher then
    pcall(watcher.stop, watcher)
    pcall(watcher.close, watcher)
    watcher = nil
  end
  if debounce_timer then
    pcall(debounce_timer.stop, debounce_timer)
    pcall(debounce_timer.close, debounce_timer)
    debounce_timer = nil
  end
end

local function schedule_reload_from_watch()
  if not debounce_timer then
    debounce_timer = uv.new_timer()
  end
  if not debounce_timer then
    return
  end

  debounce_timer:stop()
  debounce_timer:start(120, 0, function()
    vim.schedule(function()
      M.reload(false)
    end)
  end)
end

local function start_watcher()
  stop_watcher()

  if vim.fn.isdirectory(kitty_colors_dir) ~= 1 then
    return false
  end

  watcher = uv.new_fs_event()
  if not watcher then
    return false
  end

  local ok, err = pcall(function()
    watcher:start(kitty_colors_dir, {}, function(fs_err, filename, _)
      if fs_err then
        vim.schedule(function()
          state.last_error = tostring(fs_err)
        end)
        return
      end

      local changed = filename
      if type(changed) == "string" and changed ~= "" and changed ~= kitty_colors_basename then
        return
      end

      schedule_reload_from_watch()
    end)
  end)

  if not ok then
    state.last_error = tostring(err)
    stop_watcher()
    return false
  end

  return true
end

function M.reload(force)
  local parsed = parse_kitty_palette()
  if not force and last_mtime ~= nil and parsed.mtime == last_mtime then
    return false
  end

  last_mtime = parsed.mtime
  state.palette = parsed.palette
  state.last_error = parsed.error
  state.source = parsed.source
  state.applied_mtime = parsed.mtime

  apply_palette(parsed.palette)
  return parsed.ok
end

function M.info()
  local parsed = parse_kitty_palette()
  return {
    path = kitty_colors_file,
    exists = vim.fn.filereadable(kitty_colors_file) == 1,
    live_source = parsed.source,
    live_mtime = parsed.mtime,
    live_background = parsed.palette.background,
    live_foreground = parsed.palette.foreground,
    live_inactive_tab_background = parsed.palette.inactive_tab_background,
    live_active_tab_background = parsed.palette.active_tab_background,
    live_tab_bar_background = parsed.palette.tab_bar_background,
    live_color4 = parsed.palette.color4,
    live_color6 = parsed.palette.color6,
    applied_source = state.source,
    applied_mtime = state.applied_mtime,
    applied_background = state.palette.background,
    applied_foreground = state.palette.foreground,
    applied_inactive_tab_background = state.palette.inactive_tab_background,
    applied_active_tab_background = state.palette.active_tab_background,
    applied_tab_bar_background = state.palette.tab_bar_background,
    applied_color4 = state.palette.color4,
    applied_color6 = state.palette.color6,
    last_error = parsed.error or state.last_error,
  }
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  M.reload(true)
  start_watcher()

  vim.api.nvim_create_user_command("ReloadKittyTheme", function()
    local ok = M.reload(true)
    if ok then
      vim.notify("Tema Neovim ricaricato da kitty/colors.conf")
    else
      vim.notify(state.last_error or "Impossibile leggere kitty/colors.conf", vim.log.levels.WARN)
    end
  end, {})

  vim.api.nvim_create_user_command("KittyThemeInfo", function()
    print(vim.inspect(M.info()))
  end, {})

  local group = vim.api.nvim_create_augroup("KittyDynamicTheme", { clear = true })

  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "VimResume", "BufEnter", "User" }, {
    group = group,
    pattern = { "*", "VeryLazy" },
    callback = function()
      vim.schedule(function() M.reload(false) end)
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      if vim.g.colors_name ~= "kitty_dynamic" then
        vim.schedule(function() M.reload(true) end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stop_watcher()
    end,
  })
end

return M
