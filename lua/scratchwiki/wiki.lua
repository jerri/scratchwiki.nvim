local M = {}

local START_MARKER = "<!-- scratchwiki:start -->"
local END_MARKER = "<!-- scratchwiki:end -->"

local function find_markers(lines)
    local start_idx
    local end_idx

    for i, line in ipairs(lines) do
        if vim.trim(line) == START_MARKER then
            start_idx = i
        elseif vim.trim(line) == END_MARKER then
            end_idx = i
        end
    end

    if not start_idx then
        return nil, nil, "scratchwiki start marker not found"
    end

    if not end_idx then
        return nil, nil, "scratchwiki end marker not found"
    end

    if end_idx <= start_idx then
        return nil, nil, "scratchwiki end marker occurs before start marker"
    end

    return start_idx, end_idx
end

---@param bufnr? integer
---@param content string[]
---@return boolean
---@return string?
function M.replace_block(bufnr, content)
    bufnr = bufnr or 0

    local lines = vim.api.nvim_buf_get_lines(
        bufnr,
        0,
        -1,
        false
    )

    local start_idx, end_idx, err = find_markers(lines)

    if not start_idx then
        return false, err
    end

    -- Everything between the markers belongs to scratchwiki.
    -- Keep exactly one empty line around the generated task list.
    local block = { "" }

    if #content > 0 then
        vim.list_extend(block, content)
        table.insert(block, "")
    end

    vim.api.nvim_buf_set_lines(
        bufnr,
        start_idx,
        end_idx - 1,
        false,
        block
    )

    return true
end

return M
