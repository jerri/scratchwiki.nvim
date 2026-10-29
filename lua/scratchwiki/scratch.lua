---@class ScratchWikiTask
---@field id string
---@field title string
---@field status string
---@field type string
---@field priority string
---@field tags string[]
---@field path string

local M = {}

local function trim(s)
    return vim.trim(s or "")
end

local function parse_tags(value)
    if not value or value == "" then
        return {}
    end

    local tags = {}

    for tag in value:gmatch("[^,]+") do
        table.insert(tags, trim(tag))
    end

    return tags
end

---@param path string
---@return ScratchWikiTask?
local function parse_file(path)
    local lines = vim.fn.readfile(path)

    if #lines == 0 then
        return nil
    end

    local task = {
        id = vim.fn.fnamemodify(path, ":t:r"),
        path = path,
        title = nil,
        status = "open",
        type = "task",
        priority = "normal",
        tags = {},
    }

    local in_frontmatter = false

    for i, line in ipairs(lines) do
        if i == 1 and line == "---" then
            in_frontmatter = true
        elseif in_frontmatter and line == "---" then
            in_frontmatter = false
        elseif in_frontmatter then
            local key, value = line:match("^([%w_%-]+):%s*(.*)$")

            if key then
                value = trim(value)

                if key == "type" then
                    task.type = value
                elseif key == "priority" then
                    task.priority = value
                elseif key == "status" then
                    task.status = value
                elseif key == "tags" then
                    task.tags = parse_tags(value)
                end
            end
        elseif not task.title then
            local title = line:match("^#%s+(.+)$")

            if title then
                task.title = trim(title)
            end
        end
    end

    if not task.title then
        return nil
    end

    return task
end

---@param directory? string
---@return ScratchWikiTask[]
function M.list(directory)
    directory = directory
        or (vim.fn.stdpath("data") .. "/scratch.nvim/issues")

    local files = vim.fn.globpath(directory, "*.md", false, true)
    local tasks = {}

    for _, path in ipairs(files) do
        local task = parse_file(path)

        if task then
            table.insert(tasks, task)
        end
    end

    table.sort(tasks, function(a, b)
        return a.id > b.id
    end)

    return tasks
end

return M
