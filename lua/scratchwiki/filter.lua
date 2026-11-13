local M = {}

local VALID_TAG_MODES = {
    all = true,
    any = true,
}

---@param value string?
---@return string[]
local function parse_tags(value)
    local tags = {}

    if not value then
        return tags
    end

    for tag in value:gmatch("[^,]+") do
        tag = vim.trim(tag)

        if tag ~= "" then
            table.insert(tags, tag)
        end
    end

    return tags
end

---@param task ScratchWikiTask
---@param tag string
---@return boolean
local function has_tag(task, tag)
    for _, candidate in ipairs(task.tags or {}) do
        if candidate == tag then
            return true
        end
    end

    return false
end

---@param task ScratchWikiTask
---@param tags string[]
---@param mode "all"|"any"
---@return boolean
local function matches_tags(task, tags, mode)
    if #tags == 0 then
        return true
    end

    for _, tag in ipairs(tags) do
        local found = has_tag(task, tag)

        if mode == "any" and found then
            return true
        elseif mode == "all" and not found then
            return false
        end
    end

    return mode == "all"
end

---@param task ScratchWikiTask
---@param options table
---@return boolean
function M.matches(task, options)
    if options.status then
        if task.status ~= options.status then
            return false
        end
    end

    local tags = parse_tags(options.tags)
    local mode = options.tag_mode or "all"

    return matches_tags(task, tags, mode)
end

---@param tasks ScratchWikiTask[]
---@param options table
---@return ScratchWikiTask[]?
---@return string?
function M.apply(tasks, options)
    local mode = options.tag_mode

    if mode ~= nil and not VALID_TAG_MODES[mode] then
        return nil, string.format(
            'invalid tag_mode %q in scratchwiki start marker; expected "all" or "any"',
            tostring(mode)
        )
    end

    local result = {}

    for _, task in ipairs(tasks) do
        if M.matches(task, options) then
            table.insert(result, task)
        end
    end

    return result
end

M.parse_tags = parse_tags

return M
