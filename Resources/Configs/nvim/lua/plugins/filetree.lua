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
			require("nvim-tree").setup {
                hijack_directories = {
                    enable = true,
                    auto_open = true,
                },
                hijack_unnamed_buffer_when_opening = true,
                view = {
                    side = "left",
                    width = 34,
                },
                renderer = {
                    group_empty = true,
                    highlight_git = true,
                    indent_markers = {
                        enable = true,
                    },
                    icons = {
                        show = {
                            file = true,
                            folder = true,
                            folder_arrow = true,
                            git = true,
                        },
                    },
                },
                git = {
                    enable = true,
                    ignore = false,
                },
                actions = {
                    open_file = {
                        resize_window = true,
                    },
                },
            }
		end,
        keys = {
            { "<leader>e", function() vim.cmd([[NvimTreeToggle]]) end, mode = { "n" }, desc = "Toggle nvim-tree" },
        }
	},
}
