local config = require('games.config')

---@class games
local M = {}

local function select()
  local choices = {
    'Snake',
    'Demo: Life',
    'Demo: Snow',
  }

  vim.ui.select(choices, {
    prompt = 'Select a game to play:',
  }, function(name)
    if name == 'Snake' then
      require('games.snake').start()
    elseif name == 'Demo: Life' then
      require('games.demos.life').start()
    elseif name == 'Demo: Snow' then
      require('games.demos.snow').start()
    end
  end)
end

M.setup = config.setup
M.select = select

return M
