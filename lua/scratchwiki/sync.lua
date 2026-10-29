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

    local operations = reconcile.reconcile(
        scratch_tasks,
        wiki_tasks
    )

    return operations
end

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

return M
