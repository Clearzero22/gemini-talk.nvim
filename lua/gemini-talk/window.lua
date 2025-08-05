-- lua/gemini-talk/window.lua

local M = {}
local api = vim.api

-- Function to handle user input
local function handle_input(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local last_line = lines[#lines]
  if last_line and #last_line > 0 then
    -- Clear the input line before sending
    lines[#lines] = ""
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    require("gemini-talk").send_message(last_line)
  end
end

-- Creates and opens the floating window
function M.open()
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

  -- Set window options
  api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")
  api.nvim_buf_set_option(buf, "bufhidden", "hide")

  -- Initial prompt message
  api.nvim_buf_set_lines(buf, 0, -1, false, { "Ask Gemini anything...", "--------------------", "" })
  api.nvim_win_set_cursor(win, { 3, 0 })
  vim.cmd("startinsert!")

  -- Keymap for Enter to send message
  api.nvim_buf_set_keymap(buf, "i", "<Enter>", ":lua require('gemini-talk.window').handle_input_public()<CR>", { noremap = true, silent = true })
end

-- Publicly accessible input handler for the keymap
function M.handle_input_public()
  handle_input(M.buf)
end

-- Locks or unlocks the input prompt
function M.set_prompt_lock(locked)
  if M.buf and api.nvim_buf_is_valid(M.buf) then
    if locked then
      api.nvim_buf_set_option(M.buf, "modifiable", false)
      M.append_content({ "", "Gemini is thinking..." })
    else
      api.nvim_buf_set_option(M.buf, "modifiable", true)
      local lines = api.nvim_buf_get_lines(M.buf, 0, -1, false)
      local new_lines = {}
      for _, line in ipairs(lines) do
        if not line:match("^Gemini is thinking...") then
          table.insert(new_lines, line)
        end
      end
      api.nvim_buf_set_lines(M.buf, 0, -1, false, new_lines)
      local line_count = api.nvim_buf_line_count(M.buf)
      api.nvim_win_set_cursor(M.win, { line_count, 0 })
      vim.cmd("startinsert!")
    end
  end
end

-- Appends content to the window
function M.append_content(lines)
  if M.buf and api.nvim_buf_is_valid(M.buf) then
    local current_lines = api.nvim_buf_get_lines(M.buf, 0, -1, false)
    -- Remove the last empty line which is the prompt area
    table.remove(current_lines)
    for _, line in ipairs(lines) do
      table.insert(current_lines, line)
    end
    -- Add a new empty line for the next prompt
    table.insert(current_lines, "")
    api.nvim_buf_set_lines(M.buf, 0, -1, false, current_lines)
    local line_count = api.nvim_buf_line_count(M.buf)
    api.nvim_win_set_cursor(M.win, { line_count, 0 })
  end
end

return M