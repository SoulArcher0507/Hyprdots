local M = {}

M.size = 4

function M.apply(bufnr)
    local buffer_options = bufnr and vim.bo[bufnr] or vim.bo

    buffer_options.tabstop = M.size
    buffer_options.softtabstop = 0
    buffer_options.shiftwidth = M.size
    buffer_options.expandtab = false
end

function M.reindent(bufnr, start_line, end_line)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    M.apply(bufnr)

    vim.api.nvim_buf_call(bufnr, function()
        local view = vim.fn.winsaveview()

        if start_line and end_line then
            if start_line > end_line then
                start_line, end_line = end_line, start_line
            end

            vim.cmd(("%d,%dnormal! =="):format(start_line, end_line))
        else
            vim.cmd("silent! normal! gg=G")
        end

        vim.fn.winrestview(view)
    end)

    M.apply(bufnr)
end

function M.reindent_visual(bufnr)
    M.reindent(bufnr, vim.fn.line("'<"), vim.fn.line("'>"))
end

local function format_clients(bufnr, opts)
    local method = "textDocument/formatting"
    local clients

    local function supports_formatting(client)
        if type(client.supports_method) ~= "function" then
            return false
        end

        local ok, supports = pcall(client.supports_method, client, method, bufnr)
        return ok and supports
    end

    if vim.lsp.get_clients then
        clients = vim.lsp.get_clients({
            id = opts.id,
            bufnr = bufnr,
            name = opts.name,
            method = method,
        })
    else
        clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    end

    clients = vim.tbl_filter(supports_formatting, clients)

    if opts.filter then
        clients = vim.tbl_filter(opts.filter, clients)
    end

    return clients
end

function M.format(bufnr, opts)
    opts = opts or {}
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    M.apply(bufnr)

    local formatting_options = vim.tbl_extend("force", {
        tabSize = M.size,
        insertSpaces = false,
    }, opts.formatting_options or {})

    local clients = format_clients(bufnr, opts)
    local has_formatter = #clients > 0

    if has_formatter then
        vim.lsp.buf.format(vim.tbl_extend("force", opts, {
            bufnr = bufnr,
            formatting_options = formatting_options,
        }))
    end

    if not opts.async then
        M.reindent(bufnr)
    end

    return has_formatter
end

function M.setup()
    vim.opt.tabstop = M.size
    vim.opt.softtabstop = 0
    vim.opt.shiftwidth = M.size
    vim.opt.expandtab = false

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
        group = vim.api.nvim_create_augroup("FourSpaceIndent", { clear = true }),
        pattern = "*",
        callback = function(event)
            M.apply(event.buf)
        end,
    })
end

return M
