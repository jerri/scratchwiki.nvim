local validate = require("scratchwiki.validate")

local function wiki_task(id, title, line)
    return {
        id = id,
        title = title or "Task",
        status = "open",
        line = line or 1,
    }
end

local function scratch_task(id)
    return {
        id = id,
        title = "Task",
        status = "open",
        type = "task",
        priority = "normal",
        tags = {},
        path = "/tmp/" .. id .. ".md",
    }
end

describe("scratchwiki.validate", function()
    it("accepts valid state", function()
        local ok, err = validate.validate(
            {
                wiki_task("111", "First", 1),
                wiki_task("222", "Second", 2),
            },
            {
                scratch_task("111"),
                scratch_task("222"),
            }
        )

        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("accepts new tasks without ids", function()
        local ok, err = validate.validate(
            {
                wiki_task(nil, "First new task", 1),
                wiki_task(nil, "Second new task", 2),
            },
            {}
        )

        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("rejects duplicate wiki ids", function()
        local ok, err = validate.validate(
            {
                wiki_task("123", "First", 3),
                wiki_task("123", "Second", 7),
            },
            {
                scratch_task("123"),
            }
        )

        assert.is_false(ok)

        assert.are.same(
            'duplicate ScratchWiki id "123" on lines 3 and 7',
            err
        )
    end)

    it("rejects duplicate scratch ids", function()
        local ok, err = validate.validate(
            {},
            {
                scratch_task("123"),
                scratch_task("123"),
            }
        )

        assert.is_false(ok)

        assert.are.same(
            'duplicate Scratch id "123"',
            err
        )
    end)

    it("accepts an empty state", function()
        local ok, err = validate.validate({}, {})

        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("accepts orphan ids", function()
        local ok, err = validate.validate(
            {
                wiki_task("missing", "Orphan", 4),
            },
            {}
        )

        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("rejects invalid wiki status", function()
        local task = wiki_task("123", "Foo", 1)
        task.status = "maybe"

        local ok, err = validate.validate({ task }, {})

        assert.is_false(ok)
        assert.matches("invalid Vimwiki status", err)
    end)

    it("rejects invalid scratch status", function()
        local task = scratch_task("123")
        task.status = "unknown"

        local ok, err = validate.validate({}, { task })

        assert.is_false(ok)
        assert.matches("invalid Scratch status", err)
    end)
end)
