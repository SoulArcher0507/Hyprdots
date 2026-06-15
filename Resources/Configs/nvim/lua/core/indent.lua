local M = {}

M.size = 4

function M.apply(bufnr)
    local buffer_options = bufnr and vim.bo[bufnr] or vim.bo

    buffer_options.tabstop = M.size
    buffer_options.softtabstop = M.size
    buffer_options.shiftwidth = M.size
    buffer_options.expandtab = true
end

function M.setup()
    vim.opt.tabstop = M.size
    vim.opt.softtabstop = M.size
    vim.opt.shiftwidth = M.size
    vim.opt.expandtab = true

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
        group = vim.api.nvim_create_augroup("FourSpaceIndent", { clear = true }),
        pattern = "*",
        callback = function(event)
            M.apply(event.buf)
        end,
    })
end

return M
