local window = require('games.window')
local gfx = require('games.gfx')

---@class games.test
local M = {}

local game = {
  gfx_canvas_type = 'halfblock',
  is_running = false,
  field = { width = -1, height = -1 },
}

local snowflakes = {}
local max_snowflakes = 0
local max_snowflakes2 = 0
local counter = 0

local ground_snowflakes = {}

local function add_keymaps()
  local buf = window.buf
  local opts = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set('n', 'q', function() M.quit() end, opts)
  vim.keymap.set('n', 'r', function() M.restart() end, opts)
  window.set_footer(' [r]estart [q]uit ')
end

local function init()
  gfx.init(game.gfx_canvas_type)
  window.set_title(' Demo: Snow ')
  add_keymaps()

  local size = gfx.canvas.size()
  game.field.width = size.width
  game.field.height = size.height
end

local function init_snow()
  snowflakes = {}
  max_snowflakes = 2 * game.field.width
  max_snowflakes2 = max_snowflakes
  ground_snowflakes = {}
  for i = 0, game.field.width - 1 do
    ground_snowflakes[i] = 0
  end
end

local function new_snowflake()
  return {
    x = math.random(0, game.field.width - 1),
    y = -1,
    counter = 0,
    speed = 1.0 / math.random(2, 5),
  }
end

local function update_max_snowflakes()
  local min_gh = 0
  for _, v in pairs(ground_snowflakes) do
    if v < min_gh or min_gh == 0 then min_gh = v end
  end
  local max_height = math.floor(game.field.height / 2)
  max_snowflakes2 = math.floor(max_snowflakes * (max_height - min_gh) / max_height)
  if max_snowflakes2 < 1 then M.restart() end
end

local function add_snowflake()
  counter = counter + 1.0 / 15.0
  if counter >= 1 then
    if #snowflakes < max_snowflakes2 then table.insert(snowflakes, new_snowflake()) end
    counter = 0
  end
end

local function move_snowflake(snowflake)
  local gh = ground_snowflakes[snowflake.x]

  -- Removes the snowflake from its current position.
  gfx.remove_point(snowflake.x, snowflake.y)

  -- Moves sometimes to the left or right.
  if snowflake.y < game.field.height - gh - 3 then
    snowflake.x = snowflake.x + math.random(-1, 1)
    if snowflake.x < 0 then snowflake.x = 0 end
    if snowflake.x > game.field.width - 1 then snowflake.x = game.field.width - 1 end
    gh = ground_snowflakes[snowflake.x]
  end

  -- Moves downwards or sometimes upwards.
  if snowflake.y > 2 and snowflake.y < game.field.height - gh - 3 then
    snowflake.y = snowflake.y + (math.random(1, 8) < 8 and 1 or -1)
  else
    snowflake.y = snowflake.y + 1
  end

  -- Draws the snowflake at its new position.
  gfx.draw_point(snowflake.x, snowflake.y)
end

local function snow_can_grow(snowflake)
  local gh = ground_snowflakes[snowflake.x]
  local gh_l1 = snowflake.x > 0 and ground_snowflakes[snowflake.x - 1] or gh
  local gh_l2 = snowflake.x > 1 and ground_snowflakes[snowflake.x - 2] or gh
  local gh_r1 = snowflake.x < game.field.width - 1 and ground_snowflakes[snowflake.x + 1] or gh
  local gh_r2 = snowflake.x < game.field.width - 2 and ground_snowflakes[snowflake.x + 2] or gh
  return gh <= gh_l1 and gh <= gh_l2 and gh <= gh_r1 and gh <= gh_r2
end

local function grow_ground_snow(snowflake, idx)
  local gh = ground_snowflakes[snowflake.x]
  if snowflake.y == game.field.height - 1 - gh then
    -- Snowflake reached the top of the ground.
    if snow_can_grow(snowflake) then
      table.remove(snowflakes, idx)
      if #snowflakes < max_snowflakes2 then table.insert(snowflakes, new_snowflake()) end
      ground_snowflakes[snowflake.x] = gh + 1
    end
  elseif snowflake.y > game.field.height - 1 - gh then
    -- Snowflake is inside the ground snow.
    table.remove(snowflakes, idx)
    if #snowflakes < max_snowflakes2 then table.insert(snowflakes, new_snowflake()) end
  end
end

local function handle_snow()
  for idx, snowflake in ipairs(snowflakes) do
    snowflake.counter = snowflake.counter + snowflake.speed
    if snowflake.counter >= 1.0 then
      move_snowflake(snowflake)
      grow_ground_snow(snowflake, idx)
      snowflake.counter = 0
    end
  end
end

local waiting_runs = 0

local function run()
  if not game.is_running then return end

  update_max_snowflakes()
  add_snowflake()
  handle_snow()
  window.set_title(' Demo: Snow [' .. #snowflakes .. ']')

  waiting_runs = waiting_runs + 1
  vim.defer_fn(function()
    run()
    waiting_runs = waiting_runs - 1
  end, 1000 / 30)
end

function M.restart()
  gfx.clear()
  init_snow()
end

function M.restart2()
  game.is_running = false
  while waiting_runs > 0 do
    vim.wait(100)
  end
  gfx.clear()
  init_snow()
  game.is_running = true
  run()
end

function M.start()
  if not window.open() then return end
  init()
  init_snow()
  game.is_running = true
  run()
end

function M.quit()
  game.is_running = false
  window.close()
end

return M
