local scratch = require("scratchwiki.scratch")

local function issue_lines()
    return {
        "---",
        "type: task",
        "priority: high",
        "status: open",
        "tags: sharepoint",
        "---",
        "",
        "# Test the Application provided for Sharepoint",
        "",
        "The application body must remain unchanged.",
        "",
        "## Infos",
        "",
        "Working in `~/Projects/architecture_guardrails_sync/`.",
    }
end

describe("scratchwiki.scratch.apply_changes", function()
    it("updates the status", function()
        local result, err = scratch.apply_changes(issue_lines(), {
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_nil(err)

        assert.are.same({
            "---",
            "type: task",
            "priority: high",
            "status: done",
            "tags: sharepoint",
            "---",
            "",
            "# Test the Application provided for Sharepoint",
            "",
            "The application body must remain unchanged.",
            "",
            "## Infos",
            "",
            "Working in `~/Projects/architecture_guardrails_sync/`.",
        }, result)
    end)

    it("updates the title", function()
        local result, err = scratch.apply_changes(issue_lines(), {
            title = {
                old = "Test the Application provided for Sharepoint",
                new = "Test the SharePoint application",
            },
        })

        assert.is_nil(err)
        assert.are.same("# Test the SharePoint application", result[8])
    end)

    it("updates title and status simultaneously", function()
        local result, err = scratch.apply_changes(issue_lines(), {
            title = {
                old = "Test the Application provided for Sharepoint",
                new = "Test the SharePoint application",
            },
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_nil(err)
        assert.are.same("status: done", result[4])
        assert.are.same("# Test the SharePoint application", result[8])
    end)

    it("preserves all unrelated content", function()
        local source = issue_lines()

        local result, err = scratch.apply_changes(source, {
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_nil(err)

        for index, line in ipairs(source) do
            if index ~= 4 then
                assert.are.same(line, result[index])
            end
        end
    end)

    it("does not modify the input table", function()
        local source = issue_lines()

        local _, err = scratch.apply_changes(source, {
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_nil(err)
        assert.are.same("status: open", source[4])
    end)

    it("rejects a status conflict", function()
        local result, err = scratch.apply_changes(issue_lines(), {
            status = {
                old = "done",
                new = "open",
            },
        })

        assert.is_nil(result)
        assert.matches("status conflict", err)
        assert.matches('expected "done"', err)
        assert.matches('found "open"', err)
    end)

    it("rejects a title conflict", function()
        local result, err = scratch.apply_changes(issue_lines(), {
            title = {
                old = "A different title",
                new = "New title",
            },
        })

        assert.is_nil(result)
        assert.matches("title conflict", err)
    end)

    it("fails when status is missing", function()
        local lines = issue_lines()
        table.remove(lines, 4)

        local result, err = scratch.apply_changes(lines, {
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_nil(result)
        assert.are.same(
            "status field not found in Scratch frontmatter",
            err
        )
    end)

    it("fails when the task title is missing", function()
        local lines = issue_lines()
        lines[8] = "This is not a title"

        local result, err = scratch.apply_changes(lines, {
            title = {
                old = "Test the Application provided for Sharepoint",
                new = "New title",
            },
        })

        assert.is_nil(result)
        assert.are.same("task title not found", err)
    end)

    it("does not mistake body headings for the task title", function()
        local lines = issue_lines()

        local result, err = scratch.apply_changes(lines, {
            title = {
                old = "Test the Application provided for Sharepoint",
                new = "New title",
            },
        })

        assert.is_nil(err)
        assert.are.same("# New title", result[8])
        assert.are.same("## Infos", result[12])
    end)

    it("does nothing when changes are empty", function()
        local source = issue_lines()
        local result, err = scratch.apply_changes(source, {})

        assert.is_nil(err)
        assert.are.same(source, result)
        assert.is_not.equal(source, result)
    end)
end)

describe("scratchwiki.scratch.update", function()
    local directory
    local path

    before_each(function()
        directory = vim.fn.tempname()
        vim.fn.mkdir(directory, "p")

        path = directory .. "/2026-09-29T09-43-54.md"

        vim.fn.writefile(issue_lines(), path)
    end)

    after_each(function()
        vim.fn.delete(directory, "rf")
    end)

    it("updates an issue file", function()
        local task = {
            id = "2026-09-29T09-43-54",
            title = "Test the Application provided for Sharepoint",
            status = "open",
            path = path,
        }

        local ok, err = scratch.update(task, {
            title = {
                old = "Test the Application provided for Sharepoint",
                new = "Test the SharePoint application",
            },
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_true(ok)
        assert.is_nil(err)

        local result = vim.fn.readfile(path)

        assert.are.same("status: done", result[4])
        assert.are.same("# Test the SharePoint application", result[8])
        assert.are.same("## Infos", result[12])
    end)

    it("leaves the file unchanged on conflict", function()
        local before = vim.fn.readfile(path)

        local ok, err = scratch.update({
            id = "2026-09-29T09-43-54",
            path = path,
        }, {
            status = {
                old = "done",
                new = "open",
            },
        })

        assert.is_false(ok)
        assert.matches("status conflict", err)
        assert.are.same(before, vim.fn.readfile(path))
    end)

    it("does not leave temporary files behind", function()
        local ok, err = scratch.update({
            id = "2026-09-29T09-43-54",
            path = path,
        }, {
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_true(ok)
        assert.is_nil(err)

        assert.are.equal(
            0,
            vim.fn.filereadable(path .. ".scratchwiki.tmp")
        )

        assert.are.equal(
            0,
            vim.fn.filereadable(path .. ".scratchwiki.bak")
        )
    end)

    it("returns an error for a missing issue file", function()
        local missing = directory .. "/missing.md"

        local ok, err = scratch.update({
            id = "missing",
            path = missing,
        }, {
            status = {
                old = "open",
                new = "done",
            },
        })

        assert.is_false(ok)
        assert.matches("does not exist", err)
    end)
end)
