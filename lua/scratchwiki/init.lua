local M = {}

function M.refresh(bufnr)
    bufnr = bufnr or 0

    local scratch = require("scratchwiki.scratch")
    local markdown = require("scratchwiki.markdown")
    local wiki = require("scratchwiki.wiki")

    local cursor

    if bufnr == 0 or bufnr == vim.api.nvim_get_current_buf() then
        cursor = vim.api.nvim_win_get_cursor(0)
    end

    local tasks = scratch.list()
    local lines = markdown.render(tasks)

    local ok, err = wiki.replace_block(bufnr, lines)

    if not ok then
        vim.notify(
            "scratchwiki: " .. err,
            vim.log.levels.ERROR
        )
        return false
    end

    if cursor then
        local line_count = vim.api.nvim_buf_line_count(bufnr)

        cursor[1] = math.min(cursor[1], line_count)

        vim.api.nvim_win_set_cursor(0, cursor)
    end

    return true
end

return M
