local M = {}

function M.render(tasks)
    local lines = {}

    for _, task in ipairs(tasks) do
        local checkbox = task.status == "done" and "x" or " "

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

return M
