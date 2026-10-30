local M = {}

local END_MARKER = "<!-- scratchwiki:end -->"

local function parse_start_marker(line)
    local content = vim.trim(line):match(
        "^<!%-%-%s*scratchwiki:start%s*(.-)%s*%-%->$"
    )

    if content == nil then
        return nil
    end

    local options = {}

    for key, value in content:gmatch("([%w_-]+)=([^%s]+)") do
        options[key] = value
    end

    return options
end

M.parse_start_marker = parse_start_marker

---@param lines string[]
---@return integer?
---@return integer?
---@return string?
local function find_markers(lines)
    local start_idx
    local end_idx

    for i, line in ipairs(lines) do
        local trimmed = vim.trim(line)

        if parse_start_marker(trimmed) ~= nil then
            if start_idx then
                return nil, nil, "multiple scratchwiki start markers found"
            end

            start_idx = i
        elseif trimmed == END_MARKER then
            if end_idx then
                return nil, nil, "multiple scratchwiki end markers found"
            end

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

local function lines_equal(left, right)
    if #left ~= #right then
        return false
    end

    for i, line in ipairs(left) do
        if line ~= right[i] then
            return false
        end
    end

    return true
end

---@param content string[]
---@return string[]
local function build_block(content)
    local block = { "" }

    if #content > 0 then
        vim.list_extend(block, content)
        table.insert(block, "")
    end

    return block
end

---@param bufnr? integer
---@return string[]?
---@return string?
function M.get_block(bufnr)
    bufnr = bufnr or 0

    local lines = vim.api.nvim_buf_get_lines(
        bufnr,
        0,
        -1,
        false
    )

    local start_idx, end_idx, err = find_markers(lines)

    if not start_idx then
        return nil, err
    end

    local block = {}

    for i = start_idx + 1, end_idx - 1 do
        table.insert(block, lines[i])
    end

    return block
end

---@class ScratchWikiReplaceResult
---@field start_line integer
---@field old_end_line integer
---@field new_end_line integer
---@field line_delta integer
---@field cursor_line integer?
---@field changed boolean

---@param bufnr? integer
---@param content string[]
---@param cursor_line? integer
---@return boolean
---@return ScratchWikiReplaceResult|string
function M.replace_block(bufnr, content, cursor_line)
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

    local block = build_block(content)

    local existing_block = {}

    for i = start_idx + 1, end_idx - 1 do
        table.insert(existing_block, lines[i])
    end

    if lines_equal(existing_block, block) then
        return true, {
            start_line = start_idx,
            old_end_line = end_idx,
            new_end_line = end_idx,
            line_delta = 0,
            cursor_line = cursor_line,
            changed = false,
        }
    end

    local old_content_count = end_idx - start_idx - 1
    local new_content_count = #block
    local line_delta = new_content_count - old_content_count

    local adjusted_cursor_line = cursor_line

    if cursor_line and cursor_line > end_idx then
        adjusted_cursor_line = cursor_line + line_delta
    end

    vim.api.nvim_buf_set_lines(
        bufnr,
        start_idx,
        end_idx - 1,
        false,
        block
    )

    return true, {
        start_line = start_idx,
        old_end_line = end_idx,
        new_end_line = end_idx + line_delta,
        line_delta = line_delta,
        cursor_line = adjusted_cursor_line,
        changed = true,
    }
end

M.find_markers = find_markers
M.build_block = build_block

---@param bufnr? integer
---@return boolean
function M.has_block(bufnr)
    bufnr = bufnr or 0

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local start_idx, end_idx = find_markers(lines)

    return start_idx ~= nil and end_idx ~= nil
end

---@param bufnr? integer
---@return table?
---@return string?
function M.get_options(bufnr)
    bufnr = bufnr or 0

    local lines = vim.api.nvim_buf_get_lines(
        bufnr,
        0,
        -1,
        false
    )

    for _, line in ipairs(lines) do
        local options = parse_start_marker(line)

        if options ~= nil then
            return options
        end
    end

    return nil, "scratchwiki start marker not found"
end

---@param bufnr? integer
---@return string?
function M.task_id_at_cursor(bufnr)
    bufnr = bufnr or 0

    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_number = cursor[1]

    local line = vim.api.nvim_buf_get_lines(
        bufnr,
        line_number - 1,
        line_number,
        false
    )[1]

    if not line then
        return nil
    end

    return line:match(
        "<!%-%-%s*scratchwiki:id=([^%s]+)%s*%-%->"
    )
end

return M
