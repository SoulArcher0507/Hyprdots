return {
    {
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
        config = function()
            local cmp = require('cmp')

            cmp.setup({
                sources = {
                    { name = 'nvim_lsp' },
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-u>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-d>'] = cmp.mapping.scroll_docs(4),
                    ['<Tab>'] = cmp.mapping.confirm({ select = true }),
                }),
                snippet = {
                    expand = function(args)
                        vim.snippet.expand(args.body)
                    end,
                },
            })
        end
    },
    -- LSP
    {
        'neovim/nvim-lspconfig',
        cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
        event = { 'BufReadPre', 'BufNewFile' },
        dependencies = {
            { 'hrsh7th/cmp-nvim-lsp' },
            { 'williamboman/mason.nvim' },
            { 'williamboman/mason-lspconfig.nvim' },
        },
        init = function()
            -- Reserve a space in the gutter
            -- This will avoid an annoying layout shift in the screen
            vim.opt.signcolumn = 'yes'
        end,
        config = function()
            local indent = require("core.indent")
            local lsp_defaults = require('lspconfig').util.default_config
            local lspconfig = require('lspconfig')
            local format_augroup = vim.api.nvim_create_augroup('LspFormatOnSave', { clear = true })
            local format_on_save_disabled = {
                typst = true,
                markdown = true,
                c = true,
                cpp = true,
                objc = true,
                objcpp = true,
            }

            -- Add cmp_nvim_lsp capabilities settings to lspconfig
            -- This should be executed before you configure any language server
            lsp_defaults.capabilities = vim.tbl_deep_extend(
                'force',
                lsp_defaults.capabilities,
                require('cmp_nvim_lsp').default_capabilities()
            )

            -- LspAttach is where you enable features that only work
            -- if there is a language server active in the file
            vim.api.nvim_create_autocmd('LspAttach', {
                desc = 'LSP actions',
                callback = function(event)
                    local opts = { buffer = event.buf }

                    -- Borders
                    local border = "rounded"
                    vim.diagnostic.config({
                        float = { border = border }
                    })

                    -- Keymaps
                    vim.keymap.set("n", "K", function()
                        vim.lsp.buf.hover({ border = border })
                    end, opts)
                    vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
                    vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
                    vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
                    vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
                    vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
                    vim.keymap.set("n", "gs", function()
                        vim.lsp.buf.signature_help({ border = border })
                    end, opts)
                    vim.keymap.set('n', 'rn', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
                    vim.keymap.set('n', '<F3>', function()
                        indent.reindent(event.buf)
                    end, opts)
                    vim.keymap.set('x', '<F3>', function()
                        indent.reindent_visual(event.buf)
                    end, opts)
                    vim.keymap.set('n', 'vca', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
                    vim.keymap.set('n', '<leader>vd', '<cmd>lua vim.diagnostic.open_float()<cr>')

                    -- Format on save
                    vim.api.nvim_clear_autocmds({
                        group = format_augroup,
                        buffer = event.buf,
                    })
                    vim.api.nvim_create_autocmd('BufWritePre', {
                        group = format_augroup,
                        buffer = event.buf,
                        callback = function()
                            if format_on_save_disabled[vim.bo[event.buf].filetype] then
                                return
                            end

                            indent.format(event.buf, { async = false })
                        end,
                    })
                end,
            })

            require('mason-lspconfig').setup({
                ensure_installed = {},
                handlers = {
                    -- this first function is the "default handler"
                    -- it applies to every language server without a "custom handler"
                    function(server_name)
                        lspconfig[server_name].setup({})
                    end,
                    clangd = function()
                        lspconfig.clangd.setup({
                            cmd = {
                                'clangd',
                                '--fallback-style={BasedOnStyle: LLVM, IndentWidth: 4, ContinuationIndentWidth: 4, TabWidth: 4, UseTab: Never}',
                            },
                        })
                    end,
                }
            })
        end
    }
}
