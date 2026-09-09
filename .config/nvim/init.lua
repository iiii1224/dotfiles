-- Neovim starter configuration.
-- Keep this file small while learning the editor; add plugins only when you
-- know which problem they solve.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
vim.opt.termguicolors = true

-- Share Neovim's clipboard with the Windows clipboard under WSL.
if vim.fn.has("wsl") == 1
    and vim.fn.executable("clip.exe") == 1
    and vim.fn.executable("powershell.exe") == 1 then
  local paste_command = {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-Command",
    "$x = Get-Clipboard -Raw; if ($null -ne $x) { [Console]::Out.Write($x.Replace(\"`r\", \"\")) }",
  }

  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = paste_command,
      ["*"] = paste_command,
    },
    cache_enabled = 0,
  }

  vim.opt.clipboard = "unnamedplus"
end

-- Startup cost shown on the dashboard. lazy.nvim's own stats.startuptime is
-- still zero at VimEnter, when the dashboard is built, so the elapsed time is
-- measured here instead.
local start_time = vim.uv.hrtime()

require("lazy").setup({
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
  {
    -- Picker, and the image support its preview window uses. snacks.image
    -- talks the kitty graphics protocol directly, so previews are real
    -- pixels rather than the text approximation Telescope was limited to.
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      picker = {
        sources = {
          -- rg/fd skip dotfiles by default, which hides most of this repo.
          -- .git stays excluded by the source's own arguments.
          files = { hidden = true },
          grep = { hidden = true },
        },
      },
      image = { enabled = true },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "enter" },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = false } },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      for _, server in ipairs({ "pyright", "rust_analyzer", "marksman" }) do
        vim.lsp.enable(server)
      end
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<C-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
        -- One status line for the whole screen instead of one per window, so
        -- the mode block always sits in the same place.
        globalstatus = true,
      },
      sections = {
        -- Mode names differ in length (INSERT vs V-BLOCK), which would shift
        -- everything to their right on every mode change. Padding them to a
        -- fixed width leaves only the colour moving.
        lualine_a = {
          {
            "mode",
            fmt = function(name)
              local width = 9
              local pad = width - vim.fn.strchars(name)
              if pad <= 0 then
                return name
              end
              local left = math.floor(pad / 2)
              return string.rep(" ", left) .. name .. string.rep(" ", pad - left)
            end,
          },
        },
        lualine_b = { "diff" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics" },
        lualine_y = {
          function()
            local names = {}
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
              table.insert(names, client.name)
            end
            return table.concat(names, ",")
          end,
        },
        lualine_z = { "location" },
      },
      extensions = { "nvim-tree" },
    },
  },
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- Widest a recent-file entry may get. The doom theme pads every center
      -- entry out to the widest one before centring the block, so an
      -- unbounded path would drag the whole menu sideways.
      local max_desc_width = 46

      local function pad_right(str, width)
        return str .. (" "):rep(math.max(0, width - vim.fn.strdisplaywidth(str)))
      end

      -- Paths are cut from the left: the tail (the directory the file
      -- actually sits in) identifies an entry better than the root does.
      local function truncate_left(str, width)
        if vim.fn.strdisplaywidth(str) <= width then
          return str
        end
        for i = 1, vim.fn.strchars(str) do
          local tail = vim.fn.strcharpart(str, i)
          if vim.fn.strdisplaywidth(tail) + 1 <= width then
            return "…" .. tail
          end
        end
        return "…"
      end

      -- Directory halves of the recent-file entries, dimmed once the buffer
      -- is drawn. The doom theme highlights each description as a single
      -- run, so the two columns have to be split apart with extmarks.
      -- Each target carries the entry's whole rendered text and the byte
      -- range of the directory within it: matching on the directory alone
      -- would also hit the version string in the header and any file name
      -- that happens to contain the same characters.
      local dim_targets = {}

      -- The most recently edited files, newest first. v:oldfiles keeps entries
      -- for files that have since been deleted or moved, so unreadable paths
      -- are dropped rather than shown as dead menu items.
      local function recent_files(limit)
        local paths = {}
        for _, path in ipairs(vim.v.oldfiles or {}) do
          if vim.fn.filereadable(path) == 1 then
            table.insert(paths, path)
            if #paths == limit then
              break
            end
          end
        end

        -- File names share a column, so the directories line up too.
        local name_width = 0
        for _, path in ipairs(paths) do
          name_width = math.max(name_width, vim.fn.strdisplaywidth(vim.fs.basename(path)))
        end

        local devicons = require("nvim-web-devicons")
        local entries = {}
        for i, path in ipairs(paths) do
          local name = vim.fs.basename(path)
          local dir = truncate_left(
            vim.fn.fnamemodify(path, ":~:.:h"),
            max_desc_width - name_width - 2
          )
          local icon, icon_hl = devicons.get_icon(name, vim.fn.fnamemodify(name, ":e"), { default = true })
          local entry_icon = icon .. "  "
          local desc = pad_right(name, name_width) .. "  " .. dir
          table.insert(dim_targets, {
            text = entry_icon .. desc,
            offset = #entry_icon + #desc - #dir,
            len = #dir,
          })
          table.insert(entries, {
            icon = entry_icon,
            icon_hl = icon_hl,
            desc = desc,
            key = tostring(i),
            action = "edit " .. vim.fn.fnameescape(path),
          })
        end
        return entries
      end

      local center = {
        { icon = "󰈞  ", desc = "Find File", key = "f", action = function() Snacks.picker.files() end },
        { icon = "󱎸  ", desc = "Live Grep", key = "g", action = function() Snacks.picker.grep() end },
        { icon = "󰝒  ", desc = "New File", key = "n", action = "enew | startinsert" },
        { icon = "󰒓  ", desc = "Config", key = "c", action = "edit " .. vim.fn.stdpath("config") .. "/init.lua" },
        -- Heading for the entries below as much as an action of its own: the
        -- doom theme derives its highlight mapping by counting rendered lines
        -- that contain a word character, so a rule or blank spacer entry
        -- would shift that mapping and break the draw. [r] opens the picker
        -- over every recent file; [1]..[5] jump straight to one.
        { icon = "󰋚  ", desc = "Recent Files", key = "r", action = function() Snacks.picker.recent() end },
      }

      vim.list_extend(center, recent_files(5))

      local elapsed_ms = (vim.uv.hrtime() - start_time) / 1e6

      require("dashboard").setup({
        theme = "doom",
        config = {
          -- The N mark Neovim draws on its own :intro screen.
          header = {
            "",
            "",
            "│ ╲ ││",
            "││╲╲││",
            "││ ╲ │",
            "",
            "NVIM v" .. table.concat({ vim.version().major, vim.version().minor, vim.version().patch }, "."),
            "",
            "",
          },
          center = center,
          footer = {
            "",
            ("⚡ %d plugins loaded in %.0fms"):format(require("lazy").stats().loaded, elapsed_ms),
          },
        },
      })

      -- dashboard-nvim highlights the header a line at a time, but the real
      -- :intro mark uses one colour for the uprights and another for the
      -- diagonal. Extmarks are placed per character once the buffer is drawn.
      local mark_ns = vim.api.nvim_create_namespace("dashboard_nvim_mark")
      local mark_colors = { ["│"] = "DiagnosticOk", ["╲"] = "Directory" }

      -- DashboardLoaded rather than FileType: the theme rewrites the buffer
      -- as it draws, which would drop extmarks placed any earlier.
      vim.api.nvim_create_autocmd("User", {
        pattern = "DashboardLoaded",
        callback = function()
          local buf = vim.api.nvim_get_current_buf()
          if vim.bo[buf].filetype ~= "dashboard" then
            return
          end
          -- The mark sits in the header, so only the top of the buffer is
          -- scanned; nothing below it should be recoloured.
          for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 10, false)) do
            for char, hl in pairs(mark_colors) do
              local from = 1
              while true do
                local col = line:find(char, from, true)
                if not col then
                  break
                end
                vim.api.nvim_buf_set_extmark(buf, mark_ns, lnum - 1, col - 1, {
                  end_col = col - 1 + #char,
                  hl_group = hl,
                  -- Above the 4096 that dashboard-nvim's own header
                  -- highlight is placed at, so the mark keeps its colours.
                  priority = 5000,
                })
                from = col + #char
              end
            end
          end

          -- Second pass, over the menu: the directory column is pushed back
          -- so the file names carry the line. Only the leading indent varies
          -- between the entry as built and the entry as drawn, so locating
          -- the whole entry gives the directory's position within the line.
          for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            for _, target in ipairs(dim_targets) do
              local at = line:find(target.text, 1, true)
              if at then
                local col = at - 1 + target.offset
                vim.api.nvim_buf_set_extmark(buf, mark_ns, lnum - 1, col, {
                  end_col = col + target.len,
                  hl_group = "Comment",
                  priority = 5000,
                })
                break
              end
            end
          end
        end,
      })
    end,
  },
})

-- Keep syntax highlighting enabled for every file. Treesitter is used when a
-- parser is available; Neovim's built-in syntax highlighting remains the
-- fallback for filetypes without an installed parser.
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local function bufmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    bufmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
    bufmap("n", "K", vim.lsp.buf.hover, "Show documentation")
    bufmap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    bufmap({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
  end,
})

local opt = vim.opt

-- Display and navigation
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.mouse = "a"
opt.splitbelow = true
opt.splitright = true

-- Editing
opt.expandtab = true
opt.shiftwidth = 2
opt.softtabstop = 2
opt.tabstop = 2
opt.breakindent = true
opt.smartindent = true

-- Search and completion
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.completeopt = { "menuone", "noselect" }

-- Persistent undo and sensible defaults
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.confirm = true

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

local undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir, "p")
opt.undodir = undo_dir

local map = vim.keymap.set
local opts = { silent = true }

local function project_root()
  return vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
end

-- The space key is the leader: <leader>w means Space, then w.
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "File explorer" })
map("n", "<leader>ff", function() Snacks.picker.files({ cwd = project_root() }) end, { desc = "Find files" })
map("n", "<leader>rg", function() Snacks.picker.grep() end, { desc = "Live grep" })
map("n", "<leader>fb", function() Snacks.picker.buffers() end, { desc = "Find buffers" })
map("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent files" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Move between splits without reaching for Ctrl-w first.
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Plain letters are held by the Windows IME while it is composing, so jk can
-- only work when the IME is already off. Ctrl-j provides the same escape path
-- with a control key that the terminal can deliver while the IME is active.
map("i", "jk", "<Esc>")
map("i", "<C-j>", "<Esc>", { desc = "Leave insert mode while IME is active" })

-- Windows owns the IME used by WSL terminals. A tiny Windows helper on PATH
-- switches it to direct (half-width alphanumeric) input whenever Neovim
-- returns to normal mode. Other platforms and machines without the helper
-- simply skip this integration.
local ime_off = vim.fn.exepath("ime-off.exe")
if ime_off ~= "" then
  vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = "*:n",
    callback = function()
      vim.system({ ime_off }, { stdout = false, stderr = false }, function() end)
    end,
    desc = "Turn off the Windows IME in normal mode",
  })
end

-- Keep the cursor centered while scrolling and searching.
map("n", "<C-d>", "<C-d>zz", opts)
map("n", "<C-u>", "<C-u>zz", opts)
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)

-- Use the current working directory for :find and :Explore.
vim.cmd([[autocmd BufEnter * silent! lcd %:p:h]])

-- Relative line numbers only where they are useful: they help count motions
-- (3j, 5dd) in normal mode, but flicker distractingly while typing and are
-- meaningless in a window you are not moving around in. Windows that turned
-- 'number' off entirely (nvim-tree, pickers) are left alone.
local relnu = vim.api.nvim_create_augroup("relative_number_in_normal_mode", {})

vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter", "WinEnter", "FocusGained" }, {
  group = relnu,
  callback = function()
    if vim.wo.number and vim.api.nvim_get_mode().mode ~= "i" then
      vim.wo.relativenumber = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave", "FocusLost" }, {
  group = relnu,
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end,
})

-- Reopen files at the cursor position from the previous session.
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line = mark[1]
    if line < 1 or line > vim.api.nvim_buf_line_count(args.buf) then
      return
    end

    local text = vim.api.nvim_buf_get_lines(args.buf, line - 1, line, false)[1] or ""
    vim.api.nvim_win_set_cursor(0, { line, math.min(mark[2], #text) })
  end,
})
