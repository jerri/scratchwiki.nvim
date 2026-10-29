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
