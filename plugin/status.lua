vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("KodexStatus", { clear = true }),
  pattern = "KodexEvent",
  callback = function(args)
    require("kodex.status").update(args.data)
  end,
  desc = "Update kodex status",
})
