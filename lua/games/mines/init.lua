local window = require('games.window')
local gfx = require('games.gfx')
local matrix = require('games.matrix')

-- Minesweeper game implementation.
--
-- Used cell states:
-- - 0 -> --- (empty)
-- - 1 -> --* (mine)
-- - 2 -> -f- (empty + flagged)
-- - 3 -> -f* (mine + flagged)
-- - 4 -> c-- (empty + checked)
--
-- Unused cell states:
-- - 5 -> c-* (mine + checked)
-- - 6 -> cf- (empty + flagged + checked)
-- - 7 -> cf* (mine + flagged + checked)

---@class games.mines
local M = {}

---The game state.
local game = {
  gfx_canvas_type = 'singleblock',
  field = { width = -1, height = -1 },
  matrix = nil,
  is_running = false,
  waiting_runs = 0,
}

-- FIX: check multibyte characters in gfx.draw_text()
local icons = {
  field = '.', -- '░'
  empty = ' ',
  mine = '*',
  flag = 'x',
}

local stats = {
  mine_count = 0,
  flag_count = 0,
  start_time = 0,
  end_time = 0,
}

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

local function is_empty(y, x)
  local value = game.matrix:get(y, x)
  return value % 2 == 0
end

local function is_mine(y, x)
  local value = game.matrix:get(y, x)
  return value % 2 == 1
end

local function is_flagged(y, x)
  local value = game.matrix:get(y, x)
  return (math.floor(value / 2.0)) % 2 == 1
end

local function is_checked(y, x)
  local value = game.matrix:get(y, x)
  return (math.floor(value / 4.0)) % 2 == 1
end

local function set_mine(y, x, mine)
  if mine == is_mine(y, x) then return end
  local value = game.matrix:get(y, x)
  local new_value = value + (mine and 1 or -1)
  game.matrix:set(y, x, new_value)
  stats.mine_count = stats.mine_count + 1
end

local function set_flagged(y, x, flagged)
  if flagged == is_flagged(y, x) then return end
  local value = game.matrix:get(y, x)
  local new_value = value + (flagged and 2 or -2)
  game.matrix:set(y, x, new_value)
end

local function set_checked(y, x, checked)
  if checked == is_checked(y, x) then return end
  local value = game.matrix:get(y, x)
  local new_value = value + (checked and 4 or -4)
  game.matrix:set(y, x, new_value)
end

---Adds the key mappings for the game.
local function add_keymaps()
  local buf = window.buf
  local opts = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set('n', 'q', function() M.quit() end, opts)
  vim.keymap.set('n', 'r', function() M.restart() end, opts)
  vim.keymap.set('n', '<Space>', function() M.play() end, opts)
  vim.keymap.set('n', 'f', function() M.action('flag') end, opts)
  vim.keymap.set('n', 'd', function() M.action('detect') end, opts)
end

---Shows the intro screen.
local function show_intro()
  local lines = {
    'Find the Mines!',
    '',
    ' hjkl - move   ',
    '    f - flag   ',
    '    d - detect ',
    '    r - restart',
    '    q - quit   ',
    '',
    'press space to play',
  }
  gfx.center_text_in_canvas(lines)
  window.set_footer('')
end

---Initializes the game.
local function init()
  gfx.init(game.gfx_canvas_type)
  window.set_title(' Mines ')
  add_keymaps()

  local size = gfx.canvas.size()
  game.field.width = size.width
  game.field.height = size.height

  -- Creates the matrix of the game field.
  game.matrix = matrix:new(game.field.height, game.field.width)
end

local function reset_field()
  for y = 0, game.field.height - 1 do
    for x = 0, game.field.width - 1 do
      gfx.draw_text(icons.field, x, y)
    end
  end
  gfx.refresh()
end

local function place_mines(percent)
  percent = math.min(math.max(percent or 10, 0), 100)
  local count = math.floor((game.field.width * game.field.height) * percent / 100.0)
  local free_positions = game.matrix:get_positions_of(0)
  stats.mine_count = 0
  if #free_positions == 0 then return end
  for _ = 1, count do
    local idx = math.random(1, #free_positions)
    local pos = table.remove(free_positions, idx)
    if pos then set_mine(pos.y, pos.x, true) end
  end
end

---Prepares the game.
local function prepare()
  stats.start_time = os.time()
  game.matrix:clear()

  reset_field()
  place_mines()

  window.set_title(' Mines ')
  window.set_footer(' [r]estart [q]uit ')
end

local function update_title()
  local end_time = stats.end_time ~= 0 and stats.end_time or os.time()
  window.set_title(' Mines [' .. stats.mine_count - stats.flag_count .. '|' .. end_time - stats.start_time .. 's] ')
end

---The main game loop.
local function run()
  if not game.is_running or not vim.g.tigion_games_is_active then return end

  update_title()

  -- Schedules the next run.
  game.waiting_runs = game.waiting_runs + 1
  vim.defer_fn(function()
    run()
    game.waiting_runs = game.waiting_runs - 1
  end, 1000)
end

---Toggles a flag at the current cursor position.
---
local function toggle_flag()
  local pos = gfx.cursor_position()
  local x, y = pos.x + 1, pos.y + 1

  if is_checked(y, x) then return end

  set_flagged(y, x, not is_flagged(y, x))
  local flagged = is_flagged(y, x)

  local icon = flagged and icons.flag or icons.field
  stats.flag_count = stats.flag_count + (flagged and 1 or -1)

  gfx.draw_text(icon, pos.x, pos.y)
  update_title()
end

local function count_neighbor_mines(y, x)
  local count = 0
  for _, no in ipairs(neighbor_offsets) do
    local ny = y + no.y
    local nx = x + no.x
    if game.matrix:is_valid(ny, nx) and is_mine(ny, nx) then count = count + 1 end
  end
  return count
end

local function check_neighbors(y, x)
  for _, no in ipairs(neighbor_offsets) do
    local ny = y + no.y
    local nx = x + no.x
    -- Checks only valid, unchecked, and unflagged neighbors.
    if game.matrix:is_valid(ny, nx) and not is_checked(ny, nx) and not is_flagged(ny, nx) then
      set_checked(ny, nx, true)
      if not is_mine(ny, nx) then
        local count = count_neighbor_mines(ny, nx)
        local icon = (count == 0) and icons.empty or tostring(count)
        gfx.draw_text(icon, nx - 1, ny - 1)

        if count == 0 then
          if nx >= 1 and nx <= game.field.width and ny >= 1 and ny <= game.field.height then check_neighbors(ny, nx) end
        end
      end
    end
  end
end

local function show_mines()
  for y = 1, game.field.height do
    for x = 1, game.field.width do
      if is_mine(y, x) then gfx.draw_text(icons.mine, x - 1, y - 1) end
    end
  end
end

local function are_all_safe_cells_checked()
  for y = 1, game.field.height do
    for x = 1, game.field.width do
      if is_empty(y, x) and not is_checked(y, x) then return false end
    end
  end
  return true
end

local function detect_mine()
  local pos = gfx.cursor_position()
  local x, y = pos.x + 1, pos.y + 1

  if is_checked(y, x) then return end

  -- remove flag
  if is_flagged(y, x) then toggle_flag() end

  -- Checks if a mine is triggered.
  if is_mine(y, x) then
    stats.end_time = os.time()
    update_title()
    game.is_running = false
    vim.notify('You loose!', vim.log.levels.INFO, { title = 'Mines' })
    show_mines()
    return
  end

  -- Display number of adjacent mines or empty space.
  local count = count_neighbor_mines(y, x)
  local icon = (count == 0) and icons.empty or tostring(count)
  gfx.draw_text(icon, pos.x, pos.y)
  set_checked(y, x, true)

  -- Check for win condition.
  if are_all_safe_cells_checked() then
    stats.end_time = os.time()
    update_title()
    game.is_running = false
    vim.notify('You win!', vim.log.levels.INFO, { title = 'Mines' })
    show_mines()
    return
  end

  -- Check the neighbors if there are no adjacent mines.
  if count == 0 then check_neighbors(y, x) end
end

---Starts the game.
function M.start()
  if not window.open() then return end
  init()
  M.restart()
end

---Restarts the gameplay.
function M.restart()
  game.is_running = false
  gfx.clear()
  show_intro()
  window.set_title(' Mines ')
end

---Starts and pauses the gameplay.
function M.play()
  if game.is_running then return end

  game.is_running = true
  prepare()
  run()
end

---Handles the input actions.
function M.action(action)
  if not game.is_running then return end

  if action == 'flag' then
    toggle_flag()
  elseif action == 'detect' then
    detect_mine()
  end
end

---Stops the gameplay.
function M.quit() window.close() end

return M
