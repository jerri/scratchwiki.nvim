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
        lines[task_line] = lines[task_line]:gsub("%[ %]", "[x]", 1)

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
                assert.matches("%- %[x%]", line)
                found = true
            end
        end

        assert.is_true(found)
    end)
end)
