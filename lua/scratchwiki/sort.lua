local M = {}

local PRIORITY_RANK = {
    low = 1,
    normal = 2,
    high = 3,
    critical = 4,
}

local TYPE_RANK = {
    bug = 1,
    feature = 2,
    refactor = 3,
    task = 4,
}

local STATUS_RANK = {
    open = 1,
    done = 2,
}

local FIELDS = {
    title = true,
    priority = true,
    type = true,
    status = true,
    created = true,
    id = true,
    updated = true,
}

local FIELD_LIST = {
    "title",
    "priority",
    "type",
    "status",
    "created",
    "id",
    "updated",
}

---@class ScratchWikiSortKey
---@field field string
---@field descending boolean

---@param spec string
---@return ScratchWikiSortKey[]?
---@return string?
function M.parse(spec)
    if not spec or vim.trim(spec) == "" then
        return nil, "empty sort specification in scratchwiki start marker"
    end

    local keys = {}

    -- The trailing comma makes the final field visible to the loop and
    -- also lets empty fields such as "priority,,title" be rejected.
    for token in (spec .. ","):gmatch("(.-),") do
        token = vim.trim(token)

        if token == "" then
            return nil, "empty sort field in scratchwiki sort option"
        end

        local descending = false
        local field = token

        if field:sub(1, 1) == "-" then
            descending = true
            field = field:sub(2)
        elseif field:sub(1, 1) == "+" then
            field = field:sub(2)
        end

        field = field:lower()

        if field == "" then
            return nil, string.format(
                "missing sort field in %q; expected a field name after the direction prefix",
                token
            )
        end

        if not FIELDS[field] then
            return nil, string.format(
                'invalid sort field %q in scratchwiki start marker; expected one of: %s',
                field,
                table.concat(FIELD_LIST, ", ")
            )
        end

        table.insert(keys, {
            field = field,
            descending = descending,
        })
    end

    if #keys == 0 then
        return nil, "empty sort specification in scratchwiki start marker"
    end

    return keys
end

---@param left string?
---@param right string?
---@param descending boolean
---@return integer
local function compare_strings(left, right, descending)
    left = left or ""
    right = right or ""

    if left == right then
        return 0
    end

    local result = left < right and -1 or 1

    if descending then
        return -result
    end

    return result
end

---@param left string?
---@param right string?
---@param descending boolean
---@return integer
local function compare_titles(left, right, descending)
    left = left or ""
    right = right or ""

    local left_lower = left:lower()
    local right_lower = right:lower()

    if left_lower == right_lower then
        return compare_strings(left, right, descending)
    end

    local result = left_lower < right_lower and -1 or 1

    if descending then
        return -result
    end

    return result
end

--- Compare ranked values. Values missing from the rank table sort last in
--- both directions, so an unknown priority never jumps to the top.
---@param left string?
---@param right string?
---@param ranks table<string, integer>
---@param descending boolean
---@return integer
local function compare_ranked(left, right, ranks, descending)
    local left_rank = left and ranks[left]
    local right_rank = right and ranks[right]

    if left_rank == nil or right_rank == nil then
        if left_rank == nil and right_rank == nil then
            return 0
        end

        return left_rank == nil and 1 or -1
    end

    if left_rank == right_rank then
        return 0
    end

    local result = left_rank < right_rank and -1 or 1

    if descending then
        return -result
    end

    return result
end

---@param left integer?
---@param right integer?
---@param descending boolean
---@return integer
local function compare_timestamps(left, right, descending)
    left = left or 0
    right = right or 0

    if left == right then
        return 0
    end

    -- A missing or zero modification time sorts last.
    if left == 0 or right == 0 then
        if left == 0 and right == 0 then
            return 0
        end

        return left == 0 and 1 or -1
    end

    local result = left < right and -1 or 1

    if descending then
        return -result
    end

    return result
end

---@param left ScratchWikiTask
---@param right ScratchWikiTask
---@param key ScratchWikiSortKey
---@return integer
local function compare_field(left, right, key)
    local field = key.field

    if field == "title" then
        return compare_titles(left.title, right.title, key.descending)
    elseif field == "priority" then
        return compare_ranked(
            left.priority,
            right.priority,
            PRIORITY_RANK,
            key.descending
        )
    elseif field == "type" then
        return compare_ranked(
            left.type,
            right.type,
            TYPE_RANK,
            key.descending
        )
    elseif field == "status" then
        return compare_ranked(
            left.status,
            right.status,
            STATUS_RANK,
            key.descending
        )
    elseif field == "updated" then
        return compare_timestamps(
            left.updated,
            right.updated,
            key.descending
        )
    end

    return compare_strings(left.id, right.id, key.descending)
end

---@param tasks ScratchWikiTask[]
---@param options table
---@return ScratchWikiTask[]?
---@return string?
function M.apply(tasks, options)
    local spec = options.sort

    if not spec or vim.trim(spec) == "" then
        return tasks
    end

    local keys, err = M.parse(spec)

    if not keys then
        return nil, err
    end

    local decorated = {}

    for index, task in ipairs(tasks) do
        table.insert(decorated, {
            task = task,
            index = index,
        })
    end

    table.sort(decorated, function(left, right)
        for _, key in ipairs(keys) do
            local result = compare_field(left.task, right.task, key)

            if result ~= 0 then
                return result < 0
            end
        end

        -- Keep the order deterministic when the requested fields tie.
        -- Newest Scratch issues first matches scratch.list().
        local left_id = left.task.id or ""
        local right_id = right.task.id or ""

        if left_id ~= right_id then
            return left_id > right_id
        end

        return left.index < right.index
    end)

    local result = {}

    for _, entry in ipairs(decorated) do
        table.insert(result, entry.task)
    end

    return result
end

return M
