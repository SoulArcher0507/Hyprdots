-- Typst
return {
    {
        'chomosuke/typst-preview.nvim',
        tag = 'v1.3.2',
        config = function()
            require 'typst-preview'.setup {
                open_cmd = 'zen-browser --private-window %s',
                -- open_cmd = 'firefox %s',
                -- open_cmd = 'vivaldi --app=%s',
                dependencies_bin = { ['tinymist'] = 'tinymist' },
            }
            vim.keymap.set("n", "<leader>tc", ":TypstPreviewToggle<cr>")
        end,
    },
}
