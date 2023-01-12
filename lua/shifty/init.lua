local config = require 'shifty.config'
local utils = require 'shifty.utils'

local M = {}

M.setup = function(user_config)
  config.merge(user_config)

  local shifty_augroup = vim.api.nvim_create_augroup('shifty', { clear = true })
  
  vim.api.nvim_create_autocmd('FileType', {
    group = shifty_augroup,
    callback = function(a)
      local opts = utils.get_ft_opts(a.match)
      for opt, val in pairs(opts) do
        vim.bo[a.buf][opt] = val
      end
    end,
    desc = "Set shifty.nvim options",
  })

  if config.cur.embedded.enabled then
    vim.api.nvim_create_autocmd('FileType', {
      group = shifty_augroup,
      callback = function(a)
        require'shifty.mappings'.attach(a.buf)
      end,
      desc = "Attach shifty.nvim mappings",
    })
  end
end

return M
