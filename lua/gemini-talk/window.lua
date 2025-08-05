-- lua/gemini-talk/window.lua

local M = {}

local api = vim.api
local conversation_history = {} -- 用于存储对话历史

-- 创建并打开悬浮窗口
function M.open()
  -- 如果窗口已存在，则聚焦
  if M.win and api.nvim_win_is_valid(M.win) then
    api.nvim_set_current_win(M.win)
    return
  end

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")
  local win_width = math.floor(width * 0.8)
  local win_height = math.floor(height * 0.8)
  local row = math.floor((height - win_height) / 2)
  local col = math.floor((width - win_width) / 2)

  local buf = api.nvim_create_buf(false, true)
  M.buf = buf

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = "Gemini Talk",
    title_pos = "center",
  })
  M.win = win

  -- 设置窗口选项
  api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")
  api.nvim_buf_set_option(buf, "buftype", "prompt")
  api.nvim_buf_set_option(buf, "bufhidden", "hide")

  -- 初始提示信息
  api.nvim_buf_set_lines(buf, 0, -1, false, { "Ask Gemini anything...", "--------------------" })
  api.nvim_win_set_cursor(win, { 3, 0 })

  -- 设置回调，用于处理用户输入
  vim.bo[buf].prompt_callback = function(input)
    if input and #input > 0 then
      require("gemini-talk").send_message(input)
    end
  end
end

-- 将内容追加到窗口
function M.append_content(lines)
  if M.buf and api.nvim_buf_is_valid(M.buf) then
    api.nvim_buf_set_lines(M.buf, -1, -1, false, lines)
    -- 自动滚动到底部
    local line_count = api.nvim_buf_line_count(M.buf)
    api.nvim_win_set_cursor(M.win, { line_count, 0 })
  end
end

return M
