# gemini-talk.nvim

A Neovim plugin to have a conversation with Google's Gemini AI directly within a floating window.

![demo](https://user-images.githubusercontent.com/YOUR_USER_ID/YOUR_IMAGE_ID/gemini-talk-demo.png)
*(提示: 你可以截一张插件运行的图片并上传到 issue 中，然后在这里引用图片链接)*

## ✨ Features

* **Conversational UI**: Chat with Gemini in a clean, floating window.
* **Context-Aware**: The plugin remembers the conversation history for the current session.
* **Simple**: Just one command `:GeminiTalk` to get started.
* **Easy Setup**: Configure with a single line in your `lazy.nvim` setup.

## ⚠️ Requirements

* Neovim >= 0.8
* `curl` installed on your system.
* A Google Gemini API key. You can get one from [Google AI Studio](https://makersuite.google.com/app/apikey).

## 📦 Installation

You can install this plugin using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- lazy.nvim configuration
{
  "clearzero22/gemini-talk.nvim",
  cmd = "GeminiTalk",
  config = function()
    require("gemini-talk").setup({
      api_key = os.getenv("AIzaSyAIm05vPJ1Nan1FAlcWd86yO4eMohjjVdY"), -- Recommended: use an environment variable
    })
  end,
}
```

## ⚙️ Configuration

The `setup()` function accepts the following options:

* `api_key` (string, **required**): Your Google Gemini API key. It is strongly recommended to load this from an environment variable for security.

### Example Configuration

Add the following to your Neovim configuration:

```lua
-- somewhere in your init.lua or a dedicated plugin file
require("lazy").setup({
  {
    "YOUR_USERNAME/gemini-talk.nvim",
    cmd = "GeminiTalk",
    config = function() {
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

1. Set your API key using the `setup` function (see above).
2. Run the command `:GeminiTalk` in Neovim.
3. A floating window will appear. Type your question and press `<Enter>`.
4. Gemini's response will appear in the window. You can continue the conversation.
5. To close the window, simply switch to another window or use `:q`.

## 📄 License

MIT
