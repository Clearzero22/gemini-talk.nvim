-- lua/gemini-talk/init.lua

local M = {}
local config = {
	api_key = nil, -- 用户必须提供
}

local conversation_history = {}

-- 设置函数，供用户配置
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	if not config.api_key then
		vim.notify("Gemini Talk: API key is not configured!", vim.log.levels.ERROR)
	end
end

-- 发送消息给 Gemini API
function M.send_message(prompt)
	if not config.api_key then
		vim.notify("Gemini Talk: API key is missing. Please run setup()", vim.log.levels.ERROR)
		return
	end

	local window = require("gemini-talk.window")
	window.append_content({ "", "You: " .. prompt, "" }) -- 显示用户输入

	-- 构建请求体
	table.insert(conversation_history, { role = "user", parts = { { text = prompt } } })
	local body = vim.json.encode({ contents = conversation_history })

	local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"

	-- 使用 curl 发送异步请求
	vim.fn.jobstart(
		{
			"curl",
			"-s",
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"-H",
			"X-goog-api-key: " .. config.api_key,
			"-d",
			body,
			url,
		},
		{
			on_stdout = function(_, data)
  if data then
    local window = require("gemini-talk.window")
    local raw_response = table.concat(data, "")
    vim.notify("Gemini Raw Response: " .. raw_response, vim.log.levels.INFO)

    local success, response = pcall(vim.json.decode, raw_response)
    if not success or not response then
      window.append_content({ "Gemini: Error decoding JSON response." })
      vim.notify("Gemini Talk: Failed to decode JSON: " .. raw_response, vim.log.levels.ERROR)
      window.set_prompt_lock(false)
      return
    end

    if response.error then
      local err_msg = response.error.message or "Unknown API error"
      window.append_content({ "Gemini API Error: " .. err_msg })
      vim.notify("Gemini API Error: " .. err_msg, vim.log.levels.ERROR)
      window.set_prompt_lock(false)
      return
    end

    if not response.candidates or not response.candidates[1] then
      window.append_content({ "Gemini: Invalid response (no candidates)." })
      vim.notify("Gemini Talk: No candidates found in response: " .. vim.inspect(response), vim.log.levels.WARN)
      window.set_prompt_lock(false)
      return
    end

    local content = response.candidates[1].content
    if not content or not content.parts or not content.parts[1] then
      window.append_content({ "Gemini: Invalid response (no content parts)." })
      vim.notify("Gemini Talk: No content parts found: " .. vim.inspect(response), vim.log.levels.WARN)
      window.set_prompt_lock(false)
      return
    end

    local text = content.parts[1].text
    if not text then
      window.append_content({ "Gemini: Invalid response (no text)." })
      vim.notify("Gemini Talk: No text found in content part: " .. vim.inspect(response), vim.log.levels.WARN)
      window.set_prompt_lock(false)
      return
    end

    table.insert(conversation_history, content)
    window.append_content({ "Gemini: " .. text, "--------------------" })
    window.set_prompt_lock(false)
  end
end,
			on_stderr = function(_, data)
				if data then
					local stderr = table.concat(data, "")
					vim.notify("Gemini Talk cURL Error: " .. stderr, vim.log.levels.ERROR)
					window.append_content({ "Gemini cURL Error: " .. stderr })
					window.set_prompt_lock(false) -- 解锁输入
				end
			end,
		}
	)
end

return M
