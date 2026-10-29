local M = {}

---@class ScratchWikiMarkdownTask
---@field id string?
---@field title string
---@field status "open"|"done"
---@field line integer

---@param tasks ScratchWikiTask[]
---@return string[]
function M.render(tasks)
    local lines = {}

    for _, task in ipairs(tasks) do
        local checkbox = task.status == "done" and "X" or " "

        table.insert(
            lines,
            string.format(
                "- [%s] %s <!-- scratchwiki:id=%s -->",
                checkbox,
                task.title,
                task.id
            )
        )
    end

    return lines
end

---@param line string
---@param line_number integer
---@return ScratchWikiMarkdownTask?
local function parse_line(line, line_number)
    -- Match Markdown checkbox.
    --
    -- Accepted:
    --   - [ ] Foo
    --   - [x] Foo
    --   - [X] Foo
    --
    -- Leading whitespace is allowed.
    local checkbox, rest = line:match("^%s*%-%s+%[([ xX])%]%s+(.+)$")

    if not checkbox then
        return nil
    end

    -- Extract our optional ScratchWiki ID.
    local id = rest:match(
        "%s*<!%-%-%s*scratchwiki:id=([^%s]+)%s*%-%->%s*$"
    )

    -- Remove the ID comment from the visible task title.
    local title = rest:gsub(
        "%s*<!%-%-%s*scratchwiki:id=[^%s]+%s*%-%->%s*$",
        ""
    )

    title = vim.trim(title)

    if title == "" then
        return nil
    end

    return {
        id = id,
        title = title,
        status = checkbox:lower() == "x" and "done" or "open",
        line = line_number,
    }
end

---@param lines string[]
---@return ScratchWikiMarkdownTask[]
function M.parse(lines)
    local tasks = {}

    for line_number, line in ipairs(lines) do
        local task = parse_line(line, line_number)

        if task then
            table.insert(tasks, task)
        end
    end

    return tasks
end

return M
