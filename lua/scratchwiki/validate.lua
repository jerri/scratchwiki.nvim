local M = {}

local VALID_STATUS = {
    open = true,
    done = true,
}

local function validate_status(task, source)
    if not VALID_STATUS[task.status] then
        return false, string.format(
            'invalid %s status %q for task %q',
            source,
            tostring(task.status),
            tostring(task.id or task.title)
        )
    end

    return true
end

---@param wiki_tasks ScratchWikiMarkdownTask[]
---@param scratch_tasks ScratchWikiTask[]
---@return boolean
---@return string?
function M.validate(wiki_tasks, scratch_tasks)
    local wiki_ids = {}

    for _, task in ipairs(wiki_tasks) do
        local ok, err = validate_status(task, "Vimwiki")

        if not ok then
            return false, err
        end

        if task.id then
            if wiki_ids[task.id] then
                return false, string.format(
                    "duplicate ScratchWiki id %q on lines %d and %d",
                    task.id,
                    wiki_ids[task.id],
                    task.line
                )
            end

            wiki_ids[task.id] = task.line
        end
    end

    local scratch_ids = {}

    for _, task in ipairs(scratch_tasks) do
        local ok, err = validate_status(task, "Scratch")

        if not ok then
            return false, err
        end

        if scratch_ids[task.id] then
            return false, string.format(
                "duplicate Scratch id %q",
                task.id
            )
        end

        scratch_ids[task.id] = true
    end

    return true
end

return M
