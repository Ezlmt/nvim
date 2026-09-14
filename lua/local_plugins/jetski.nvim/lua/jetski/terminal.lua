--- Terminal window and process manager for Jetski CLI.
local config = require("jetski.config")
local workspace = require("jetski.workspace")

local M = {}

--- State tracking
M.term_buf = nil
M.term_win = nil
M.term_chan = nil
M.is_running = false

--- Checks if terminal window is currently open and valid.
---@return boolean
function M.is_open()
  return M.term_win ~= nil
    and vim.api.nvim_win_is_valid(M.term_win)
    and M.term_buf ~= nil
    and vim.api.nvim_win_get_buf(M.term_win) == M.term_buf
end

--- Checks if terminal process is active.
---@return boolean
function M.is_active()
  return M.is_running and M.term_chan ~= nil
end

--- Closes the terminal window without killing the background process.
function M.close_window()
  if M.is_open() then
    pcall(vim.api.nvim_win_close, M.term_win, true)
    M.term_win = nil
  end
end

--- Creates the window according to user layout settings and attaches the specified buffer.
---@param buf number Buffer to display in the new window
---@return number Window ID
function M.create_window(buf)
  local opts = config.get()
  local mode = opts.open_mode or "vertical"

  if mode == "float" then
    local float_opts = opts.float or {}
    local width_ratio = float_opts.width or 0.85
    local height_ratio = float_opts.height or 0.85
    local width = math.floor(vim.o.columns * width_ratio)
    local height = math.floor(vim.o.lines * height_ratio)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      border = float_opts.border or "rounded",
      title = float_opts.title or " Jetski Agent ",
      title_pos = "center",
    })
    return win
  elseif mode == "horizontal" then
    local h_opts = opts.horizontal or {}
    local height = h_opts.height or 0.38
    local split_cmd = (h_opts.side == "above") and "topleft split" or "botright split"
    vim.cmd(split_cmd)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    if type(height) == "number" and height < 1 then
      vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * height))
    elseif type(height) == "number" then
      vim.api.nvim_win_set_height(win, height)
    end
    return win
  elseif mode == "tab" then
    vim.cmd("tabnew")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    return win
  elseif mode == "replace" then
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    return win
  else
    -- Default: vertical
    local v_opts = opts.vertical or {}
    local width = v_opts.width or 0.45
    local split_cmd = (v_opts.side == "left") and "topleft vsplit" or "botright vsplit"
    vim.cmd(split_cmd)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    if type(width) == "number" and width < 1 then
      vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * width))
    elseif type(width) == "number" then
      vim.api.nvim_win_set_width(win, width)
    end
    return win
  end
end

--- Builds the command line string or arguments table to launch the CLI.
---@param options? table
---@return string Command line string
function M.build_command(options)
  options = options or {}
  local cfg = config.get()
  local cmd = cfg.cmd

  local args = {}

  -- CitC / Workspace detection
  local ws = workspace.detect_workspace()
  if ws.is_google3 and ws.workspace_root then
    table.insert(args, string.format("--add-dir=%s", vim.fn.shellescape(ws.workspace_root)))
  end

  if cfg.model and cfg.model ~= "" then
    table.insert(args, string.format("--model=%s", vim.fn.shellescape(cfg.model)))
  end

  if cfg.agent and cfg.agent ~= "" then
    table.insert(args, string.format("--agent=%s", vim.fn.shellescape(cfg.agent)))
  end

  if cfg.effort and cfg.effort ~= "" then
    table.insert(args, string.format("--effort=%s", vim.fn.shellescape(cfg.effort)))
  end

  if options.continue_session then
    table.insert(args, "--continue")
  end

  local prompt = options.prompt
  if not prompt and cfg.skill_prompt and not options.continue_session then
    prompt = "Make sure to use the nvim skill to interact with the active Neovim editor. " ..
             "Whenever displaying plans, walkthroughs, or files, open them directly in Neovim using the skill commands."
  end

  if prompt and prompt ~= "" then
    table.insert(args, string.format("--prompt-interactive=%s", vim.fn.shellescape(prompt)))
  end

  local full_cmd = cmd
  if #args > 0 then
    full_cmd = full_cmd .. " " .. table.concat(args, " ")
  end
  return full_cmd
end

--- Starts the Jetski process in a hidden background buffer without opening a window.
---@param options? table { prompt = string, continue_session = boolean }
function M.preload(options)
  if M.is_active() then
    return
  end

  options = options or {}

  if options.prompt and options.prompt ~= "" then
    pcall(function()
      require("jetski.diff").snapshot_open_buffers()
    end)
  end

  -- Create a dedicated unlisted scratch buffer for the terminal
  M.term_buf = vim.api.nvim_create_buf(false, true)

  local cmd = M.build_command(options)

  -- Pass NVIM server address in environment for child process
  local nvim_server = vim.v.servername
  if nvim_server and nvim_server ~= "" then
    vim.fn.setenv("NVIM", nvim_server)
  end

  M.is_running = true

  vim.api.nvim_buf_call(M.term_buf, function()
    M.term_chan = vim.fn.termopen(cmd, {
      on_exit = function(_, exit_code, _)
        M.is_running = false
        M.term_chan = nil
        if exit_code ~= 0 and exit_code ~= 130 and exit_code ~= 143 then
          vim.notify(string.format("[Jetski] Process exited with code %d", exit_code), vim.log.levels.WARN)
        end

        local cfg = config.get()
        if cfg.auto_close then
          vim.schedule(function()
            M.close_window()
            if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
              pcall(vim.api.nvim_buf_delete, M.term_buf, { force = true })
              M.term_buf = nil
            end
          end)
        end
      end,
    })
  end)

  -- Configure buffer options
  vim.bo[M.term_buf].syntax = "off"
  vim.bo[M.term_buf].filetype = "jetski"
  pcall(vim.api.nvim_buf_set_name, M.term_buf, "jetski://session")

  -- Clean up state on buffer deletion
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    buffer = M.term_buf,
    once = true,
    callback = function()
      M.is_running = false
      M.term_chan = nil
      M.term_buf = nil
      M.term_win = nil
    end,
  })

  -- Map <Esc><Esc> to exit terminal mode without clashing with CLI single <Esc>
  if config.get().terminal.escape_key then
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = M.term_buf, silent = true, desc = "Exit terminal mode" })
    vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = M.term_buf, silent = true, desc = "Send Escape to CLI" })
  end
end

--- Opens the Jetski terminal window and starts or attaches to the session.
---@param options? table { prompt = string, continue_session = boolean, new_session = boolean }
function M.open(options)
  options = options or {}

  -- If window already open and valid, focus it
  if M.is_open() then
    vim.api.nvim_set_current_win(M.term_win)
    if config.get().terminal.auto_insert then
      vim.cmd("startinsert")
    end
    if options.prompt and options.prompt ~= "" then
      M.send_prompt(options.prompt)
    end
    return
  end

  -- If requesting a new session and one is already active, kill the old one
  if options.new_session and M.is_active() then
    M.kill()
  end

  -- If buffer exists and process is still running, just reveal it in a new window
  if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) and M.is_active() then
    M.term_win = M.create_window(M.term_buf)
    if config.get().terminal.auto_insert then
      vim.cmd("startinsert")
    end
    if options.prompt and options.prompt ~= "" then
      M.send_prompt(options.prompt)
    end
    return
  end

  -- Start new session in background buffer first
  M.preload(options)

  -- Now reveal in window
  M.term_win = M.create_window(M.term_buf)

  if config.get().terminal.auto_insert then
    vim.cmd("startinsert")
  end
end

--- Toggles terminal window visibility.
function M.toggle()
  if M.is_open() then
    M.close_window()
  else
    M.open()
  end
end

--- Sends raw prompt string into the active terminal channel.
---@param text string Prompt text
function M.send_prompt(text)
  -- Snapshot open buffers before agent modifies them
  pcall(function()
    require("jetski.diff").snapshot_open_buffers()
  end)

  if not M.term_chan or not M.is_active() then
    M.open({ prompt = text })
    return
  end

  -- If window not visible, open it
  if not M.is_open() then
    M.open()
  end

  -- Send text followed by carriage return
  vim.fn.chansend(M.term_chan, text .. "\r")
end

--- Kills the active process and wipes the terminal buffer.
---@param silent? boolean If true, suppress user notification
function M.kill(silent)
  if M.term_chan then
    pcall(vim.fn.jobstop, M.term_chan)
    M.term_chan = nil
  end
  M.is_running = false
  M.close_window()
  if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
    pcall(vim.api.nvim_buf_delete, M.term_buf, { force = true })
    M.term_buf = nil
  end
  if not silent then
    vim.notify("[Jetski] Session terminated", vim.log.levels.INFO)
  end
end

--- Finds an editor window (one not containing the terminal or special Jetski scratch buffers).
---@return number|nil Window ID
function M.find_editor_window()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(current_tab)

  -- First pass: prioritize normal file buffers not in diff mode
  for _, win in ipairs(wins) do
    if win ~= M.term_win and not vim.wo[win].diff then
      local buf = vim.api.nvim_win_get_buf(win)
      if buf ~= M.term_buf then
        local buftype = vim.bo[buf].buftype
        local bufname = vim.api.nvim_buf_get_name(buf)
        if buftype == "" and not bufname:find("^jetski://") then
          return win
        end
      end
    end
  end

  -- Second pass: any non-terminal, non-diff, non-jetski window
  for _, win in ipairs(wins) do
    if win ~= M.term_win and not vim.wo[win].diff then
      local buf = vim.api.nvim_win_get_buf(win)
      if buf ~= M.term_buf then
        local bufname = vim.api.nvim_buf_get_name(buf)
        if not bufname:find("^jetski://") then
          return win
        end
      end
    end
  end
  return nil
end

--- Opens a file at a specific line and column in an editor window.
--- Exposed for Neovim RPC: require('jetski').open_file(filepath, line, col)
---@param filepath string File to open
---@param line? number Line number (1-indexed)
---@param col? number Column number (1-indexed)
function M.open_file(filepath, line, col)
  if not filepath or filepath == "" then return end
  filepath = workspace.normalize_path(filepath)

  -- Close active diff review if one is currently open so open_file does not clash
  local ok_diff, diff_mod = pcall(require, "jetski.diff")
  if ok_diff and diff_mod.active_diff then
    diff_mod.close_diff_review()
  end

  local edit_win = M.find_editor_window()
  if not edit_win then
    -- If only terminal window is open, split above
    vim.cmd("aboveleft split")
    edit_win = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(edit_win)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(filepath))

  if line and tonumber(line) then
    line = tonumber(line)
    col = (col and tonumber(col)) or 1
    pcall(vim.api.nvim_win_set_cursor, edit_win, { line, col - 1 })
  end
end

--- Opens multiple files across splits.
--- Exposed for Neovim RPC: require('jetski').open_files(list)
---@param files table Array of filepaths
function M.open_files(files)
  if not files or #files == 0 then return end
  M.open_file(files[1])
  for i = 2, #files do
    local f = workspace.normalize_path(files[i])
    vim.cmd("vsplit " .. vim.fn.fnameescape(f))
  end
end

return M
