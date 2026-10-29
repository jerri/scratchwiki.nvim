local M = {}

---@param scratch_tasks ScratchWikiTask[]
---@param wiki_tasks ScratchWikiMarkdownTask[]
---@return table[]
function M.reconcile(scratch_tasks, wiki_tasks)
    local operations = {}
    local scratch_by_id = {}

    for _, task in ipairs(scratch_tasks) do
        scratch_by_id[task.id] = task
    end

    for _, wiki_task in ipairs(wiki_tasks) do
        if not wiki_task.id then
            table.insert(operations, {
                action = "create",
                title = wiki_task.title,
                status = wiki_task.status,
                line = wiki_task.line,
            })

            goto continue
        end

        local scratch_task = scratch_by_id[wiki_task.id]

        if not scratch_task then
            table.insert(operations, {
                action = "orphan",
                id = wiki_task.id,
                title = wiki_task.title,
                status = wiki_task.status,
                line = wiki_task.line,
            })

            goto continue
        end

        local changes = {}

        if scratch_task.title ~= wiki_task.title then
            changes.title = {
                old = scratch_task.title,
                new = wiki_task.title,
            }
        end

        if scratch_task.status ~= wiki_task.status then
            changes.status = {
                old = scratch_task.status,
                new = wiki_task.status,
            }
        end

        if next(changes) then
            table.insert(operations, {
                action = "update",
                id = wiki_task.id,
                changes = changes,
                line = wiki_task.line,
            })
        else
            table.insert(operations, {
                action = "unchanged",
                id = wiki_task.id,
                line = wiki_task.line,
            })
        end

        ::continue::
    end

    return operations
end

return M
