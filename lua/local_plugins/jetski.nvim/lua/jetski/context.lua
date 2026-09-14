--- Editor context extraction and prompt generation (Editor -> Jetski).
local workspace = require("jetski.workspace")
local config = require("jetski.config")

local M = {}

--- Extracts visual selection text and range information.
---@return table|nil Selection data or nil if no active selection
function M.get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_info = workspace.get_active_file_info()

  -- Use marks '< and '> if not in visual mode, or line('.') and line('v')
  local mode = vim.fn.mode()
  local is_visual = mode:find("[vV\22]") ~= nil

  local start_pos, end_pos
  if is_visual then
    start_pos = vim.fn.getpos("v")
    end_pos = vim.fn.getpos(".")
  else
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  end

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  -- Normalize so start_line <= end_line
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  if start_line == 0 or end_line == 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if #lines == 0 then
    return nil
  end

  -- Truncate partial columns if in characterwise visual mode
  if mode == "v" or not is_visual then
    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_col, end_col)
    else
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end

  local text = table.concat(lines, "\n")
  local display_path = file_info.relative_path ~= "" and file_info.relative_path or file_info.filename

  return {
    bufnr = bufnr,
    file = file_info.abs_path,
    display_path = display_path,
    start_line = start_line,
    end_line = end_line,
    text = text,
    filetype = file_info.filetype,
  }
end

--- Gets current cursor line context or visual selection.
---@return table
function M.get_current_context()
  local selection = M.get_visual_selection()
  if selection and selection.text ~= "" then
    return selection
  end

  local file_info = workspace.get_active_file_info()
  local line_content = ""
  if file_info.is_named and file_info.line <= file_info.total_lines then
    line_content = vim.api.nvim_buf_get_lines(file_info.bufnr, file_info.line - 1, file_info.line, false)[1] or ""
  end

  local display_path = file_info.relative_path ~= "" and file_info.relative_path or file_info.filename
  return {
    bufnr = file_info.bufnr,
    file = file_info.abs_path,
    display_path = display_path,
    start_line = file_info.line,
    end_line = file_info.line,
    text = line_content,
    filetype = file_info.filetype,
  }
end

local severity_names = {
  [vim.diagnostic.severity.ERROR] = "ERROR",
  [vim.diagnostic.severity.WARN] = "WARN",
  [vim.diagnostic.severity.INFO] = "INFO",
  [vim.diagnostic.severity.HINT] = "HINT",
}

--- Retrieves diagnostics from buffer and formats them into a clean string.
---@param bufnr? number Buffer number (defaults to current buffer)
---@param line_only? boolean If true, only fetch diagnostics for the current cursor line
---@return table { count = number, formatted = string, items = table }
function M.get_diagnostics(bufnr, line_only)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  local filter = { lnum = line_only and cursor_line or nil }
  local diags = vim.diagnostic.get(bufnr, filter)

  local formatted_lines = {}
  local items = {}

  for _, diag in ipairs(diags) do
    local sev = severity_names[diag.severity] or "INFO"
    local lnum = diag.lnum + 1
    local col = diag.col + 1
    local source = diag.source or "LSP"
    local code = diag.code and string.format(" [%s]", tostring(diag.code)) or ""
    local msg = string.format("Line %d:%d [%s] (%s%s): %s", lnum, col, sev, source, code, diag.message)
    table.insert(formatted_lines, msg)
    table.insert(items, {
      line = lnum,
      col = col,
      severity = sev,
      source = source,
      message = diag.message,
    })
  end

  return {
    count = #diags,
    formatted = table.concat(formatted_lines, "\n"),
    items = items,
  }
end

--- Builds an Explain prompt for current selection or cursor context.
---@return string
function M.build_explain_prompt()
  local ctx = M.get_current_context()
  local tpl = config.get().prompt_templates.explain
  return string.format(tpl, ctx.display_path, ctx.start_line, ctx.end_line, ctx.filetype, ctx.text)
end

--- Builds a Refactor prompt with optional user instruction.
---@param instruction? string Custom instruction (e.g. "Optimize performance", "Modernize")
---@return string
function M.build_refactor_prompt(instruction)
  local ctx = M.get_current_context()
  local tpl = config.get().prompt_templates.refactor
  local prompt = string.format(tpl, ctx.display_path, ctx.start_line, ctx.end_line, ctx.filetype, ctx.text)
  if instruction and instruction ~= "" then
    prompt = prompt .. "\n\nSpecific Guidance:\n" .. instruction
  end
  return prompt
end

--- Builds a Unit Test prompt for current selection or function.
---@return string
function M.build_test_prompt()
  local ctx = M.get_current_context()
  local tpl = config.get().prompt_templates.test
  return string.format(tpl, ctx.display_path, ctx.start_line, ctx.end_line, ctx.filetype, ctx.text)
end

--- Builds a Fix Diagnostics prompt from compiler / LSP / Tricorder errors.
---@param line_only? boolean If true, fix only cursor line diagnostics
---@return string|nil Formatted prompt or nil if no diagnostics found
function M.build_fix_prompt(line_only)
  local file_info = workspace.get_active_file_info()
  local diag_res = M.get_diagnostics(file_info.bufnr, line_only)

  if diag_res.count == 0 then
    return nil
  end

  local display_path = file_info.relative_path ~= "" and file_info.relative_path or file_info.filename

  -- Extract surrounding code around the errors
  local min_line = 1
  local max_line = file_info.total_lines
  if line_only then
    min_line = math.max(1, file_info.line - 10)
    max_line = math.min(file_info.total_lines, file_info.line + 10)
  else
    -- Find lowest and highest diagnostic lines
    local low = file_info.total_lines
    local high = 1
    for _, item in ipairs(diag_res.items) do
      if item.line < low then low = item.line end
      if item.line > high then high = item.line end
    end
    min_line = math.max(1, low - 5)
    max_line = math.min(file_info.total_lines, high + 5)
  end

  local surrounding_lines = vim.api.nvim_buf_get_lines(file_info.bufnr, min_line - 1, max_line, false)
  local surrounding_text = table.concat(surrounding_lines, "\n")

  local tpl = config.get().prompt_templates.fix
  return string.format(tpl, display_path, diag_res.formatted, file_info.filetype, surrounding_text)
end

--- Formats a general question with attached context snippet.
---@param user_query string User question
---@return string
function M.build_ask_prompt(user_query)
  local ctx = M.get_current_context()
  if ctx.text ~= "" then
    return string.format(
      "%s\n\nContext from `%s` (lines %d-%d):\n```%s\n%s\n```",
      user_query,
      ctx.display_path,
      ctx.start_line,
      ctx.end_line,
      ctx.filetype,
      ctx.text
    )
  else
    return user_query
  end
end

return M
