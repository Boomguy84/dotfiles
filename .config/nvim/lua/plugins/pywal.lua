-- ~/.config/nvim/lua/plugins/pywal16.lua
return {
  {
    "uZer/pywal16.nvim",
    lazy = false,
    priority = 1000,
    opts = { bold = true, italic = true, underline = false },
    config = function(_, opts)
      local function apply()
        require("pywal16").setup(opts)
        vim.cmd.colorscheme("pywal16")
        vim.cmd("doautocmd ColorScheme")
        vim.cmd("redraw!")
      end

      -- initial apply
      apply()

      -- manual reload command (kept as-is)
      vim.api.nvim_create_user_command("ReloadWal", apply, { desc = "Reload pywal16 colors" })

      -- NEW: auto reload when pywal updates its cache
      local uv       = vim.uv or vim.loop
      -- prefer colors.json (written by wal); fall back to colors-wal.vim
      local wal_json = vim.fn.expand("~/.cache/wal/colors.json")
      local wal_vim  = vim.fn.expand("~/.cache/wal/colors-wal.vim")
      local watch    = (vim.fn.filereadable(wal_json) == 1) and wal_json or wal_vim

      if uv and uv.new_fs_event and vim.fn.filereadable(watch) == 1 then
        local fsw = uv.new_fs_event()
        -- tiny debounce so multiple writes don't spam reloads
        local timer = uv.new_timer()
        local pending = false

        fsw:start(watch, {}, vim.schedule_wrap(function()
          if pending then return end
          pending = true
          timer:start(120, 0, function()
            timer:stop()
            pending = false
            vim.schedule(apply)
          end)
        end))

        -- clean up on exit
        vim.api.nvim_create_autocmd("VimLeavePre", {
          once = true,
          callback = function()
            pcall(fsw.stop, fsw)
            pcall(fsw.close, fsw)
            pcall(timer.stop, timer)
            pcall(timer.close, timer)
          end,
        })
      end
    end,
  },
}
