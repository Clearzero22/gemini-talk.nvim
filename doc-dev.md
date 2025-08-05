# dev doc

---

# 下面是这个项目的开发文档请你按照下面的文档进行功能的开发

好的，我们来从头开始创建一个名为 `gemini-talk.nvim` 的 Neovim 插件，这个插件可以让你在 Neovim 中直接与 Gemini AI 进行对话。

### 第 1 步：创建 GitHub 仓库

首先，在你的 GitHub 上创建一个新的公开仓库，命名为 `gemini-talk.nvim`。这将是我们插件的家，其他人可以通过这个地址来安装和使用它。

创建完成后，将仓库克隆到你的本地，以便我们开始添加代码。

```bash
git clone https://github.com/YOUR_USERNAME/gemini-talk.nvim.git
cd gemini-talk.nvim
```

### 第 2 步：规划插件结构和功能

我们将实现一个核心功能：

* **`:GeminiTalk` 命令**: 打开一个悬浮窗口，你可以在其中输入问题。
* **API 调用**: 按下回车后，插件会将你的问题和之前的对话历史一起发送给 Google Gemini API。
* **显示回复**: API 的回复会追加到悬浮窗口中，形成一个持续的对话。

为了实现这个功能，我们需要一个 HTTP 请求库。这里我们选用 `curl`，因为它是最通用的，并且 Neovim 可以通过 `jobstart()` 与之交互。

**目录结构如下：**

```
gemini-talk.nvim/
├── lua/
│   └── gemini-talk/
│       ├── init.lua      -- 主逻辑文件
│       └── window.lua    -- 负责悬浮窗口的管理
├── plugin/
│   └── gemini_talk.lua -- 设置用户命令
└── README.md             -- 插件说明文档
```

### 第 3 步：编写插件的核心代码

现在，我们来填充这些文件。

#### **`lua/gemini-talk/window.lua`** (窗口管理)

这个文件负责创建、管理和更新我们的对话悬浮窗口。

```lua
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
```

#### **`lua/gemini-talk/init.lua`** (主逻辑)

这个文件是插件的核心，负责处理配置、调用 API 和与窗口模块交互。

```lua
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

  local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" .. config.api_key

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
```

#### **`plugin/gemini_talk.lua`** (命令设置)

这个文件确保我们的 `:GeminiTalk` 命令是可用的。

```lua
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
```

### 第 4 步：编写 `README.md` 文档

一个好的 `README.md` 是插件成功的关键。它应该清晰地说明如何安装、配置和使用。

````markdown
# gemini-talk.nvim

A Neovim plugin to have a conversation with Google's Gemini AI directly within a floating window.

![demo](https://user-images.githubusercontent.com/YOUR_USER_ID/YOUR_IMAGE_ID/gemini-talk-demo.png)
*(提示: 你可以截一张插件运行的图片并上传到 issue 中，然后在这里引用图片链接)*

## ✨ Features

*   **Conversational UI**: Chat with Gemini in a clean, floating window.
*   **Context-Aware**: The plugin remembers the conversation history for the current session.
*   **Simple**: Just one command `:GeminiTalk` to get started.
*   **Easy Setup**: Configure with a single line in your `lazy.nvim` setup.

## ⚠️ Requirements

*   Neovim >= 0.8
*   `curl` installed on your system.
*   A Google Gemini API key. You can get one from [Google AI Studio](https://makersuite.google.com/app/apikey).

## 📦 Installation

You can install this plugin using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- lazy.nvim configuration
{
  "YOUR_USERNAME/gemini-talk.nvim",
  cmd = "GeminiTalk",
  config = function()
    require("gemini-talk").setup({
      api_key = os.getenv("GEMINI_API_KEY"), -- Recommended: use an environment variable
    })
  end,
}
```

## ⚙️ Configuration

The `setup()` function accepts the following options:

*   `api_key` (string, **required**): Your Google Gemini API key. It is strongly recommended to load this from an environment variable for security.

### Example Configuration

Add the following to your Neovim configuration:

```lua
-- somewhere in your init.lua or a dedicated plugin file
require("lazy").setup({
  {
    "YOUR_USERNAME/gemini-talk.nvim",
    cmd = "GeminiTalk",
    config = function()
      require("gemini-talk").setup({
        -- Make sure to set this environment variable in your shell's config
        -- e.g., export GEMINI_API_KEY="your_secret_key" in ~/.zshrc
        api_key = os.getenv("GEMINI_API_KEY"),
      })
    end,
  },
})
```

## 🚀 Usage

1.  Set your API key using the `setup` function (see above).
2.  Run the command `:GeminiTalk` in Neovim.
3.  A floating window will appear. Type your question and press `<Enter>`.
4.  Gemini's response will appear in the window. You can continue the conversation.
5.  To close the window, simply switch to another window or use `:q`.

## 📄 License

MIT
````

### 第 5 步：发布和加载

1. **提交代码**: 将你创建的所有文件添加到 Git，并推送到 GitHub。

    ```bash
    git add .
    git commit -m "feat: initial implementation of gemini-talk"
    git push origin main
    ```

2. **获取 Gemini API Key**:
    * 访问 [Google AI Studio](https://makersuite.google.com/app/apikey)。
    * 点击 "Create API key" 并复制你的密钥。

3. **在你的 Neovim 配置中加载插件**:
    * 将你的 API 密钥设置为环境变量。例如，在你的 `~/.zshrc` 或 `~/.bashrc` 中添加：

        ```bash
        export GEMINI_API_KEY="YOUR_API_KEY_HERE"
        ```

        然后重新加载你的 shell (`source ~/.zshrc`)。

    * 打开你的 Neovim 配置文件 (例如 `init.lua`)，并使用 `lazy.nvim` 添加你的插件。记得将 `YOUR_USERNAME` 替换为你的 GitHub 用户名。

        ```lua
        -- lazy.nvim 用户
        require("lazy").setup({
          -- ... 其他插件
          {
            "YOUR_USERNAME/gemini-talk.nvim",
            cmd = "GeminiTalk", -- 优化启动：只在运行 :GeminiTalk 时加载
            config = function()
              require("gemini-talk").setup({
                api_key = os.getenv("GEMINI_API_KEY"),
              })
            end,
          },
          -- ... 其他插件
        })
        ```

4. **安装和测试**:
    * 重启 Neovim。`lazy.nvim` 应该会自动检测到新的插件并进行安装。
    * 运行 `:GeminiTalk` 命令。
    * 一个悬浮窗口应该会弹出。输入你的问题，按回车，你应该能看到 Gemini 的回复！

至此，你已经成功开发并发布了一个功能完整的 Neovim 插件，并通过 `lazy.nvim` 进行了加载和配置。
