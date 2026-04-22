return {
    {
        "mason-org/mason.nvim",
        config = function()
            -- 1. Setup di Mason (base)
            require("mason").setup()

            -- 2. Setup di Mason-LSPConfig (qui definisci cosa installare)
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "clangd",
                    "pyright",
                    "bashls",
                    "tinymist",
                },
                automatic_installation = true,
            })
        end,
    },
    {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = {
            "mason-org/mason.nvim",
            "mfussenegger/nvim-dap",
        },
        opts = {
            automatic_installation = true,
            ensure_installed = {
                -- add debuggers you want here
            },
        },
    },
}
