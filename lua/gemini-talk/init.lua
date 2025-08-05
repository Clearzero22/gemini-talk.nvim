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

	local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key="
		.. config.api_key

	-- 使用 curl 发送异步请求
	vim.fn.jobstart({ "curl", "-s", "-X", "POST", "-H", "Content-Type: application/json", "-d", body, url }, {
		on_stdout = function(_, data)
			if data then
				local response = vim.json.decode(table.concat(data, ""))
				if response and response.candidates and response.candidates[1] then
					local content = response.candidates[1].content
					if content and content.parts and content.parts[1] then
						local text = content.parts[1].text
						table.insert(conversation_history, content) -- 将模型回复添加到历史记录
						window.append_content({ "Gemini: " .. text, "--------------------" })
					else
						window.append_content({ "Gemini: Error parsing response." })
					end
				elseif response.error then
					window.append_content({ "Gemini API Error: " .. response.error.message })
				else
					window.append_content({ "Gemini: Received an invalid response." })
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.notify("Gemini Talk Error: " .. table.concat(data, ""), vim.log.levels.ERROR)
			end
		end,
	})
end

return M
