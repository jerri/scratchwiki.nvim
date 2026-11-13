local sort = require("scratchwiki.sort")

local function task(id, fields)
    return vim.tbl_extend("force", {
        id = id,
        title = "Task " .. id,
        status = "open",
        type = "task",
        priority = "normal",
        tags = {},
        path = "/tmp/" .. id .. ".md",
        updated = 0,
    }, fields or {})
end

local function ids(tasks)
    local result = {}

    for _, entry in ipairs(tasks) do
        table.insert(result, entry.id)
    end

    return result
end

describe("scratchwiki.sort.parse", function()
    it("parses ascending and descending fields", function()
        assert.are.same({
            {
                field = "priority",
                descending = true,
            },
            {
                field = "title",
                descending = false,
            },
        }, sort.parse("-priority,title"))
    end)

    it("accepts an explicit ascending prefix", function()
        assert.are.same({
            {
                field = "title",
                descending = false,
            },
        }, sort.parse("+title"))
    end)

    it("rejects an unknown field", function()
        local result, err = sort.parse("-unknown")

        assert.is_nil(result)
        assert.matches('invalid sort field "unknown"', err)
        assert.matches("title", err)
        assert.matches("priority", err)
    end)

    it("rejects empty fields", function()
        local result, err = sort.parse("priority,,title")

        assert.is_nil(result)
        assert.matches("empty sort field", err)
    end)

    it("rejects a missing field after a direction prefix", function()
        local result, err = sort.parse("-")

        assert.is_nil(result)
        assert.matches("missing sort field", err)
    end)
end)

describe("scratchwiki.sort.apply", function()
    it("keeps the input order without a sort option", function()
        local tasks = {
            task("1"),
            task("2"),
        }

        assert.are.same(tasks, sort.apply(tasks, {}))
    end)

    it("sorts titles case-insensitively", function()
        local tasks = {
            task("1", { title = "banana" }),
            task("2", { title = "Apple" }),
            task("3", { title = "cherry" }),
        }

        assert.are.same(
            { "2", "1", "3" },
            ids(sort.apply(tasks, { sort = "title" }))
        )

        assert.are.same(
            { "3", "1", "2" },
            ids(sort.apply(tasks, { sort = "-title" }))
        )
    end)

    it("sorts by priority in both directions", function()
        local tasks = {
            task("1", { priority = "high" }),
            task("2", { priority = "low" }),
            task("3", { priority = "critical" }),
            task("4", { priority = "normal" }),
        }

        assert.are.same(
            { "2", "4", "1", "3" },
            ids(sort.apply(tasks, { sort = "priority" }))
        )

        assert.are.same(
            { "3", "1", "4", "2" },
            ids(sort.apply(tasks, { sort = "-priority" }))
        )
    end)

    it("sorts by type and status", function()
        local typed = {
            task("1", { type = "task" }),
            task("2", { type = "bug" }),
            task("3", { type = "refactor" }),
            task("4", { type = "feature" }),
        }

        assert.are.same(
            { "2", "4", "3", "1" },
            ids(sort.apply(typed, { sort = "type" }))
        )

        local statuses = {
            task("1", { status = "done" }),
            task("2", { status = "open" }),
        }

        assert.are.same(
            { "2", "1" },
            ids(sort.apply(statuses, { sort = "status" }))
        )
    end)

    it("supports multiple sort keys", function()
        local tasks = {
            task("1", {
                priority = "normal",
                title = "Beta",
            }),
            task("2", {
                priority = "critical",
                title = "Zulu",
            }),
            task("3", {
                priority = "critical",
                title = "Alpha",
            }),
            task("4", {
                priority = "high",
                title = "Gamma",
            }),
        }

        assert.are.same(
            { "3", "2", "4", "1" },
            ids(sort.apply(tasks, {
                sort = "-priority,title",
            }))
        )
    end)

    it("falls back to newest ids when sort values tie", function()
        local tasks = {
            task("111", { title = "Same" }),
            task("222", { title = "Same" }),
            task("333", { title = "Same" }),
        }

        assert.are.same(
            { "333", "222", "111" },
            ids(sort.apply(tasks, { sort = "title" }))
        )
    end)

    it("sorts unknown ranked values last in both directions", function()
        local tasks = {
            task("1", { priority = "urgent" }),
            task("2", { priority = "high" }),
            task("3", { priority = "low" }),
        }

        assert.are.same(
            { "3", "2", "1" },
            ids(sort.apply(tasks, { sort = "priority" }))
        )

        assert.are.same(
            { "2", "3", "1" },
            ids(sort.apply(tasks, { sort = "-priority" }))
        )
    end)

    it("sorts by creation id", function()
        local tasks = {
            task("2026-10-29T12-00-00"),
            task("2026-10-30T12-00-00"),
            task("2026-10-28T12-00-00"),
        }

        assert.are.same(
            {
                "2026-10-28T12-00-00",
                "2026-10-29T12-00-00",
                "2026-10-30T12-00-00",
            },
            ids(sort.apply(tasks, { sort = "created" }))
        )

        assert.are.same(
            {
                "2026-10-30T12-00-00",
                "2026-10-29T12-00-00",
                "2026-10-28T12-00-00",
            },
            ids(sort.apply(tasks, { sort = "-id" }))
        )
    end)

    it("sorts by modification time", function()
        local tasks = {
            task("1", { updated = 100 }),
            task("2", { updated = 300 }),
            task("3", { updated = 200 }),
        }

        assert.are.same(
            { "1", "3", "2" },
            ids(sort.apply(tasks, { sort = "updated" }))
        )

        assert.are.same(
            { "2", "3", "1" },
            ids(sort.apply(tasks, { sort = "-updated" }))
        )
    end)

    it("sorts a missing modification time last", function()
        local tasks = {
            task("1", { updated = 0 }),
            task("2", { updated = 100 }),
        }

        assert.are.same(
            { "2", "1" },
            ids(sort.apply(tasks, { sort = "updated" }))
        )

        assert.are.same(
            { "2", "1" },
            ids(sort.apply(tasks, { sort = "-updated" }))
        )
    end)

    it("does not modify the input table", function()
        local tasks = {
            task("1", { title = "Beta" }),
            task("2", { title = "Alpha" }),
        }

        local before = ids(tasks)

        sort.apply(tasks, { sort = "title" })

        assert.are.same(before, ids(tasks))
    end)

    it("returns a useful error for an invalid sort option", function()
        local result, err = sort.apply({
            task("1"),
        }, {
            sort = "priority,-unknown",
        })

        assert.is_nil(result)
        assert.matches('invalid sort field "unknown"', err)
    end)
end)
