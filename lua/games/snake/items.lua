---@class games.snake.items
local M = {}

local types = {
  food = { icons = { 'ò', 'ó' }, is_deadly = false, grow_amount = 3 },
  -- food_big = { icons = { 'Ò', 'Ó' }, is_deadly = false, grow_amount = 5 },
  -- food_bad = { icons = { '+', 'x' }, is_deadly = false, grow_amount = -2 },
  stone = { icon = '#', is_deadly = true },
}

M.items = {}

function M.add_snake_segment(x, y)
  local key = x .. ',' .. y
  M.items[key] = {
    type = 'snake',
    pos = { x = x, y = y },
    is_deadly = true,
  }
  return M.items[key]
end

function M.add_food(x, y)
  local key = x .. ',' .. y
  M.items[key] = {
    type = 'food',
    pos = { x = x, y = y },
    is_deadly = types.food.is_deadly,
    grow_amount = types.food.grow_amount,
    animation = { icons = types.food.icons, idx = math.random(1, #types.food.icons) },
  }
  return M.items[key]
end

function M.remove(x, y)
  local key = x .. ',' .. y
  M.items[key] = nil
end

---Clears all food items.
function M.clear() M.items = {} end

---Animates all food items by moving to the next icon in their animation.
function M.animate()
  for _, item in ipairs(M.items) do
    if item.animation then
      item.animation.idx = item.animation.idx + 1
      if item.animation.idx > #item.animation.icons then item.animation.idx = 1 end
    end
  end
end

return M
