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

---@class ScratchWikiChange
---@field old string
---@field new string

---@class ScratchWikiChanges
---@field title ScratchWikiChange?
---@field status ScratchWikiChange?

---@param lines string[]
---@param changes ScratchWikiChanges
---@return string[]?
---@return string?
local function apply_changes(lines, changes)
    local result = vim.deepcopy(lines)

    local in_frontmatter = false
    local frontmatter_finished = false
    local status_found = false
    local title_found = false

    for i, line in ipairs(result) do
        if i == 1 and line == "---" then
            in_frontmatter = true
        elseif in_frontmatter and line == "---" then
            in_frontmatter = false
            frontmatter_finished = true
        elseif in_frontmatter then
            local key, value = line:match("^([%w_%-]+):%s*(.*)$")

            if key == "status" then
                status_found = true

                if changes.status then
                    value = vim.trim(value)

                    if value ~= changes.status.old then
                        return nil, string.format(
                            "status conflict: expected %q, found %q",
                            changes.status.old,
                            value
                        )
                    end

                    result[i] = "status: " .. changes.status.new
                end
            end
        elseif frontmatter_finished and not title_found then
            local title = line:match("^#%s+(.+)$")

            if title then
                title_found = true

                if changes.title then
                    title = vim.trim(title)

                    if title ~= changes.title.old then
                        return nil, string.format(
                            "title conflict: expected %q, found %q",
                            changes.title.old,
                            title
                        )
                    end

                    result[i] = "# " .. changes.title.new
                end
            end
        end
    end

    if changes.status and not status_found then
        return nil, "status field not found in Scratch frontmatter"
    end

    if changes.title and not title_found then
        return nil, "task title not found"
    end

    return result
end

M.apply_changes = apply_changes

---@param task ScratchWikiTask
---@param changes ScratchWikiChanges
---@return boolean
---@return string?
function M.update(task, changes)
    if not task or not task.path then
        return false, "task path is missing"
    end

    if vim.fn.filereadable(task.path) ~= 1 then
        return false, "Scratch issue does not exist: " .. task.path
    end

    local lines = vim.fn.readfile(task.path)
    local updated, err = apply_changes(lines, changes)

    if not updated then
        return false, err
    end

    local temporary_path = task.path .. ".scratchwiki.tmp"

    local write_result = vim.fn.writefile(updated, temporary_path)

    if write_result ~= 0 then
        return false, "failed to write temporary file: " .. temporary_path
    end

    -- Windows does not reliably allow renaming a file over an existing file.
    -- Keep a backup briefly so the original can be restored if replacement fails.
    local backup_path = task.path .. ".scratchwiki.bak"

    vim.fn.delete(backup_path)

    local backup_result = vim.uv.fs_rename(task.path, backup_path)

    if not backup_result then
        vim.fn.delete(temporary_path)

        return false, "failed to create backup for: " .. task.path
    end

    local replace_result = vim.uv.fs_rename(temporary_path, task.path)

    if not replace_result then
        vim.uv.fs_rename(backup_path, task.path)
        vim.fn.delete(temporary_path)

        return false, "failed to replace Scratch issue: " .. task.path
    end

    vim.fn.delete(backup_path)

    return true
end

local function format_timestamp(time)
    return os.date("%Y-%m-%dT%H-%M-%S", time)
end

local function issue_content(title, status)
    return {
        "---",
        "type: task",
        "priority: normal",
        "status: " .. status,
        "tags: ",
        "---",
        "",
        "# " .. title,
        "",
    }
end

local function next_issue_path(directory, timestamp)
    local base = timestamp
    local path = directory .. "/" .. base .. ".md"

    if vim.fn.filereadable(path) ~= 1 then
        return path
    end

    local suffix = 1

    while true do
        path = string.format(
            "%s/%s-%02d.md",
            directory,
            base,
            suffix
        )

        if vim.fn.filereadable(path) ~= 1 then
            return path
        end

        suffix = suffix + 1
    end
end

---@param title string
---@param status? "open"|"done"
---@param directory? string
---@return ScratchWikiTask?
---@return string?
function M.create(title, status, directory)
    status = status or "open"

    if not title or vim.trim(title) == "" then
        return nil, "task title must not be empty"
    end

    if status ~= "open" and status ~= "done" then
        return nil, "invalid task status: " .. tostring(status)
    end

    directory = directory
        or (vim.fn.stdpath("data") .. "/scratch.nvim/issues")

    if vim.fn.isdirectory(directory) ~= 1 then
        local result = vim.fn.mkdir(directory, "p")

        if result ~= 1 then
            return nil, "failed to create Scratch directory: " .. directory
        end
    end

    title = vim.trim(title)

    local timestamp = format_timestamp(os.time())
    local path = next_issue_path(directory, timestamp)

    local lines = issue_content(title, status)

    local result = vim.fn.writefile(lines, path)

    if result ~= 0 then
        return nil, "failed to create Scratch issue: " .. path
    end

    return {
        id = vim.fn.fnamemodify(path, ":t:r"),
        title = title,
        status = status,
        type = "task",
        priority = "normal",
        tags = {},
        path = path,
    }
end

M.format_timestamp = format_timestamp
M.issue_content = issue_content
M.next_issue_path = next_issue_path

return M
