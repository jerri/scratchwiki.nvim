local filter = require("scratchwiki.filter")

local function task(id, status, tags)
    return {
        id = id,
        title = "Task " .. id,
        status = status,
        tags = tags or {},
    }
end

describe("scratchwiki.filter", function()
    it("returns all tasks without filters", function()
        local tasks = {
            task("1", "open"),
            task("2", "done"),
        }

        assert.are.same(
            tasks,
            filter.apply(tasks, {})
        )
    end)

    it("filters open tasks", function()
        local result = filter.apply({
            task("1", "open"),
            task("2", "done"),
            task("3", "open"),
        }, {
            status = "open",
        })

        assert.are.equal(2, #result)
        assert.are.same("1", result[1].id)
        assert.are.same("3", result[2].id)
    end)

    it("filters completed tasks", function()
        local result = filter.apply({
            task("1", "open"),
            task("2", "done"),
        }, {
            status = "done",
        })

        assert.are.equal(1, #result)
        assert.are.same("2", result[1].id)
    end)

    it("filters tasks by a single tag", function()
        local result = filter.apply({
            task("1", "open", { "architecture" }),
            task("2", "open", { "backend" }),
            task("3", "open"),
        }, {
            tags = "architecture",
        })

        assert.are.equal(1, #result)
        assert.are.same("1", result[1].id)
    end)

    it("requires all listed tags by default", function()
        local result = filter.apply({
            task("1", "open", { "architecture", "backend" }),
            task("2", "open", { "architecture" }),
            task("3", "open", { "backend" }),
        }, {
            tags = "architecture,backend",
        })

        assert.are.equal(1, #result)
        assert.are.same("1", result[1].id)
    end)

    it("supports matching any listed tag", function()
        local result = filter.apply({
            task("1", "open", { "architecture" }),
            task("2", "open", { "backend" }),
            task("3", "open", { "frontend" }),
        }, {
            tags = "architecture,backend",
            tag_mode = "any",
        })

        assert.are.equal(2, #result)
        assert.are.same("1", result[1].id)
        assert.are.same("2", result[2].id)
    end)

    it("matches tags case-sensitively", function()
        local result = filter.apply({
            task("1", "open", { "Architecture" }),
            task("2", "open", { "architecture" }),
        }, {
            tags = "architecture",
        })

        assert.are.equal(1, #result)
        assert.are.same("2", result[1].id)
    end)

    it("combines status and tag filters", function()
        local result = filter.apply({
            task("1", "open", { "architecture" }),
            task("2", "done", { "architecture" }),
            task("3", "open", { "backend" }),
        }, {
            status = "open",
            tags = "architecture",
        })

        assert.are.equal(1, #result)
        assert.are.same("1", result[1].id)
    end)

    it("rejects an invalid tag mode", function()
        local result, err = filter.apply({}, {
            tag_mode = "some",
        })

        assert.is_nil(result)
        assert.matches('invalid tag_mode "some"', err)
    end)
end)
