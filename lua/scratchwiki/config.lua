local M = {}

M.defaults = {
    scratch_dir = vim.fn.stdpath("data")
        .. "/scratch.nvim/issues",

    sync = {
        on_open = true,
        on_save = true,
    }
}

M.options = vim.deepcopy(M.defaults)

---@param opts? table
function M.setup(opts)
    M.options = vim.tbl_deep_extend(
        "force",
        vim.deepcopy(M.defaults),
        opts or {}
    )
end

return M
