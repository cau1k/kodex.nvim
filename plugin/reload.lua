vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("KodexAutoReload", { clear = true }),
  pattern = "KodexEvent",
  callback = function(args)
    local data = args.data or {}
    local event = data.event
    if type(event) ~= "table" then
      event = data.params
    end

    if type(event) == "table" and event.type == "file.edited" and require("kodex.config").opts.auto_reload then
      if not vim.o.autoread then
        -- Unfortunately `autoread` is kinda necessary, for `:checktime`.
        -- Alternatively we could `:edit!` but that would lose any unsaved changes.
        vim.notify(
          "Please set `vim.o.autoread = true` to use `kodex.nvim` auto-reload, or set `vim.g.kodex_opts.auto_reload = false`",
          vim.log.levels.WARN,
          { title = "kodex" }
        )
      else
        -- `schedule` because blocking the event loop during rapid SSE influx can drop events
        vim.schedule(function()
          -- `:checktime` checks all buffers - no need to check the event's file
          vim.cmd("checktime")
        end)
      end
    end
  end,
  desc = "Reload buffers edited by `kodex`",
})

