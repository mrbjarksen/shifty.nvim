local utils = require 'shifty.utils'

local M = {}

M.with_opts = function(opts, callback, ...)
  local prev_eventignore = vim.opt.eventignore:get()

  -- Set desired options (without triggering OptionSet)
  vim.opt.eventignore:append('OptionSet')
  local opts_restore = {}
  for opt, val in pairs(opts) do
    if vim.opt[opt] ~= val then
      opts_restore[opt] = vim.opt[opt]
      vim.opt[opt] = val
    end
  end
  vim.opt.eventignore = prev_eventignore

  local return_val = callback(...)

  local has_been_reset = false
  local reset_opts = function()
    if has_been_reset then return end
    vim.opt.eventignore:append('OptionSet')
    for opt, val in pairs(opts_restore) do
      vim.opt[opt] = val
    end
    vim.opt.eventignore = prev_eventignore
    has_been_reset = true
  end

  -- Schedule resetting options until it is safe
  -- (this should happen after func has finished)
  vim.schedule(function()
    -- Wait to reset options if in operator-pending mode
    if utils.is_in_op_pend() then
      local op_pend_group = vim.api.nvim_create_augroup('shifty_operator_pending_reset', { clear = true })
      vim.api.nvim_create_autocmd('ModeChanged', {
        group = op_pend_group,
        pattern = 'no*',
        callback = vim.schedule_wrap(function()
          if not utils.is_in_op_pend() then
            reset_opts()
            pcall(vim.api.nvim_del_augroup_by_id, op_pend_group)
            pcall(vim.cmd, [[IndentBlanklineRefresh]])
          end
        end)
      })
    else
      reset_opts()
    end
  end)

  return return_val
end

M.make_callback = function(rhs, is_expr)
  local callback = rhs
  if type(rhs) == 'string' then
    if not is_expr then
      callback = function()
        return rhs
      end
    else
      callback = function()
        return vim.api.nvim_eval(rhs)
      end
    end
  end

  return function()
    return M.with_opts(utils.get_opts(), callback)
  end
end

M.attach = function(bufnr)
  local mappings = require'shifty.config'.cur.embedded.mappings

  for lhs, modes in pairs(mappings) do
    if type(modes) == 'string' then modes = { modes } end
    for _, mode in ipairs(modes) do
      local prev = vim.fn.maparg(lhs, mode, false, true)
      if bufnr == nil and prev.buffer == 1 then
        vim.keymap.del(mode, lhs, { buffer = true })
        local global_prev = vim.fn.maparg(lhs, mode, false, true)
        vim.fn.mapset(mode, false, prev)
        prev = global_prev
      end

      local rhs = prev.callback or prev.rhs or lhs

      local map_opts = {
        silent = prev.silent == 1 or nil,
        remap = prev.noremap == 0 or nil,
        script = prev.script == 1 or nil,
        nowait = prev.nowait == 1 or nil,
        expr = prev.expr == 1 or nil,
        replace_keycodes = prev.replace_keycodes == 1,
        buffer = bufnr,
        desc = "shifty.nvim override for " .. lhs,
      }

      if prev.desc or prev.rhs then
        map_opts.desc = map_opts.desc .. ", previously: " .. (prev.desc or prev.rhs)
      end

      if type(rhs) == 'string' and prev.expr ~= 1 then
        map_opts.remap = false
        map_opts.expr = true
        map_opts.replace_keycodes = true
      end

      local callback = M.make_callback(rhs, prev.expr == 1)
      vim.keymap.set(mode, lhs, callback, map_opts)
    end
  end
end

return M
