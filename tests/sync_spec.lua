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

describe("scratchwiki.sync.execute_operations", function()
    local scratch = require("scratchwiki.scratch")

    local directory

    before_each(function()
        directory = vim.fn.tempname()
        vim.fn.mkdir(directory, "p")
    end)

    after_each(function()
        vim.fn.delete(directory, "rf")
    end)

    it("executes an update operation", function()
        local path = directory .. "/123.md"

        vim.fn.writefile({
            "---",
            "type: task",
            "priority: normal",
            "status: open",
            "tags: ",
            "---",
            "",
            "# Foo",
            "",
            "Body remains untouched.",
        }, path)

        local task = {
            id = "123",
            title = "Foo",
            status = "open",
            type = "task",
            priority = "normal",
            tags = {},
            path = path,
        }

        local ok, err, applied = sync.execute_operations({
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
        }, {
            task,
        })

        assert.is_true(ok)
        assert.is_nil(err)
        assert.are.equal(1, applied)

        local result = vim.fn.readfile(path)

        assert.are.same("status: done", result[4])
        assert.are.same("Body remains untouched.", result[10])
    end)

    it("executes title and status changes together", function()
        local path = directory .. "/123.md"

        vim.fn.writefile({
            "---",
            "type: task",
            "priority: high",
            "status: open",
            "tags: architecture",
            "---",
            "",
            "# Old title",
            "",
            "Important body.",
        }, path)

        local task = {
            id = "123",
            title = "Old title",
            status = "open",
            path = path,
        }

        local ok, err, applied = sync.execute_operations({
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
        }, {
            task,
        })

        assert.is_true(ok)
        assert.is_nil(err)
        assert.are.equal(1, applied)

        local result = vim.fn.readfile(path)

        assert.are.same("status: done", result[4])
        assert.are.same("# New title", result[8])

        -- These must survive untouched.
        assert.are.same("priority: high", result[3])
        assert.are.same("tags: architecture", result[5])
        assert.are.same("Important body.", result[10])
    end)

    it("aborts before writing when an orphan exists", function()
        local path = directory .. "/123.md"

        local original = {
            "---",
            "type: task",
            "priority: normal",
            "status: open",
            "tags: ",
            "---",
            "",
            "# Foo",
        }

        vim.fn.writefile(original, path)

        local task = {
            id = "123",
            title = "Foo",
            status = "open",
            path = path,
        }

        local ok, err, applied = sync.execute_operations({
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
            {
                action = "orphan",
                id = "missing",
                title = "Missing task",
                status = "open",
                line = 2,
            },
        }, {
            task,
        })

        assert.is_false(ok)
        assert.matches("no longer exists", err)
        assert.are.equal(0, applied)

        -- Critically, the preceding update was NOT executed.
        assert.are.same(
            original,
            vim.fn.readfile(path)
        )
    end)

    it("executes a create operation", function()
        local ok, err, applied = sync.execute_operations({
            {
                action = "create",
                title = "Created from Vimwiki",
                status = "open",
                line = 1,
            },
        }, {}, directory)

        assert.is_true(ok)
        assert.is_nil(err)
        assert.are.equal(1, applied)

        local files = vim.fn.globpath(
            directory,
            "*.md",
            false,
            true
        )

        assert.are.equal(1, #files)

        local lines = vim.fn.readfile(files[1])

        assert.are.same("status: open", lines[4])
        assert.are.same(
            "# Created from Vimwiki",
            lines[8]
        )
    end)

    it("creates unique files for multiple new tasks", function()
        local ok, err, applied = sync.execute_operations({
            {
                action = "create",
                title = "First",
                status = "open",
                line = 1,
            },
            {
                action = "create",
                title = "Second",
                status = "open",
                line = 2,
            },
        }, {}, directory)

        assert.is_true(ok)
        assert.is_nil(err)
        assert.are.equal(2, applied)

        local files = vim.fn.globpath(
            directory,
            "*.md",
            false,
            true
        )

        assert.are.equal(2, #files)
    end)
end)
