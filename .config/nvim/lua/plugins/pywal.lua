return {
  -- Lua theme that reads your current pywal cache (~/.cache/wal)
  {
    "AlphaTechnolog/pywal.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("pywal").setup()
    end,
  },
  -- Tell LazyVim to use this colorscheme
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "pywal" },
  },
}
