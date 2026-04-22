return {
    -- File tree
	{
		"nvim-tree/nvim-tree.lua",
		version = "*",
		lazy = false,
		requires = {
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("nvim-tree").setup {}
		end,
        keys = {
            { "<leader>e", function() vim.cmd([[NvimTreeToggle]]) end, mode = { "n" }, desc = "Toggle nvim-tree" },
        }
	},
}
