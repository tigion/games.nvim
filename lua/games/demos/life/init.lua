local window = require('games.window')
local gfx = require('games.gfx')
local matrix = require('games.matrix')

---@class games.demos.life
local M = {}

local game = {
  gfx_canvas_type = 'halfblock',
  field = { width = -1, height = -1 },
  matrix = nil,
  fps = 10,
  frame_time = -1,
  is_running = false,
  use_toroidal_matrix = true,
  waiting_runs = 0,
}

local stats = {
  population = 0,
  generations = 0,
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

  -- Creates the matrix of the game field.
  game.matrix = matrix:new(game.field.height, game.field.width)

  -- Calculates the frame time (timeout) based on the fps.
  game.frame_time = 1000.0 / game.fps
end

---Returns a random free game field position, otherwise nil.
---@return { x: integer, y: integer }?
local function random_free_position()
  local free_positions = game.matrix:get_positions_of(0)
  if #free_positions == 0 then return nil end
  return free_positions[math.random(1, #free_positions)]
end

---Fills the matrix with some live cells at free random positions.
---@param percent? integer Percentage of the live cells (0-100, default: 10)
local function init_live_cells(percent)
  percent = math.min(math.max(percent or 10, 0), 100)
  local count = math.floor((game.field.width * game.field.height) / percent)
  stats.population = 0
  for _ = 1, count do
    local pos = random_free_position()
    if pos then
      game.matrix:set(pos.y, pos.x, 1)
      stats.population = stats.population + 1
    end
  end
end

---Returns the number of live neighbors for a given cell.
---@param y integer
---@param x integer
---@return integer
local function count_live_neighbors(y, x)
  local count = 0
  local neighbor_offsets = {
    { y = -1, x = -1 }, -- top left
    { y = -1, x = 0 }, -- top
    { y = -1, x = 1 }, -- top right
    { y = 0, x = -1 }, -- left
    { y = 0, x = 1 }, -- right
    { y = 1, x = -1 }, -- bottom left
    { y = 1, x = 0 }, -- bottom
    { y = 1, x = 1 }, -- bottom right
  }
  for _, no in ipairs(neighbor_offsets) do
    if game.use_toroidal_matrix then
      -- Border wrapping.
      local y1, x1 = y + no.y, x + no.x
      y1 = ((y1 - 1) % game.matrix.height) + 1
      x1 = ((x1 - 1) % game.matrix.width) + 1
      count = count + game.matrix:get(y1, x1)
    else
      -- Border cells are dead cells.
      count = count + ((game.matrix:get(y + no.y, x + no.x) or 0) > 0 and 1 or 0)
    end
  end
  return count
end

---Evolves a cell based on the Game of Life rules.
---@param y integer
---@param x integer
---@return integer # New cell state (0 = dead, 1 = alive)
local function next_cell_state(y, x)
  local live_neighbors = count_live_neighbors(y, x)
  local cell = game.matrix:get(y, x)
  -- Any live cell with two or three live neighbours survives.
  -- Any dead cell with exactly three live neighbours becomes a live cell.
  -- All other cells die or remain dead.
  if cell == 1 and live_neighbors == 2 or live_neighbors == 3 then
    stats.population = stats.population + 1
    return 1
  end
  return 0
end

---Evolves all cells by one generation.
local function update_cell_states()
  stats.population = 0
  local new_matrix = matrix:new(game.field.height, game.field.width)
  for y = 1, new_matrix.height do
    for x = 1, new_matrix.width do
      new_matrix:set(y, x, next_cell_state(y, x))
    end
  end
  game.matrix = new_matrix
end

---Renders the current cell states to the graphics canvas.
local function render_cell_states()
  gfx.clear()
  for x = 0, game.field.width - 1 do
    for y = 0, game.field.height - 1 do
      if game.matrix:get(y, x, { is_0_based = true }) == 1 then gfx.draw_point(x, y) end
    end
  end
end

---The main game loop.
local function run()
  if not game.is_running then return end

  -- Creates the next cells generation.
  update_cell_states()
  render_cell_states()
  stats.generations = stats.generations + 1
  window.set_title(string.format(' Demo: Life [%d] ', stats.population))

  -- Schedules the next run.
  game.waiting_runs = game.waiting_runs + 1
  vim.defer_fn(function()
    run()
    game.waiting_runs = game.waiting_runs - 1
  end, game.frame_time)
end

local function reset()
  gfx.clear()
  game.matrix:clear()
  init_live_cells()
  render_cell_states()
end

function M.start()
  if not window.open() then return end
  init()

  reset()

  game.is_running = true
  run()
end

function M.restart()
  game.is_running = false

  while game.waiting_runs > 0 do
    vim.wait(100)
  end

  reset()

  game.is_running = true
  run()
end

function M.quit()
  game.is_running = false
  window.close()
end

return M
