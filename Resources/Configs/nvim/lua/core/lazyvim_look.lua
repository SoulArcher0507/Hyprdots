local M = {}

local function safe_setup(module, setup)
    local ok, plugin = pcall(require, module)
    if ok then
        pcall(setup, plugin)
    end
end

function M.apply_plugin_style()
    safe_setup("bufferline", function(bufferline)
        bufferline.setup({
            options = {
                mode = "buffers",
                diagnostics = "nvim_lsp",
                always_show_bufferline = false,
                separator_style = "thin",
                show_buffer_close_icons = false,
                show_close_icon = false,
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = "Explorer",
                        highlight = "Directory",
                        separator = true,
                    },
                },
            },
        })
    end)

    safe_setup("telescope", function(telescope)
        telescope.setup({
            defaults = {
                prompt_prefix = "> ",
                selection_caret = "> ",
                sorting_strategy = "ascending",
                layout_strategy = "horizontal",
                layout_config = {
                    width = 0.88,
                    height = 0.82,
                    horizontal = {
                        prompt_position = "top",
                        preview_width = 0.55,
                    },
                    vertical = {
                        mirror = false,
                    },
                },
                border = true,
                borderchars = {
                    prompt = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                    results = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                    preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                },
            },
        })
    end)
end

function M.apply_palette(colors, helpers)
    local set_hl = helpers.set_hl
    local blend = helpers.blend
    local contrast = helpers.contrast

    local bg = colors.background
    local fg = colors.foreground
    local panel = colors.inactive_tab_background
        or colors.active_tab_background
        or colors.tab_bar_background
        or blend(bg, fg, 0.08)
    local accent = colors.color4
    local accent2 = colors.color6
    local red = colors.color1
    local green = colors.color2
    local yellow = colors.color3
    local subtle = colors.color8
    local float_bg = blend(panel, fg, 0.06)
    local panel_alt = blend(panel, fg, 0.1)
    local border = blend(panel, fg, 0.2)
    local muted = blend(subtle, panel, 0.3)

    set_hl("LazyNormal", { fg = fg, bg = float_bg })
    set_hl("LazyButton", { fg = fg, bg = panel_alt })
    set_hl("LazyButtonActive", { fg = contrast(accent), bg = accent, bold = true })
    set_hl("LazySpecial", { fg = accent2 })

    set_hl("WhichKey", { fg = accent, bold = true })
    set_hl("WhichKeyDesc", { fg = fg })
    set_hl("WhichKeyGroup", { fg = accent2 })
    set_hl("WhichKeySeparator", { fg = muted })
    set_hl("WhichKeyFloat", { bg = float_bg })
    set_hl("WhichKeyBorder", { fg = border, bg = float_bg })

    set_hl("NoiceCmdlinePopup", { fg = fg, bg = float_bg })
    set_hl("NoiceCmdlinePopupBorder", { fg = accent, bg = float_bg })
    set_hl("NoiceCmdlineIcon", { fg = accent2, bg = float_bg })
    set_hl("NoicePopup", { fg = fg, bg = float_bg })
    set_hl("NoicePopupBorder", { fg = border, bg = float_bg })
    set_hl("NoiceMini", { fg = muted, bg = panel_alt })

    set_hl("NotifyERRORBorder", { fg = red })
    set_hl("NotifyWARNBorder", { fg = yellow })
    set_hl("NotifyINFOBorder", { fg = accent })
    set_hl("NotifyDEBUGBorder", { fg = subtle })
    set_hl("NotifyTRACEBorder", { fg = accent2 })
    set_hl("NotifyERRORIcon", { fg = red })
    set_hl("NotifyWARNIcon", { fg = yellow })
    set_hl("NotifyINFOIcon", { fg = accent })
    set_hl("NotifyDEBUGIcon", { fg = subtle })
    set_hl("NotifyTRACEIcon", { fg = accent2 })
    set_hl("NotifyERRORTitle", { fg = red, bold = true })
    set_hl("NotifyWARNTitle", { fg = yellow, bold = true })
    set_hl("NotifyINFOTitle", { fg = accent, bold = true })
    set_hl("NotifyDEBUGTitle", { fg = subtle, bold = true })
    set_hl("NotifyTRACETitle", { fg = accent2, bold = true })
    set_hl("NotifyBackground", { bg = float_bg })

    set_hl("IblIndent", { fg = blend(panel, fg, 0.13), nocombine = true })
    set_hl("IblScope", { fg = accent, nocombine = true })

    set_hl("TodoBgFIX", { fg = contrast(red), bg = red, bold = true })
    set_hl("TodoBgWARN", { fg = contrast(yellow), bg = yellow, bold = true })
    set_hl("TodoBgNOTE", { fg = contrast(accent), bg = accent, bold = true })
    set_hl("TodoBgPERF", { fg = contrast(accent2), bg = accent2, bold = true })

    set_hl("LspInlayHint", { fg = muted, bg = panel_alt })
    set_hl("FloatFooter", { fg = muted, bg = float_bg })
end

function M.setup()
    vim.opt.laststatus = 3
    vim.opt.showmode = false
    vim.opt.pumblend = 8
    vim.opt.winblend = 0

    pcall(function()
        vim.opt.winborder = "rounded"
    end)

    vim.diagnostic.config({
        severity_sort = true,
        signs = {
            text = {
                [vim.diagnostic.severity.ERROR] = "E",
                [vim.diagnostic.severity.WARN] = "W",
                [vim.diagnostic.severity.INFO] = "I",
                [vim.diagnostic.severity.HINT] = "H",
            },
        },
        float = {
            border = "rounded",
            source = "if_many",
        },
    })

    local hover = vim.lsp.handlers.hover
    vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
        config = vim.tbl_deep_extend("force", config or {}, { border = "rounded" })
        return hover(err, result, ctx, config)
    end

    local signature_help = vim.lsp.handlers.signature_help
    vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
        config = vim.tbl_deep_extend("force", config or {}, { border = "rounded" })
        return signature_help(err, result, ctx, config)
    end

    vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
            M.apply_plugin_style()
        end,
    })

    local startup_path = vim.fn.argv(0)
    if startup_path ~= "" and vim.fn.isdirectory(startup_path) == 1 then
        local startup_dir = vim.fn.fnamemodify(startup_path, ":p")

        vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = function()
                local initial_buf = vim.api.nvim_get_current_buf()

                vim.schedule(function()
                    vim.cmd("tcd " .. vim.fn.fnameescape(startup_dir))

                    local ok, api = pcall(require, "nvim-tree.api")
                    if not ok then
                        return
                    end

                    api.tree.close()
                    api.tree.open({
                        path = startup_dir,
                        current_window = true,
                    })

                    local current_buf = vim.api.nvim_get_current_buf()
                    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                        if vim.api.nvim_buf_is_valid(bufnr) and bufnr ~= current_buf then
                            local name = vim.api.nvim_buf_get_name(bufnr)
                            local path = name ~= "" and vim.fn.fnamemodify(name, ":p") or ""
                            if name == "" or path == startup_dir then
                                pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
                            end
                        end
                    end
                end)
            end,
        })
    end

    vim.schedule(M.apply_plugin_style)
end

return M
