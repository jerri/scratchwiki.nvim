local M = {}

---@param bufnr? integer
---@return boolean
function M.refresh(bufnr)
    bufnr = bufnr or 0

    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
        vim.notify(
            "scratchwiki: invalid buffer",
            vim.log.levels.ERROR
        )

        return false
    end

    if not vim.api.nvim_buf_is_loaded(bufnr) then
        vim.notify(
            "scratchwiki: buffer is not loaded",
            vim.log.levels.ERROR
        )

        return false
    end

    local scratch = require("scratchwiki.scratch")
    local markdown = require("scratchwiki.markdown")
    local wiki = require("scratchwiki.wiki")

    local cursor
    local current_win

    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        current_win = win

        if win == vim.api.nvim_get_current_win() then
            break
        end
    end

    if current_win and vim.api.nvim_win_is_valid(current_win) then
        cursor = vim.api.nvim_win_get_cursor(current_win)
    end

    local tasks = scratch.list()
    local lines = markdown.render(tasks)

    local ok, result = wiki.replace_block(
        bufnr,
        lines,
        cursor and cursor[1] or nil
    )

    if not ok then
        vim.notify(
            "scratchwiki: " .. result,
            vim.log.levels.ERROR
        )

        return false
    end

    if cursor and current_win and vim.api.nvim_win_is_valid(current_win) then
        local new_line = cursor[1]

        if result.cursor_line then
            new_line = result.cursor_line
        end

        local line_count = vim.api.nvim_buf_line_count(bufnr)
        new_line = math.min(new_line, line_count)

        vim.api.nvim_win_set_cursor(
            current_win,
            { new_line, cursor[2] }
        )
    end

    return true
end

return M
