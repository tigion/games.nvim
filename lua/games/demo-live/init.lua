local window = require('games.window')
local gfx = require('games.gfx')
local matrix = require('games.matrix')

---@class games.demo_live
local M = {}

---The game state.
local game = {
  gfx_canvas_type = 'halfblock',
  field = { width = -1, height = -1 },
  matrix = nil,
  fps = 10,
  frame_time = -1,
  is_running = false,
}

local function add_keymaps()
  local opts = { buffer = window.buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set('n', 'q', function() M.quit() end, opts)
  vim.keymap.set('n', 'r', function() M.restart() end, opts)
  window.set_footer(' [r]estart [q]uit ')
end

local function init()
  gfx.init(game.gfx_canvas_type)
  window.set_title(' Demo: Life ')
  add_keymaps()

  local size = gfx.canvas.size()
  game.field.width = size.width
  game.field.height = size.height

  -- Creates the matrix.
  game.matrix = matrix:new(game.field.height, game.field.width)

  -- Calculates the frame time (timeout) based on the fps.
  game.frame_time = 1000.0 / game.fps
end

---Returns a random free game field position, otherwise nil.
---@return { x: integer, y: integer }?
local function random_free_position()
  local free_positions = game.matrix:get_positions_of(0, game.gfx_canvas_type == 'halfblock')
  if #free_positions == 0 then return nil end
  return free_positions[math.random(1, #free_positions)]
end

local function init_live_cells()
  -- Fills the matrix with some live cells at free random positions.
  for i = 1, math.floor((game.field.width * game.field.height) / 10) do
    local pos = random_free_position()
    if pos then
      game.matrix:set(pos.y, pos.x, 1)
      gfx.draw_point(pos.x, pos.y)
    end
  end
end

function M.start()
  if not window.open() then return end
  init()

  M.restart()
end

function M.restart()
  gfx.clear()
  game.matrix:clear()
  init_live_cells()

  -- game.is_running = true
  -- run()
end

function M.quit()
  game.is_running = false
  window.close()
end

return M
