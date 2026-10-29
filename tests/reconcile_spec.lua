local reconcile = require("scratchwiki.reconcile")

local function scratch_task(id, title, status)
    return {
        id = id,
        title = title,
        status = status,
        type = "task",
        priority = "normal",
        tags = {},
        path = "/tmp/" .. id .. ".md",
    }
end

local function wiki_task(id, title, status, line)
    return {
        id = id,
        title = title,
        status = status,
        line = line or 1,
    }
end

describe("scratchwiki.reconcile", function()
    it("recognizes unchanged tasks", function()
        local result = reconcile.reconcile(
            {
                scratch_task("123", "Foo", "open"),
            },
            {
                wiki_task("123", "Foo", "open"),
            }
        )

        assert.are.same({
            {
                action = "unchanged",
                id = "123",
                line = 1,
            },
        }, result)
    end)

    it("creates a status patch when a task is closed", function()
        local result = reconcile.reconcile(
            {
                scratch_task("123", "Foo", "open"),
            },
            {
                wiki_task("123", "Foo", "done"),
            }
        )

        assert.are.same({
            {
                action = "update",
                id = "123",
                changes = {
                    status = {
                        old = "open",
                        new = "done",
                    },
                },
                line = 1,
            },
        }, result)
    end)

    it("creates a status patch when a task is reopened", function()
        local result = reconcile.reconcile(
            {
                scratch_task("123", "Foo", "done"),
            },
            {
                wiki_task("123", "Foo", "open"),
            }
        )

        assert.are.same({
            {
                action = "update",
                id = "123",
                changes = {
                    status = {
                        old = "done",
                        new = "open",
                    },
                },
                line = 1,
            },
        }, result)
    end)

    it("creates a title patch when a task is renamed", function()
        local result = reconcile.reconcile(
            {
                scratch_task("123", "Old title", "open"),
            },
            {
                wiki_task("123", "New title", "open"),
            }
        )

        assert.are.same({
            {
                action = "update",
                id = "123",
                changes = {
                    title = {
                        old = "Old title",
                        new = "New title",
                    },
                },
                line = 1,
            },
        }, result)
    end)

    it("creates title and status patches simultaneously", function()
        local result = reconcile.reconcile(
            {
                scratch_task("123", "Old title", "open"),
            },
            {
                wiki_task("123", "New title", "done"),
            }
        )

        assert.are.same({
            {
                action = "update",
                id = "123",
                changes = {
                    title = {
                        old = "Old title",
                        new = "New title",
                    },
                    status = {
                        old = "open",
                        new = "done",
                    },
                },
                line = 1,
            },
        }, result)
    end)

    it("recognizes a new Vimwiki task", function()
        local result = reconcile.reconcile(
            {},
            {
                wiki_task(nil, "New task", "open"),
            }
        )

        assert.are.same({
            {
                action = "create",
                title = "New task",
                status = "open",
                line = 1,
            },
        }, result)
    end)

    it("preserves done status when creating a new task", function()
        local result = reconcile.reconcile(
            {},
            {
                wiki_task(nil, "Already done", "done"),
            }
        )

        assert.are.same({
            {
                action = "create",
                title = "Already done",
                status = "done",
                line = 1,
            },
        }, result)
    end)

    it("recognizes an orphaned Vimwiki task", function()
        local result = reconcile.reconcile(
            {},
            {
                wiki_task("missing", "Foo", "open"),
            }
        )

        assert.are.same({
            {
                action = "orphan",
                id = "missing",
                title = "Foo",
                status = "open",
                line = 1,
            },
        }, result)
    end)

    it("does not delete Scratch tasks missing from Vimwiki", function()
        local result = reconcile.reconcile(
            {
                scratch_task("123", "Foo", "open"),
            },
            {}
        )

        assert.are.same({}, result)
    end)

    it("handles multiple operations", function()
        local result = reconcile.reconcile(
            {
                scratch_task("111", "First", "open"),
                scratch_task("222", "Second", "done"),
                scratch_task("333", "Old title", "open"),
                scratch_task("444", "Old fourth", "open"),
                scratch_task("555", "Untouched", "open"),
            },
            {
                wiki_task("111", "First", "done", 2),
                wiki_task("222", "Second", "open", 3),
                wiki_task("333", "New title", "open", 4),
                wiki_task("444", "New fourth", "done", 5),
                wiki_task("555", "Untouched", "open", 6),
                wiki_task(nil, "Brand new", "open", 7),
            }
        )

        assert.are.equal(6, #result)

        -- Status only.
        assert.are.same({
            action = "update",
            id = "111",
            changes = {
                status = {
                    old = "open",
                    new = "done",
                },
            },
            line = 2,
        }, result[1])

        -- Reopen.
        assert.are.same({
            action = "update",
            id = "222",
            changes = {
                status = {
                    old = "done",
                    new = "open",
                },
            },
            line = 3,
        }, result[2])

        -- Rename only.
        assert.are.same({
            action = "update",
            id = "333",
            changes = {
                title = {
                    old = "Old title",
                    new = "New title",
                },
            },
            line = 4,
        }, result[3])

        -- Rename and close simultaneously.
        assert.are.same({
            action = "update",
            id = "444",
            changes = {
                title = {
                    old = "Old fourth",
                    new = "New fourth",
                },
                status = {
                    old = "open",
                    new = "done",
                },
            },
            line = 5,
        }, result[4])

        -- No changes.
        assert.are.same({
            action = "unchanged",
            id = "555",
            line = 6,
        }, result[5])

        -- New task.
        assert.are.same({
            action = "create",
            title = "Brand new",
            status = "open",
            line = 7,
        }, result[6])
    end)
end)
