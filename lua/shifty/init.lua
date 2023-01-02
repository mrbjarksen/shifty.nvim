local M = {}

local config = {
  defaults = {
    expandtab = false,
    shiftwidth = 8,
    softtabstop = 0,
  },
  by_ft = {},
  embedded = {
    enabled = true,
    mappings = {
      ['<<'] = 'n',
      ['>>'] = 'n',
      ['<Tab>'] = 'i',
      ['<C-I>'] = 'i',
      ['<C-T>'] = 'i',
      ['<C-D>'] = 'i',
    },
    ts_to_ft = {}
  },
}

local with_opts = function(opts, func)
  local optionset_is_ignored = vim.tbl_contains(vim.opt.eventignore:get(), 'OptionSet')

  -- Set desired options (without triggering OptionSet)
  if not optionset_is_ignored then
    vim.opt.eventignore:append('OptionSet')
  end
  local opts_restore = {}
  for opt, val in pairs(opts) do
    opts_restore[opt] = vim.opt[opt]
    vim.opt[opt] = val
  end
  if not optionset_is_ignored then
    vim.opt.eventignore:remove('OptionSet')
  end

  func()

  -- Reset options to previous values (without triggering OptionSet).
  -- This needs to be scheduled, possibly due to textlock
  vim.schedule(function()
    if not optionset_is_ignored then
      vim.opt.eventignore:append('OptionSet')
    end
    for opt, val in pairs(opts_restore) do
      vim.opt[opt] = val
    end
    if not optionset_is_ignored then
      vim.opt.eventignore:remove('OptionSet')
    end
  end)
end

local feedkeys = function(keys)
  keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(keys, 'n', false)
end

local make_callback = function(rhs, is_expr)
  local callback
  if type(rhs) == 'function' then
    if not is_expr then
      callback = function() return rhs end
    else
      callback = function() feedkeys(rhs()) end
    end
  elseif type(rhs) == 'string' then
    if not is_expr then
      callback = function()
        local count = ''
        if vim.v.count == vim.v.count1 then
          count = vim.v.count
        end
        feedkeys(count .. rhs)
      end
    else
      callback = function() feedkeys(vim.api.nvim_eval(rhs)) end
    end
  end

  return function()
    with_opts(M.get_opts(), callback)
  end
end

M.get_opts = function(use_ts)
  local merged_opts = M.get_ft_opts(vim.bo.filetype)

  if use_ts ~= false then
    local ok, parser = pcall(vim.treesitter.get_parser)
    if ok then
      local line = vim.api.nvim_win_get_cursor(0)[1] - 1
      local maxcol = vim.api.nvim_get_current_line():len()
      local lang = parser:language_for_range({ line, 0, line, maxcol }):lang() or {}
      lang = config.embedded.ts_to_ft[lang] or lang
      merged_opts = vim.tbl_extend(
        'force',
        merged_opts,
        config.by_ft[lang] or {}
      )
    end
  end

  return {
    expandtab = merged_opts.expandtab or nil,
    shiftwidth = merged_opts.shiftwidth or nil,
    softtabstop = merged_opts.softtabstop or nil,
  }
end

M.get_ft_opts = function(ft)
  local merged_opts = vim.tbl_extend('force', config.defaults, config.by_ft[ft] or {})
  return {
    expandtab = merged_opts.expandtab or nil,
    shiftwidth = merged_opts.shiftwidth or nil,
    softtabstop = merged_opts.softtabstop or nil,
  }
end

local warn = function(msg, ...)
  vim.notify(msg:format(...), vim.log.levels.WARN, { title = 'shifty.nvim' })
end

local warn_both_specified = function(long, short, ft)
  warn("Both `%s` and `%s` specified for filetype `%s`, ignoring `%s`", long, short, ft, short)
end

M.setup = function(user_config)
  -- Merge config
  user_config = user_config or {}
  vim.validate { user_config = { user_config, 'table' } }
  user_config.by_ft = user_config.by_ft or {}
  for ft, opts in pairs(user_config.by_ft) do
    if type(opts) == 'number' then
      user_config.by_ft[ft] = { shiftwidth = opts }
    elseif type(opts) == 'table' then
      if opts.expandtab and opts.et then warn_both_specified('expandtab', 'et', ft) end
      if opts.shiftwidth and opts.sw then warn_both_specified('shiftwidth', 'sw', ft) end
      if opts.softtabstop and opts.sts then warn_both_specified('softtabstop', 'sts', ft) end
      user_config.by_ft[ft] = {
        expandtab = opts.expandtab or opts.et or nil,
        shiftwidth = opts.shiftwidth or opts.sw or nil,
        softtabstop = opts.softtabstop or opts.sts or nil,
      }
    else
      warn("Specification for filetype `%s` should be a number or a table, ignoring")
      user_config.by_ft[ft] = nil
    end
  end
  config = vim.tbl_deep_extend('force', config, user_config)

  -- Create autocommand
  local shifty_group = vim.api.nvim_create_augroup('shifty', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = shifty_group,
    callback = function(a)
      local opts = M.get_ft_opts(a.match)
      for opt, val in pairs(opts) do
        vim.bo[a.buf][opt] = val
      end
    end,
    desc = "Set expandtab/shiftwidth/softtabstop by filetype",
  })

  -- Attach mappings
  if config.embedded.enabled then
    for lhs, modes in pairs(config.embedded.mappings) do
      if type(modes) == 'string' then modes = { modes } end
      for _, mode in ipairs(modes) do
        local prev = vim.fn.maparg(lhs, mode, false, true)
        if prev.buffer == 1 then
          goto continue
        end

        local rhs = prev.callback or prev.rhs or lhs

        local map_opts = {
          silent = prev.silent == 1 or nil,
          remap = prev.noremap == 0 or nil,
          script = prev.script == 1 or nil,
          nowait = prev.nowait == 1 or nil,
        }

        local callback = make_callback(rhs, prev.expr == 1)
        vim.keymap.set(mode, lhs, callback, map_opts)
      end
      ::continue::
    end
  end
end

return M
