# games.nvim

A Neovim plugin for playing little games directly within Neovim.

> [!WARNING]
> This plugin is still in early development. Work in progress. 🚀

## Features

- Games:
  - **Snake** - The Hungry Snake
- Demos:
  - **Life** - Game of Life
  - **Snow** - Falling Snowflakes

## Installation

Use your favorite package manager to install `tigion/games.nvim`.

## Usage

Call the following command to select a game or a demo:

```lua
require('games').select()
```

## Configuration

The default options:

```lua
{
  window = {
    width = 0.8,
    height = 0.8,
    min = { width = 30, height = 15 },
    max = { width = 60, height = 30 },
    border = 'rounded',
    ignore_aspect_ratio = false,
  },
}
```
