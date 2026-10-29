vim.opt.runtimepath:append(vim.fn.getcwd())

local data = vim.fn.stdpath("data")

vim.opt.runtimepath:append(data .. "/lazy/plenary.nvim")
vim.opt.runtimepath:append(vim.fn.getcwd())

vim.cmd("runtime plugin/plenary.vim")
