local markdown = require("scratchwiki.markdown")

describe("scratchwiki.markdown.parse", function()
    it("parses an open task with id", function()
        local tasks = markdown.parse({
            "- [ ] First task <!-- scratchwiki:id=2026-10-29T08-12-40 -->",
        })

        assert.are.same({
            {
                id = "2026-10-29T08-12-40",
                title = "First task",
                status = "open",
                line = 1,
            },
        }, tasks)
    end)

    it("parses a completed task", function()
        local tasks = markdown.parse({
            "- [x] Completed task <!-- scratchwiki:id=123 -->",
        })

        assert.are.same({
            {
                id = "123",
                title = "Completed task",
                status = "done",
                line = 1,
            },
        }, tasks)
    end)

    it("accepts uppercase X", function()
        local tasks = markdown.parse({
            "- [X] Completed task <!-- scratchwiki:id=123 -->",
        })

        assert.are.same("done", tasks[1].status)
    end)

    it("parses a new task without an id", function()
        local tasks = markdown.parse({
            "- [ ] Brand new task",
        })

        assert.are.same({
            {
                title = "Brand new task",
                status = "open",
                line = 1,
            },
        }, tasks)

        assert.is_nil(tasks[1].id)
    end)

    it("parses multiple tasks", function()
        local tasks = markdown.parse({
            "- [ ] First <!-- scratchwiki:id=111 -->",
            "- [x] Second <!-- scratchwiki:id=222 -->",
            "- [ ] Third",
        })

        assert.are.equal(3, #tasks)

        assert.are.same("111", tasks[1].id)
        assert.are.same("open", tasks[1].status)
        assert.are.same("First", tasks[1].title)

        assert.are.same("222", tasks[2].id)
        assert.are.same("done", tasks[2].status)
        assert.are.same("Second", tasks[2].title)

        assert.is_nil(tasks[3].id)
        assert.are.same("open", tasks[3].status)
        assert.are.same("Third", tasks[3].title)
    end)

    it("ignores blank lines", function()
        local tasks = markdown.parse({
            "",
            "- [ ] Task <!-- scratchwiki:id=123 -->",
            "",
        })

        assert.are.equal(1, #tasks)
        assert.are.same(2, tasks[1].line)
    end)

    it("ignores normal markdown text", function()
        local tasks = markdown.parse({
            "# Heading",
            "",
            "Some text.",
            "",
            "- normal list item",
            "",
            "- [ ] Actual task <!-- scratchwiki:id=123 -->",
        })

        assert.are.equal(1, #tasks)
        assert.are.same("Actual task", tasks[1].title)
        assert.are.same(7, tasks[1].line)
    end)

    it("ignores malformed checkboxes", function()
        local tasks = markdown.parse({
            "- [] Missing space",
            "- [  ] Too many spaces",
            "- [y] Unknown checkbox",
            "-[ ] Missing space after dash",
            "- [ ]",
        })

        assert.are.equal(0, #tasks)
    end)

    it("allows leading whitespace", function()
        local tasks = markdown.parse({
            "    - [ ] Indented task <!-- scratchwiki:id=123 -->",
        })

        assert.are.equal(1, #tasks)
        assert.are.same("Indented task", tasks[1].title)
    end)

    it("trims whitespace from the title", function()
        local tasks = markdown.parse({
            "- [ ]    Task with whitespace    <!-- scratchwiki:id=123 -->",
        })

        assert.are.equal(1, #tasks)
        assert.are.same("Task with whitespace", tasks[1].title)
    end)

    it("preserves markdown in the title", function()
        local tasks = markdown.parse({
            "- [ ] Test `foo()` and **bar** <!-- scratchwiki:id=123 -->",
        })

        assert.are.same(
            "Test `foo()` and **bar**",
            tasks[1].title
        )
    end)

    it("preserves unicode in the title", function()
        local tasks = markdown.parse({
            "- [ ] Prüfe Änderungen für München <!-- scratchwiki:id=123 -->",
        })

        assert.are.same(
            "Prüfe Änderungen für München",
            tasks[1].title
        )
    end)

    it("returns an empty table when there are no tasks", function()
        local tasks = markdown.parse({
            "# Nothing here",
            "",
            "Just some text.",
        })

        assert.are.same({}, tasks)
    end)
end)

describe("scratchwiki markdown round trip", function()
    it("parses tasks rendered by scratchwiki", function()
        local source = {
            {
                id = "2026-09-29T09-43-54",
                title = "Test the Application provided for Sharepoint",
                status = "done",
                type = "task",
                priority = "high",
                tags = { "sharepoint" },
                path = "/tmp/2026-09-29T09-43-54.md",
            },
            {
                id = "2026-10-29T08-12-40",
                title = "Review architecture guardrails",
                status = "open",
                type = "task",
                priority = "normal",
                tags = {},
                path = "/tmp/2026-10-29T08-12-40.md",
            },
        }

        local rendered = markdown.render(source)
        local parsed = markdown.parse(rendered)

        assert.are.same({
            {
                id = "2026-09-29T09-43-54",
                title = "Test the Application provided for Sharepoint",
                status = "done",
                line = 1,
            },
            {
                id = "2026-10-29T08-12-40",
                title = "Review architecture guardrails",
                status = "open",
                line = 2,
            },
        }, parsed)
    end)

    it("only recognizes scratchwiki id at the end of the line", function()
        local tasks = markdown.parse({
            "- [ ] Foo <!-- scratchwiki:id=123 --> trailing",
        })

        assert.are.equal(1, #tasks)
        assert.is_nil(tasks[1].id)

        assert.are.same(
            "Foo <!-- scratchwiki:id=123 --> trailing",
            tasks[1].title
        )
    end)
end)

describe("scratchwiki.markdown.render", function()
    it("renders completed tasks with Vimwiki uppercase X", function()
        local lines = markdown.render({
            {
                id = "123",
                title = "Completed task",
                status = "done",
            },
        })

        assert.are.same({
            "- [x] Completed task <!-- scratchwiki:id=123 -->",
        }, lines)
    end)
end)
