local utils = require 'shifty.utils'

local M = {}

M.default = {
  defaults = {
    expandtab = false,
    shiftwidth = 8,
    softtabstop = 0,
  },
  by_ft = {},
  embedded = {
    enabled = true,
    mappings = {
      -- NOTE: These include `<<` and `>>`
      ['<'] = { 'n', 'x' },
      ['>'] = { 'n', 'x' },

      ['<Tab>'] = 'i',
      ['<C-I>'] = 'i',
      ['<C-T>'] = 'i',
      ['<C-D>'] = 'i',

      ['<BS>'] = 'i',
      ['<C-H>'] = 'i',

      ['<CR>'] = 'i',
      ['o'] = 'n',
      ['O'] = 'n',
    },
    ts_to_ft = {}
  },
}

M.cur = vim.deepcopy(M.default)

M.merge = function(user_config)
  user_config = user_config or {}
  vim.validate { user_config = { user_config, 'table' } }
  user_config.by_ft = user_config.by_ft or {}
  for ft, opts in pairs(user_config.by_ft) do
    if type(opts) == 'number' then
      user_config.by_ft[ft] = { shiftwidth = opts }
    elseif type(opts) == 'table' then
      if opts.expandtab and opts.et then utils.warn_both_specified('expandtab', 'et', ft) end
      if opts.shiftwidth and opts.sw then utils.warn_both_specified('shiftwidth', 'sw', ft) end
      if opts.softtabstop and opts.sts then utils.warn_both_specified('softtabstop', 'sts', ft) end
      user_config.by_ft[ft] = {
        expandtab = opts.expandtab or opts.et or nil,
        shiftwidth = opts.shiftwidth or opts.sw or nil,
        softtabstop = opts.softtabstop or opts.sts or nil,
      }
    else
      utils.warn("Specification for filetype `%s` should be a number or a table, ignoring", ft)
      user_config.by_ft[ft] = nil
    end
  end
  M.cur = vim.tbl_deep_extend('force', M.cur, user_config)
end

return M
