---@class games.config
local M = {}

---@class games.ConfigSize
---@field width? integer
---@field height? integer

---@class games.ConfigWindow
---@field width? number|integer
---@field height? number|integer
---@field min? games.ConfigSize
---@field max? games.ConfigSize
---@field border? string
---@field ignore_34_aspect_ratio? boolean
---
---@class games.Config
---@field window? games.ConfigWindow

---The default options.
---@type games.Config
local defaults = {
  window = {
    width = 0.8,
    height = 0.8,
    min = { width = 30, height = 15 },
    max = { width = 60, height = 30 },
    border = nil, -- defaults to vim.o.winborder or 'none', 'single', 'double', 'rounded', 'solid', 'shadow'
    ignore_34_aspect_ratio = false,
  },
}

---The current options. Uses defaults without setup.
---@type games.Config
M.options = vim.deepcopy(defaults, true)

---Setups the plugin configuration.
---@param opts games.Config The user options.
function M.setup(opts)
  opts = opts or {}
  -- Merges the default options with the user options.
  M.options = vim.tbl_deep_extend('force', defaults, opts or {})
end

return M
