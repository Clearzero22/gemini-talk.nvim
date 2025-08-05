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

	local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

	-- 使用 curl 发送异步请求
	vim.fn.jobstart({ "curl", "-s", "-X", "POST", "-H", "Content-Type: application/json", "-H", "X-goog-api-key: " .. config.api_key, "-d", body, url }, {
		on_stdout = function(_, data)
			if data then
				-- Log the raw response for debugging
				vim.notify("Gemini Raw Response: " .. table.concat(data, ""), vim.log.levels.INFO)

				local response = vim.json.decode(table.concat(data, ""))
				if response and response.candidates and response.candidates[1] then
					local content = response.candidates[1].content
					if content and content.parts and content.parts[1] then
						local text = content.parts[1].text
						table.insert(conversation_history, content) -- 将模型回复添加到历史记录
						window.append_content({ "Gemini: " .. text, "--------------------" })
					else
						window.append_content({ "Gemini: Error parsing response." })
						vim.notify("Gemini Talk: Could not find text in response.", vim.log.levels.WARN)
					end
				elseif response.error then
					window.append_content({ "Gemini API Error: " .. response.error.message })
					vim.notify("Gemini API Error: " .. response.error.message, vim.log.levels.ERROR)
				else
					window.append_content({ "Gemini: Received an invalid response." })
					vim.notify("Gemini Talk: Invalid response received: " .. vim.inspect(response), vim.log.levels.WARN)
				end
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
	})
end

return M
