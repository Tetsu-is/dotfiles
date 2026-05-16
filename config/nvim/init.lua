-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
-- vim.api.nvim_set_hl(0, "@keyword.import.python", { link = "Keyword" })
-- vim.api.nvim_set_hl(0, "@module.python", { link = "Identifier" })
vim.opt.clipboard = "unnamedplus"
vim.diagnostic.config({
  underline = {
    priority = 105, -- 常に最前面に表示させる
  },
})
local lspconfig = require("lspconfig")
lspconfig.kotlin_language_server.setup({})
