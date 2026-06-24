vim.g.mapleader = " "
local indent = require("core.indent")

-- Change file
vim.keymap.set("n", "<leader>ve", vim.cmd.Ex, { desc = "Open netrw explorer" })

-- Tabs (next, previous, close)
vim.keymap.set("n", "<leader>n", "<cmd>bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>p", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close buffer" })

-- Copy to clipboard
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])

-- Center after scrolling
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<C-d>", "<C-d>zz")

-- Reindent
vim.keymap.set("n", "<F3>", function()
    indent.reindent(0)
end)
vim.keymap.set("x", "<F3>", function()
    indent.reindent_visual(0)
end)
