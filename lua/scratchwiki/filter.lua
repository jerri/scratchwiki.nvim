local M = {}

---@param task ScratchWikiTask
---@param options table
---@return boolean
function M.matches(task, options)
    if options.status then
        if task.status ~= options.status then
            return false
        end
    end

    return true
end

---@param tasks ScratchWikiTask[]
---@param options table
---@return ScratchWikiTask[]
function M.apply(tasks, options)
    local result = {}

    for _, task in ipairs(tasks) do
        if M.matches(task, options) then
            table.insert(result, task)
        end
    end

    return result
end

return M
