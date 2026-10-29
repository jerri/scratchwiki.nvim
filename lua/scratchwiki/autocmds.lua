local M = {}

local function is_scratchwiki_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    if vim.bo[bufnr].filetype ~= "vimwiki" then
        return false
    end

    return require("scratchwiki.wiki").has_block(bufnr)
end

function M.setup()
    local config = require("scratchwiki.config").options

    local group = vim.api.nvim_create_augroup(
        "ScratchWiki",
        { clear = true }
    )

    if config.sync.on_open then
        vim.api.nvim_create_autocmd("FileType", {
            group = group,
            pattern = "vimwiki",

            callback = function(args)
                if not is_scratchwiki_buffer(args.buf) then
                    return
                end

                require("scratchwiki").refresh(args.buf)
            end,

            desc = "Refresh ScratchWiki tasks",
        })
    end

    if config.sync.on_save then
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = group,
            pattern = "*",

            callback = function(args)
                if not is_scratchwiki_buffer(args.buf) then
                    return
                end

                local ok = require("scratchwiki.sync").execute(
                    args.buf
                )

                if not ok then
                    error(
                        "ScratchWiki synchronization failed; write aborted"
                    )
                end
            end,

            desc = "Synchronize Vimwiki tasks with Scratch",
        })
    end
end

return M
