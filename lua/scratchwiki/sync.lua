local M = {}

---@param operations table[]
---@return string[]
local function format_operations(operations)
    local lines = {}

    local counts = {
        create = 0,
        update = 0,
        unchanged = 0,
        orphan = 0,
    }

    for _, operation in ipairs(operations) do
        counts[operation.action] = (counts[operation.action] or 0) + 1

        if operation.action == "create" then
            table.insert(
                lines,
                string.format(
                    "CREATE   line %d: %s [%s]",
                    operation.line,
                    operation.title,
                    operation.status
                )
            )
        elseif operation.action == "update" then
            local changes = {}

            if operation.changes.status then
                table.insert(
                    changes,
                    string.format(
                        "status: %s -> %s",
                        operation.changes.status.old,
                        operation.changes.status.new
                    )
                )
            end

            if operation.changes.title then
                table.insert(
                    changes,
                    string.format(
                        'title: "%s" -> "%s"',
                        operation.changes.title.old,
                        operation.changes.title.new
                    )
                )
            end

            table.insert(
                lines,
                string.format(
                    "UPDATE   line %d: %s (%s)",
                    operation.line,
                    operation.id,
                    table.concat(changes, ", ")
                )
            )
        elseif operation.action == "orphan" then
            table.insert(
                lines,
                string.format(
                    "ORPHAN   line %d: %s (%s)",
                    operation.line,
                    operation.id,
                    operation.title
                )
            )
        end
    end

    local summary = string.format(
        "%d create, %d update, %d unchanged, %d orphan",
        counts.create,
        counts.update,
        counts.unchanged,
        counts.orphan
    )

    return lines, summary
end

---@param bufnr? integer
---@return table[]?
---@return string?
function M.plan(bufnr)
    bufnr = bufnr or 0

    local wiki = require("scratchwiki.wiki")
    local markdown = require("scratchwiki.markdown")
    local scratch = require("scratchwiki.scratch")
    local reconcile = require("scratchwiki.reconcile")

    local block, err = wiki.get_block(bufnr)

    if not block then
        return nil, err
    end

    local wiki_tasks = markdown.parse(block)
    local scratch_tasks = scratch.list()

    local validate = require("scratchwiki.validate")

    local ok, validation_err = validate.validate(
        wiki_tasks,
        scratch_tasks
    )

    if not ok then
        return nil, validation_err
    end

    local operations = reconcile.reconcile(
        scratch_tasks,
        wiki_tasks
    )

    return operations, nil, scratch_tasks
end

---@param operations table[]
---@param scratch_tasks ScratchWikiTask[]
---@return boolean
---@return string?
---@return integer
local function execute_operations(operations, scratch_tasks, directory)
    local scratch = require("scratchwiki.scratch")

    local scratch_by_id = {}

    for _, task in ipairs(scratch_tasks) do
        scratch_by_id[task.id] = task
    end

    local applied = 0

    -- Orphans make the state ambiguous. Abort before performing anything.
    for _, operation in ipairs(operations) do
        if operation.action == "orphan" then
            return false, string.format(
                'cannot sync: Scratch issue %q no longer exists (line %d)',
                operation.id,
                operation.line
            ), applied
        end
    end

    for _, operation in ipairs(operations) do
        if operation.action == "update" then
            local task = scratch_by_id[operation.id]

            if not task then
                return false, string.format(
                    'Scratch issue %q disappeared during synchronization',
                    operation.id
                ), applied
            end

            local ok, err = scratch.update(
                task,
                operation.changes
            )

            if not ok then
                return false, string.format(
                    'failed to update %q: %s',
                    operation.id,
                    err
                ), applied
            end

            applied = applied + 1
        elseif operation.action == "create" then
            local task, err = scratch.create(
                operation.title,
                operation.status,
                directory
            )

            if not task then
                return false, string.format(
                    'failed to create %q: %s',
                    operation.title,
                    err
                ), applied
            end

            applied = applied + 1
        end
    end

    return true, nil, applied
end

M.execute_operations = execute_operations

---@param bufnr? integer
---@return boolean
function M.dry_run(bufnr)
    local operations, err = M.plan(bufnr)

    if not operations then
        vim.notify(
            "scratchwiki: " .. err,
            vim.log.levels.ERROR
        )

        return false
    end

    local lines, summary = format_operations(operations)

    if #lines == 0 then
        vim.notify(
            "scratchwiki: no changes (" .. summary .. ")",
            vim.log.levels.INFO
        )

        return true
    end

    table.insert(lines, 1, "ScratchWiki dry run")
    table.insert(lines, 2, string.rep("-", 40))
    table.insert(lines, "")
    table.insert(lines, "Summary: " .. summary)

    vim.notify(
        table.concat(lines, "\n"),
        vim.log.levels.INFO
    )

    return true
end

M.format_operations = format_operations

---@param bufnr? integer
---@return boolean
function M.execute(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

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

    if not vim.bo[bufnr].modifiable then
        vim.notify(
            "scratchwiki: current buffer is not modifiable",
            vim.log.levels.ERROR
        )

        return false
    end

    local operations, err, scratch_tasks = M.plan(bufnr)

    if not operations then
        vim.notify(
            "scratchwiki: " .. err,
            vim.log.levels.ERROR
        )

        return false
    end

    local ok, execute_err, applied = execute_operations(
        operations,
        scratch_tasks
    )

    if not ok then
        vim.notify(
            string.format(
                "scratchwiki: synchronization failed after %d change(s): %s",
                applied,
                execute_err
            ),
            vim.log.levels.ERROR
        )

        -- If anything was changed before the failure, make the Vimwiki
        -- representation reflect the current Scratch state.
        if applied > 0 then
            require("scratchwiki").refresh(bufnr)
        end

        return false
    end

    if applied > 0 then
        local refresh_ok = require("scratchwiki").refresh(bufnr)

        if not refresh_ok then
            vim.notify(
                "scratchwiki: changes applied, but Vimwiki refresh failed",
                vim.log.levels.WARN
            )

            return false
        end
    end

    if applied > 0 then
        vim.notify(
            string.format(
                "scratchwiki: synchronized %d change(s)",
                applied
            ),
            vim.log.levels.INFO
        )
    end

    return true
end

return M
