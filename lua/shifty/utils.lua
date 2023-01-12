local M = {}

M.get_opts = function()
  local config = require 'shifty.config'

  local merged_opts = M.get_ft_opts()

  local ok, parser = pcall(vim.treesitter.get_parser)
  if ok then
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
    local maxcol = vim.api.nvim_get_current_line():len()
    local lang = parser:language_for_range({ line, 0, line, maxcol }):lang() or {}
    lang = config.cur.embedded.ts_to_ft[lang] or lang
    merged_opts = vim.tbl_extend(
      'force',
      merged_opts,
      config.cur.by_ft[lang] or {}
    )
  end

  return {
    expandtab = merged_opts.expandtab or nil,
    shiftwidth = merged_opts.shiftwidth or nil,
    softtabstop = merged_opts.softtabstop or nil,
  }
end

M.get_ft_opts = function(ft)
  local config = require 'shifty.config'

  ft = ft or vim.bo.filetype
  local merged_opts = vim.tbl_extend('force', config.cur.defaults, config.cur.by_ft[ft] or {})
  return {
    expandtab = merged_opts.expandtab or nil,
    shiftwidth = merged_opts.shiftwidth or nil,
    softtabstop = merged_opts.softtabstop or nil,
  }
end

M.is_in_op_pend = function()
  local mode = vim.api.nvim_get_mode().mode
  return mode:sub(1, 2) == 'no'
end

M.warn = function(msg, ...)
  vim.notify(msg:format(...), vim.log.levels.WARN, { title = 'shifty.nvim' })
end

M.warn_both_specified = function(long, short, ft)
  M.warn("Both `%s` and `%s` specified for filetype `%s`, ignoring `%s`", long, short, ft, short)
end

return M
