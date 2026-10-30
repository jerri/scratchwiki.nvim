if vim.g.loaded_scratchwiki then
    return
end

vim.g.loaded_scratchwiki = true

vim.api.nvim_create_user_command(
    "ScratchWikiRefresh",
    function()
        require("scratchwiki").refresh()
    end,
    {
        desc = "Refresh Scratch tasks in the current Vimwiki buffer",
    }
)

vim.api.nvim_create_user_command(
    "ScratchWikiSync",
    function(opts)
        if opts.bang then
            require("scratchwiki.sync").execute()
        else
            require("scratchwiki.sync").dry_run()
        end
    end,
    {
        bang = true,
        desc = "Synchronize Vimwiki tasks with Scratch (! applies changes)",
    }
)

vim.api.nvim_create_user_command(
    "ScratchWikiOpen",
    function()
        local wiki = require("scratchwiki.wiki")
        local scratch = require("scratchwiki.scratch")

        local id = wiki.task_id_at_cursor(0)

        if not id then
            vim.notify(
                "scratchwiki: no Scratch task under cursor",
                vim.log.levels.WARN
            )

            return
        end

        local ok, err = scratch.open(id)

        if not ok then
            vim.notify(
                "scratchwiki: " .. err,
                vim.log.levels.ERROR
            )
        end
    end,
    {
        desc = "Open Scratch issue under cursor",
    }
)
