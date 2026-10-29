local sync = require("scratchwiki.sync")

describe("scratchwiki.sync.format_operations", function()
    it("summarizes unchanged tasks without listing them", function()
        local lines, summary = sync.format_operations({
            {
                action = "unchanged",
                id = "111",
                line = 1,
            },
            {
                action = "unchanged",
                id = "222",
                line = 2,
            },
        })

        assert.are.same({}, lines)

        assert.are.same(
            "0 create, 0 update, 2 unchanged, 0 orphan",
            summary
        )
    end)

    it("formats a status update", function()
        local lines, summary = sync.format_operations({
            {
                action = "update",
                id = "123",
                line = 4,
                changes = {
                    status = {
                        old = "open",
                        new = "done",
                    },
                },
            },
        })

        assert.are.same({
            "UPDATE   line 4: 123 (status: open -> done)",
        }, lines)

        assert.are.same(
            "0 create, 1 update, 0 unchanged, 0 orphan",
            summary
        )
    end)

    it("formats a title update", function()
        local lines = sync.format_operations({
            {
                action = "update",
                id = "123",
                line = 5,
                changes = {
                    title = {
                        old = "Old title",
                        new = "New title",
                    },
                },
            },
        })

        assert.are.same({
            'UPDATE   line 5: 123 (title: "Old title" -> "New title")',
        }, lines)
    end)

    it("formats simultaneous title and status changes", function()
        local lines = sync.format_operations({
            {
                action = "update",
                id = "123",
                line = 6,
                changes = {
                    status = {
                        old = "open",
                        new = "done",
                    },
                    title = {
                        old = "Old title",
                        new = "New title",
                    },
                },
            },
        })

        assert.are.same({
            'UPDATE   line 6: 123 (status: open -> done, title: "Old title" -> "New title")',
        }, lines)
    end)

    it("formats new tasks", function()
        local lines = sync.format_operations({
            {
                action = "create",
                title = "Brand new task",
                status = "open",
                line = 7,
            },
        })

        assert.are.same({
            "CREATE   line 7: Brand new task [open]",
        }, lines)
    end)

    it("formats orphaned tasks", function()
        local lines = sync.format_operations({
            {
                action = "orphan",
                id = "missing",
                title = "Lost task",
                status = "open",
                line = 8,
            },
        })

        assert.are.same({
            "ORPHAN   line 8: missing (Lost task)",
        }, lines)
    end)
end)
