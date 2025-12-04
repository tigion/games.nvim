local window = require('games.window')
local gfx = require('games.gfx')
local matrix = require('games.matrix')
local snake = require('games.snake.snake')
local food = require('games.snake.food')

---@class games.snake
local M = {}

---The game state.
local game = {
  gfx_canvas_type = 'halfblock',
  field = { width = -1, height = -1 },
  matrix = nil,
  fps = 30,
  frame_time = -1,
  is_started = false,
  is_running = false,
  waiting_runs = 0,
}

---The speeds as fractions of the frame rate.
-- 100.00%: 1.0/1.0  = 1.000, every  1 frame
--  50.00%: 1.0/2.0  = 0.500, every  2 frames
--  25.00%: 1.0/4.0  = 0.250, every  4 frames
--   6.66%: 1.0/15.0 = 0.066, every 15 frames
local speeds = {
  snake = {
    default = 1.0 / 6.0,
    current = 0.0,
    counter = 0.0,
  },
  food = {
    default = 1.0 / 15.0,
    current = 0.0,
    counter = 0.0,
  },
}

local stats = {
  score = 0,
}

---Adds the key mappings for the game.
local function add_keymaps()
  local buf = window.buf
  local opts = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set('n', 'q', function() M.quit() end, opts)
  vim.keymap.set('n', 'r', function() M.restart() end, opts)
  vim.keymap.set('n', '<Space>', function() M.play() end, opts)
  vim.keymap.set('n', 'h', function() M.action('left') end, opts)
  vim.keymap.set('n', 'j', function() M.action('down') end, opts)
  vim.keymap.set('n', 'k', function() M.action('up') end, opts)
  vim.keymap.set('n', 'l', function() M.action('right') end, opts)

  vim.keymap.set('n', 'm', function() M.action('debug_fill') end, opts)
end

---Shows the intro screen.
local function show_intro()
  local lines = {
    'The Hungry Snake',
    '',
    'hjkl - move   ',
    '   r - restart',
    '   q - quit   ',
    '',
    'press space to play',
  }
  gfx.center_text_in_canvas(lines)
  window.set_footer('')
end

---Shows the game over screen.
local function show_game_over()
  local lines = {
    'Game Over!',
    '',
    'Your Score: ' .. stats.score,
    '',
    'press r to restart',
    'press q to quit',
  }
  gfx.center_text_in_canvas(lines)
  window.set_footer('')
end

---Returns a random free game field position, otherwise nil.
---@return { x: integer, y: integer }?
local function random_free_position()
  local free_positions = game.matrix:get_positions_of(0, { ignore_halfblocks = game.gfx_canvas_type == 'halfblock' })
  if #free_positions == 0 then return nil end
  return free_positions[math.random(1, #free_positions)]
end

---Returns a random start position and direction for the snake.
---@return { x: integer, y: integer, dir: string }
local function random_snake_start()
  local direction_choices = snake.directions
  local dir = direction_choices[math.random(1, #direction_choices)]
  local x, y

  if dir == 'left' then
    x = game.field.width
    y = math.floor(game.field.height / 2)
  elseif dir == 'down' then
    dir = 'down'
    x = math.floor(game.field.width / 2)
    y = -1
  elseif dir == 'up' then
    x = math.floor(game.field.width / 2)
    y = game.field.height
  else
    x = -1
    y = math.floor(game.field.height / 2)
  end

  return { x = x, y = y, dir = dir }
end

---Places food at a random position.
---@return boolean # True if food was placed, otherwise false.
local function place_food()
  local pos = random_free_position()
  if pos == nil then return false end

  local base_pos = gfx.block_base_position(pos.x, pos.y)
  local food_item = food.add(base_pos.x, base_pos.y)
  for _, bp in ipairs(gfx.block_positions(pos.x, pos.y)) do
    game.matrix:set(bp.y, bp.x, 2, { is_0_based = true })
  end
  local icon = food_item.animation.icons[food_item.animation.idx]
  gfx.draw_text(icon, pos.x, pos.y)

  return true
end

---Draws the snake movement.
local function update_snake()
  local head = snake.head()
  local old_tail = snake.old_tail()
  if old_tail ~= nil then
    game.matrix:set(old_tail.y, old_tail.x, 0, { is_0_based = true })
    gfx.remove_point(old_tail.x, old_tail.y)
  end
  game.matrix:set(head.y, head.x, 1, { is_0_based = true })
  gfx.draw_point(head.x, head.y)
end

---Draws the animation of the food items.
local function update_food()
  for _, item in pairs(food.items) do
    local pos = gfx.block_base_position(item.pos.x, item.pos.y)
    local icon = item.animation.icons[item.animation.idx]
    gfx.draw_text(icon, pos.x, pos.y)
  end
end

---Handles the score based adjustments.
local function handle_score_adjustments()
  -- Places more food.
  if food.count() < stats.score / 20 then place_food() end

  -- Increases the snake speed.
  local thresholds = {
    { score = 200, speed = 1.0 },
    { score = 100, speed = 1.0 / 2.0 },
    { score = 50, speed = 1.0 / 3.0 },
    { score = 25, speed = 1.0 / 4.0 },
    { score = 10, speed = 1.0 / 5.0 },
    { score = 0, speed = 1.0 / 6.0 },
  }
  for _, threshold in ipairs(thresholds) do
    if stats.score >= threshold.score then
      speeds.snake.current = threshold.speed
      break
    end
  end
end

---Returns true if there is a collision, otherwise false.
---@return boolean
local function has_collision()
  local head = snake.head()
  local opts = { is_0_based = true }

  -- No collision
  if game.matrix:get(head.y, head.x, opts) == 0 then return false end

  -- Game field border
  if game.matrix:get(head.y, head.x, opts) == nil then return true end

  -- Snake body
  if game.matrix:get(head.y, head.x, opts) == 1 then return true end

  -- Food
  if game.matrix:get(head.y, head.x, opts) == 2 then
    local food_pos = gfx.block_base_position(head.x, head.y)
    local food_item = food.get(food_pos.x, food_pos.y)
    if food_item == nil then return false end

    -- Grows the snake and increases the score.
    snake.grow(food_item.grow_amount)
    stats.score = stats.score + food_item.grow_amount

    -- New food must be placed before removing the old one.
    place_food()
    handle_score_adjustments()
    -- Removes the old food item.
    food.remove(food_pos.x, food_pos.y)
    for _, bp in ipairs(gfx.block_positions(head.x, head.y)) do
      game.matrix:set(bp.y, bp.x, 0, opts)
    end
    gfx.draw_text(' ', head.x, head.y)

    -- Updates the window title with the new score.
    window.set_title(' Snake [' .. stats.score .. ' Points]')
  end

  return false
end

---Handles the snake movement.
local function handle_snake()
  speeds.snake.counter = speeds.snake.counter + speeds.snake.current
  if speeds.snake.counter >= 1 then
    -- Moves the snake.
    snake.move()

    -- Checks for collisions.
    if has_collision() then
      game.is_running = false
      show_game_over()
      return
    end

    -- Draws the snake movement.
    update_snake()

    speeds.snake.counter = 0
  end
end

local function handle_food()
  speeds.food.counter = speeds.food.counter + speeds.food.current
  if speeds.food.counter >= 1 then
    food.animate()
    update_food()
    speeds.food.counter = 0
  end
end

---Initializes the game.
local function init()
  gfx.init(game.gfx_canvas_type)
  window.set_title(' Snake ')
  add_keymaps()

  local size = gfx.canvas.size()
  game.field.width = size.width
  game.field.height = size.height

  -- Creates the matrix of the game field.
  game.matrix = matrix:new(game.field.height, game.field.width)

  -- Calculates the frame time (timeout) based on the fps.
  game.frame_time = 1000.0 / game.fps
end

---Prepares the game.
local function prepare()
  -- Resets the points.
  stats.score = 0

  -- Resets the game matrix.
  game.matrix:clear()

  -- Initializes the snake.
  local start = random_snake_start()
  local len = 5
  snake.init(start.x, start.y, start.dir, len)

  -- Resets the speeds.
  speeds.snake.current = speeds.snake.default
  speeds.food.current = speeds.food.default

  -- Sets the game field.
  gfx.clear()
  food.clear()
  place_food()

  -- Updates the window footer.
  window.set_title(' Snake ')
  window.set_footer(' [r]estart [q]uit ')
end

---The main game loop.
local function run()
  if not game.is_running then return end

  handle_snake()
  handle_food()

  -- Schedules the next run.
  vim.defer_fn(function() run() end, game.frame_time)
end

---Starts the game.
function M.start()
  if not window.open() then return end
  init()
  M.restart()
end

---Restarts the gameplay.
function M.restart()
  game.is_started = false
  game.is_running = false
  gfx.clear()
  show_intro()
  window.set_title(' Snake ')
end

---Starts and pauses the gameplay.
function M.play()
  -- Prepares the game if not started yet.
  if not game.is_started then
    prepare()
    game.is_started = true
  end

  -- Toggles the running state.
  game.is_running = not game.is_running
  if game.is_running then run() end
end

---Handles the input actions.
function M.action(action)
  if not game.is_running then return end

  -- Ignores if same or opposite direction.
  local opposite = { left = 'right', right = 'left', up = 'down', down = 'up' }
  if action == snake.direction or opposite[action] == snake.direction then return end

  snake.direction = action
end

---Stops the gameplay.
function M.quit()
  game.is_running = false
  window.close()
end

return M
