-- plugin/gemini_talk.lua

vim.api.nvim_create_user_command(
  "GeminiTalk",
  function()
    require("gemini-talk.window").open()
  end,
  {
    nargs = 0,
    desc = "Open a floating window to chat with Gemini",
  }
)
