local wiki = require("scratchwiki.wiki")

describe("scratchwiki.wiki.build_block", function()
    it("adds blank lines around tasks", function()
        local result = wiki.build_block({
            "- [ ] First",
            "- [x] Second",
        })

        assert.are.same({
            "",
            "- [ ] First",
            "- [x] Second",
            "",
        }, result)
    end)

    it("uses one blank line for an empty block", function()
        assert.are.same(
            { "" },
            wiki.build_block({})
        )
    end)
end)

describe("scratchwiki.wiki.replace_block", function()
    local bufnr

    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "# Test",
            "",
            "<!-- scratchwiki:start -->",
            "",
            "- [ ] Old task",
            "",
            "<!-- scratchwiki:end -->",
            "",
            "## Notes",
            "",
            "Unrelated unsaved content",
        })

        -- Treat the initial fixture as saved.
        vim.bo[bufnr].modified = false
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)

    it("replaces only the managed block", function()
        local ok, result = wiki.replace_block(bufnr, {
            "- [ ] New task",
        })

        assert.is_true(ok)
        assert.is_true(result.changed)

        assert.are.same({
            "# Test",
            "",
            "<!-- scratchwiki:start -->",
            "",
            "- [ ] New task",
            "",
            "<!-- scratchwiki:end -->",
            "",
            "## Notes",
            "",
            "Unrelated unsaved content",
        }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)

    it("reports an unchanged canonical block", function()
        local ok, result = wiki.replace_block(bufnr, {
            "- [ ] Old task",
        })

        assert.is_true(ok)
        assert.is_false(result.changed)
        assert.are.equal(0, result.line_delta)
    end)

    it("reports a changed block", function()
        local ok, result = wiki.replace_block(bufnr, {
            "- [ ] New task",
        })

        assert.is_true(ok)
        assert.is_true(result.changed)
    end)

    it("preserves unrelated unsaved content", function()
        vim.api.nvim_buf_set_lines(
            bufnr,
            10,
            11,
            false,
            { "Changed but not saved" }
        )

        local ok = wiki.replace_block(bufnr, {
            "- [ ] New task",
            "- [ ] Another task",
        })

        assert.is_true(ok)

        local lines = vim.api.nvim_buf_get_lines(
            bufnr,
            0,
            -1,
            false
        )

        assert.are.same(
            "Changed but not saved",
            lines[#lines]
        )
    end)

    it("adjusts a cursor below the managed block", function()
        local ok, result = wiki.replace_block(
            bufnr,
            {
                "- [ ] First",
                "- [ ] Second",
                "- [ ] Third",
            },
            11
        )

        assert.is_true(ok)
        assert.are.equal(2, result.line_delta)
        assert.are.equal(13, result.cursor_line)
    end)

    it("does not adjust a cursor above the block", function()
        local ok, result = wiki.replace_block(
            bufnr,
            {
                "- [ ] First",
                "- [ ] Second",
            },
            1
        )

        assert.is_true(ok)
        assert.are.equal(1, result.cursor_line)
    end)

    it("rejects duplicate start markers", function()
        vim.api.nvim_buf_set_lines(bufnr, 3, 3, false, {
            "<!-- scratchwiki:start -->",
        })

        local ok, err = wiki.replace_block(bufnr, {})

        assert.is_false(ok)
        assert.matches("multiple scratchwiki start markers", err)
    end)
end)

describe("scratchwiki.wiki.parse_start_marker", function()
    it("parses a marker without options", function()
        assert.are.same(
            {},
            wiki.parse_start_marker(
                "<!-- scratchwiki:start -->"
            )
        )
    end)

    it("parses a status filter", function()
        assert.are.same(
            {
                status = "open",
            },
            wiki.parse_start_marker(
                "<!-- scratchwiki:start status=open -->"
            )
        )
    end)

    it("parses multiple options", function()
        assert.are.same(
            {
                status = "open",
                priority = "high",
                tags = "architecture",
            },
            wiki.parse_start_marker(
                "<!-- scratchwiki:start status=open priority=high tags=architecture -->"
            )
        )
    end)

    it("parses tag filters and sort order", function()
        assert.are.same(
            {
                status = "open",
                tags = "architecture,backend",
                tag_mode = "all",
                sort = "-priority,title",
            },
            wiki.parse_start_marker(
                "<!-- scratchwiki:start status=open tags=architecture,backend tag_mode=all sort=-priority,title -->"
            )
        )
    end)

    it("ignores unrelated markdown comments", function()
        assert.is_nil(
            wiki.parse_start_marker(
                "<!-- something else -->"
            )
        )
    end)
end)
