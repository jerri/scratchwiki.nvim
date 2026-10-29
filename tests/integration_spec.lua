local scratchwiki = require("scratchwiki")
local config = require("scratchwiki.config")
local sync = require("scratchwiki.sync")

describe("scratchwiki integration", function()
    local directory
    local bufnr

    before_each(function()
        directory = vim.fn.tempname()
        vim.fn.mkdir(directory, "p")

        config.setup({
            scratch_dir = directory,
        })

        vim.fn.writefile({
            "---",
            "type: task",
            "priority: high",
            "status: open",
            "tags: test",
            "---",
            "",
            "# Integration test task",
            "",
            "This body must survive.",
        }, directory .. "/2026-10-29T12-00-00.md")

        bufnr = vim.api.nvim_create_buf(false, true)

        vim.api.nvim_buf_set_lines(
            bufnr,
            0,
            -1,
            false,
            {
                "# Test Wiki",
                "",
                "Some content before.",
                "",
                "<!-- scratchwiki:start -->",
                "",
                "<!-- scratchwiki:end -->",
                "",
                "Some content after.",
            }
        )
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(
                bufnr,
                { force = true }
            )
        end

        vim.fn.delete(directory, "rf")

        -- Don't leak test configuration.
        config.setup()
    end)

    it("completes a Scratch task from Vimwiki", function()
        --
        -- Scratch -> Vimwiki
        --
        assert.is_true(scratchwiki.refresh(bufnr))

        local lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        local task_line

        for i, line in ipairs(lines) do
            if line:match("Integration test task") then
                task_line = i
                break
            end
        end

        assert.is_not_nil(task_line)

        assert.matches(
            "%- %[ %] Integration test task",
            lines[task_line]
        )

        assert.matches(
            "scratchwiki:id=2026%-10%-29T12%-00%-00",
            lines[task_line]
        )

        --
        -- Simulate the user ticking the checkbox.
        --
        lines[task_line] = lines[task_line]:gsub("%[ %]", "[X]", 1)

        vim.api.nvim_buf_set_lines(
            bufnr,
            task_line - 1,
            task_line,
            false,
            { lines[task_line] }
        )

        --
        -- Verify the plan first.
        --
        local operations, err = sync.plan(bufnr)

        assert.is_nil(err)
        assert.are.equal(1, #operations)

        assert.are.same(
            "update",
            operations[1].action
        )

        assert.are.same({
            old = "open",
            new = "done",
        }, operations[1].changes.status)

        --
        -- Execute.
        --
        assert.is_true(sync.execute(bufnr))

        --
        -- Verify the underlying Scratch file.
        --
        local issue = vim.fn.readfile(
            directory .. "/2026-10-29T12-00-00.md"
        )

        assert.are.same(
            "status: done",
            issue[4]
        )

        -- Body survived.
        assert.are.same(
            "This body must survive.",
            issue[10]
        )

        --
        -- Verify refresh kept the completed checkbox.
        --
        lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        local found = false

        for _, line in ipairs(lines) do
            if line:match("Integration test task") then
                assert.matches("%- %[X%]", line)
                found = true
            end
        end

        assert.is_true(found)
    end)

    it("renames and completes a Scratch task from Vimwiki", function()
        assert.is_true(scratchwiki.refresh(bufnr))

        local lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        local task_line

        for i, line in ipairs(lines) do
            if line:match("Integration test task") then
                task_line = i
                break
            end
        end

        assert.is_not_nil(task_line)

        --
        -- Simulate the user:
        --   * completing the task
        --   * changing its title
        --
        local line = lines[task_line]

        line = line:gsub("%[ %]", "[X]", 1)
        line = line:gsub(
            "Integration test task",
            "Renamed integration task",
            1
        )

        vim.api.nvim_buf_set_lines(
            bufnr,
            task_line - 1,
            task_line,
            false,
            { line }
        )

        --
        -- Check the reconciliation plan.
        --
        local operations, err = sync.plan(bufnr)

        assert.is_nil(err)
        assert.are.equal(1, #operations)

        assert.are.same(
            "update",
            operations[1].action
        )

        assert.are.same({
            old = "open",
            new = "done",
        }, operations[1].changes.status)

        assert.are.same({
            old = "Integration test task",
            new = "Renamed integration task",
        }, operations[1].changes.title)

        --
        -- Execute.
        --
        assert.is_true(sync.execute(bufnr))

        --
        -- Verify the Scratch source.
        --
        local issue = vim.fn.readfile(
            directory .. "/2026-10-29T12-00-00.md"
        )

        assert.are.same("status: done", issue[4])
        assert.are.same("# Renamed integration task", issue[8])

        -- Critical: body content must survive.
        assert.are.same(
            "This body must survive.",
            issue[10]
        )

        --
        -- Verify refreshed Vimwiki representation.
        --
        lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        local found = false

        for _, wiki_line in ipairs(lines) do
            if wiki_line:match("Renamed integration task") then
                assert.matches("%- %[X%]", wiki_line)

                assert.matches(
                    "scratchwiki:id=2026%-10%-29T12%-00%-00",
                    wiki_line
                )

                found = true
            end
        end

        assert.is_true(found)
    end)

    it("creates a new Scratch task from Vimwiki", function()
        assert.is_true(scratchwiki.refresh(bufnr))

        --
        -- Locate the managed block in the real buffer.
        --
        local lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        local end_line

        for i, line in ipairs(lines) do
            if vim.trim(line) == "<!-- scratchwiki:end -->" then
                end_line = i
                break
            end
        end

        assert.is_not_nil(end_line)

        --
        -- Insert a new Vimwiki task before the blank line preceding
        -- the end marker.
        --
        vim.api.nvim_buf_set_lines(
            bufnr,
            end_line - 2,
            end_line - 2,
            false,
            {
                "- [ ] Created from Vimwiki",
            }
        )

        --
        -- Verify that parsing/reconciliation sees a creation.
        --
        local operations, err = sync.plan(bufnr)

        assert.is_nil(err)

        local create_operation

        for _, operation in ipairs(operations) do
            if operation.action == "create" then
                create_operation = operation
                break
            end
        end

        assert.is_not_nil(create_operation)
        assert.are.same(
            "Created from Vimwiki",
            create_operation.title
        )
        assert.are.same(
            "open",
            create_operation.status
        )

        --
        -- The Scratch directory initially contains one issue.
        --
        local files_before = vim.fn.globpath(
            directory,
            "*.md",
            false,
            true
        )

        assert.are.equal(1, #files_before)

        --
        -- Execute.
        --
        assert.is_true(sync.execute(bufnr))

        --
        -- We should now have exactly two Scratch issues.
        --
        local files_after = vim.fn.globpath(
            directory,
            "*.md",
            false,
            true
        )

        assert.are.equal(2, #files_after)

        --
        -- Find the newly-created issue.
        --
        local created_file

        for _, path in ipairs(files_after) do
            if not path:match("2026%-10%-29T12%-00%-00%.md$") then
                created_file = path
                break
            end
        end

        assert.is_not_nil(created_file)

        local issue = vim.fn.readfile(created_file)

        assert.are.same("type: task", issue[2])
        assert.are.same("priority: normal", issue[3])
        assert.are.same("status: open", issue[4])
        assert.are.same("# Created from Vimwiki", issue[8])

        --
        -- The refreshed Vimwiki task should now have the ID of
        -- the newly-created Scratch issue.
        --
        local created_id = vim.fn.fnamemodify(
            created_file,
            ":t:r"
        )

        lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        local found = false

        for _, wiki_line in ipairs(lines) do
            if wiki_line:match("Created from Vimwiki") then
                assert.matches("%- %[ %]", wiki_line)

                assert.is_not_nil(
                    wiki_line:find(
                        "scratchwiki:id=" .. created_id,
                        1,
                        true
                    )
                )

                found = true
            end
        end

        assert.is_true(found)
    end)
end)
