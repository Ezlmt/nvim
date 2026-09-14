--- Code review comments and line annotations manager (Parity with Cider-J CommentsManager).
local config = require("jetski.config")
local workspace = require("jetski.workspace")

local M = {}

--- Namespace for comment signs and virtual text
local ns_id = vim.api.nvim_create_namespace("jetski_comments")

--- In-memory store of comments:
--- M.comments[file_abs_path][start_line] = {
---   file = string,
---   line = number,
---   end_line = number,
---   comment = string,
---   selection = string,
--- }
M.comments = {}

--- Defines sign and highlight groups for comment indicators
function M.setup_highlights()
  local opts = config.get().comments
  vim.cmd(string.format([[
    highlight default link JetskiCommentSign %s
    highlight default link JetskiCommentVirtualText %s
  ]], opts.sign_hl or "DiagnosticInfo", opts.virtual_text_hl or "Comment"))

  pcall(vim.fn.sign_define, "JetskiCommentSign", {
    text = opts.sign or "💬",
    texthl = "JetskiCommentSign",
  })
end

--- Places or updates the gutter sign and virtual text for a commented line.
---@param bufnr number
---@param line number 1-indexed line number
---@param text string Comment text
function M.update_indicator(bufnr, line, text)
  local opts = config.get().comments
  local summary = text:match("^[^\r\n]+") or text
  if #summary > 50 then
    summary = summary:sub(1, 47) .. "..."
  end

  local extmark_opts = {
    sign_text = opts.sign or "💬",
    sign_hl_group = "JetskiCommentSign",
  }

  if opts.virtual_text then
    extmark_opts.virt_text = { { " " .. (opts.sign or "💬") .. " [" .. summary .. "]", "JetskiCommentVirtualText" } }
    extmark_opts.virt_text_pos = "eol"
  end

  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line - 1, 0, extmark_opts)
end

--- Removes indicators for a given line.
---@param bufnr number
---@param line number 1-indexed line number
function M.remove_indicator(bufnr, line)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, line - 1, line)
end

--- Redraws indicators for all buffers currently loaded.
function M.refresh_all_indicators()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
      if M.comments[path] then
        for line, entry in pairs(M.comments[path]) do
          M.update_indicator(bufnr, line, entry.comment)
        end
      end
    end
  end
end

--- Opens a floating window to add or edit a comment on a line or selection range.
---@param start_line? number 1-indexed start line (defaults to cursor)
---@param end_line? number 1-indexed end line (defaults to start_line)
---@param auto_submit? boolean If true, submits immediately upon closing
function M.add_comment(start_line, end_line, auto_submit)
  M.setup_highlights()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_info = workspace.get_active_file_info()

  if not file_info.is_named then
    vim.notify("[Jetski] Cannot add comment to an unnamed buffer", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  start_line = start_line or cursor[1]
  end_line = end_line or start_line
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  -- Capture code snippet
  local code_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local code_snippet = table.concat(code_lines, "\n")

  -- Check for existing comment
  local existing_text = ""
  local filepath = file_info.abs_path
  if M.comments[filepath] and M.comments[filepath][start_line] then
    existing_text = M.comments[filepath][start_line].comment
  end

  -- Create floating buffer
  local float_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[float_buf].buftype = "nofile"
  vim.bo[float_buf].bufhidden = "wipe"
  vim.bo[float_buf].filetype = "markdown"

  if existing_text ~= "" then
    local split_lines = vim.split(existing_text, "\n")
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, split_lines)
  end

  local width = math.min(75, math.floor(vim.o.columns * 0.7))
  local height = 5

  local range_str = start_line == end_line and string.format("line %d", start_line) or string.format("lines %d-%d", start_line, end_line)
  local title_str = string.format(" Jetski Comment (%s: %s) ", file_info.filename, range_str)

  local win_opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = config.get().comments.float_border or "rounded",
    title = title_str,
    title_pos = "center",
  }

  local float_win = vim.api.nvim_open_win(float_buf, true, win_opts)
  vim.wo[float_win].wrap = true
  vim.wo[float_win].linebreak = true
  vim.wo[float_win].cursorline = true

  if existing_text == "" then
    vim.cmd("startinsert!")
  end

  local saved = false
  local function save_and_close()
    if saved then return end
    saved = true

    local lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
    local comment_text = vim.trim(table.concat(lines, "\n"))

    if comment_text ~= "" then
      if not M.comments[filepath] then
        M.comments[filepath] = {}
      end
      M.comments[filepath][start_line] = {
        file = filepath,
        display_path = file_info.relative_path ~= "" and file_info.relative_path or file_info.filename,
        line = start_line,
        end_line = end_line,
        comment = comment_text,
        selection = code_snippet,
      }
      M.update_indicator(bufnr, start_line, comment_text)

      if auto_submit then
        local terminal = require("jetski.terminal")
        local payload = M.format_comments_payload({ M.comments[filepath][start_line] })
        terminal.send_prompt(payload)
        M.comments[filepath][start_line] = nil
        M.remove_indicator(bufnr, start_line)
        vim.notify("[Jetski] Comment submitted to agent", vim.log.levels.INFO)
      else
        vim.notify(string.format("[Jetski] Comment saved for %s", range_str), vim.log.levels.INFO)
      end
    else
      if M.comments[filepath] and M.comments[filepath][start_line] then
        M.comments[filepath][start_line] = nil
        M.remove_indicator(bufnr, start_line)
        vim.notify("[Jetski] Comment deleted", vim.log.levels.INFO)
      end
    end

    if vim.api.nvim_win_is_valid(float_win) then
      vim.api.nvim_win_close(float_win, true)
    end
  end

  -- Auto-save on WinLeave
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = float_buf,
    once = true,
    callback = save_and_close,
  })

  -- Keymaps to save and close
  vim.keymap.set("n", "<CR>", save_and_close, { buffer = float_buf, silent = true, desc = "Save Jetski comment" })
  vim.keymap.set("n", "<C-s>", save_and_close, { buffer = float_buf, silent = true, desc = "Save Jetski comment" })
  vim.keymap.set("i", "<C-s>", function()
    vim.cmd("stopinsert")
    save_and_close()
  end, { buffer = float_buf, silent = true, desc = "Save Jetski comment" })
  vim.keymap.set("n", "<Esc>", save_and_close, { buffer = float_buf, silent = true, desc = "Save and close Jetski comment" })
  vim.keymap.set("n", "q", save_and_close, { buffer = float_buf, silent = true, desc = "Save and close Jetski comment" })
end

--- Adds a comment on the current visual selection range.
function M.add_visual_comment()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  -- Exit visual mode cleanly
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.schedule(function()
    M.add_comment(start_line, end_line, false)
  end)
end

--- Deletes comment on the current cursor line.
function M.delete_comment()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
  local line = vim.api.nvim_win_get_cursor(0)[1]

  if M.comments[filepath] and M.comments[filepath][line] then
    M.comments[filepath][line] = nil
    M.remove_indicator(bufnr, line)
    vim.notify("[Jetski] Comment deleted", vim.log.levels.INFO)
  else
    vim.notify("[Jetski] No comment on current line", vim.log.levels.WARN)
  end
end

--- Clears all stored comments and removes indicators across all buffers.
function M.clear_all_comments()
  M.comments = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
    end
  end
  vim.notify("[Jetski] Cleared all comments", vim.log.levels.INFO)
end

--- Returns a flat list of all pending comments across all files.
---@return table
function M.get_all_comments()
  local list = {}
  for filepath, lines in pairs(M.comments) do
    for _, entry in pairs(lines) do
      table.insert(list, entry)
    end
  end
  table.sort(list, function(a, b)
    if a.file == b.file then
      return a.line < b.line
    end
    return a.file < b.file
  end)
  return list
end

--- Opens a Quickfix list with all pending comments.
function M.list_comments()
  local all = M.get_all_comments()
  if #all == 0 then
    vim.notify("[Jetski] No pending comments found", vim.log.levels.INFO)
    return
  end

  local qf_items = {}
  for _, entry in ipairs(all) do
    local first_line = entry.comment:match("^[^\r\n]+") or entry.comment
    table.insert(qf_items, {
      filename = entry.file,
      lnum = entry.line,
      col = 1,
      text = string.format("[Jetski Comment] %s", first_line),
    })
  end

  vim.fn.setqflist(qf_items, "r")
  vim.fn.setqflist({}, "a", { title = "Jetski Pending Comments" })
  vim.cmd("copen")
end

--- Formats comments into JSON structure expected by the agent.
---@param comments_list table
---@return string
function M.format_comments_payload(comments_list)
  local data = {}
  for _, c in ipairs(comments_list) do
    table.insert(data, {
      file = c.file,
      display_path = c.display_path,
      line = c.line,
      end_line = c.end_line,
      comment = c.comment,
      selection = c.selection,
    })
  end
  return string.format("Please address the following code review comments:\n```json\n%s\n```", vim.fn.json_encode(data))
end

--- Submits all pending comments across all files to the Jetski session.
function M.submit_all_comments()
  local all = M.get_all_comments()
  if #all == 0 then
    vim.notify("[Jetski] No pending comments to submit", vim.log.levels.WARN)
    return
  end

  local payload = M.format_comments_payload(all)
  local terminal = require("jetski.terminal")

  if terminal.is_open() then
    terminal.send_prompt(payload)
  else
    terminal.open({ prompt = payload })
  end

  if config.get().comments.auto_clear_on_submit then
    M.clear_all_comments()
  end

  vim.notify(string.format("[Jetski] Submitted %d comment(s) to agent", #all), vim.log.levels.INFO)
end

return M
