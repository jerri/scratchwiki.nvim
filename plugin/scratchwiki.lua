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
    function()
        require("scratchwiki.sync").dry_run()
    end,
    {
        desc = "Show planned ScratchWiki synchronization changes",
    }
)
