local filter = require("scratchwiki.filter")

local function task(id, status)
    return {
        id = id,
        title = "Task " .. id,
        status = status,
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
end)
