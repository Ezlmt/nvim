--- Artifact browser and viewer (Parity with Cider-J Artifact Viewer).
local workspace = require("jetski.workspace")

local M = {}

--- Returns the base brain/artifacts directory for the active user.
---@return string
function M.get_brain_dir()
  local home = os.getenv("HOME") or vim.fn.expand("~")
  return home .. "/.gemini/jetski/brain"
end

--- Locates the most recently modified conversation directory.
---@return string|nil
function M.get_latest_conversation_dir()
  local brain_dir = M.get_brain_dir()
  if vim.fn.isdirectory(brain_dir) == 0 then
    return nil
  end

  local handle = vim.uv.fs_scandir(brain_dir)
  if not handle then
    return nil
  end

  local latest_dir = nil
  local latest_mtime = 0

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if type == "directory" and not name:match("^%.") then
      local full_path = brain_dir .. "/" .. name
      local stat = vim.uv.fs_stat(full_path)
      if stat and stat.mtime and stat.mtime.sec > latest_mtime then
        latest_mtime = stat.mtime.sec
        latest_dir = full_path
      end
    end
  end

  return latest_dir
end

--- Scans a directory recursively for artifact files (.md, .txt, .json, .html).
---@param dir string Directory path
---@param max_depth? number
---@return table Array of file paths
function M.find_artifacts_in_dir(dir, max_depth)
  max_depth = max_depth or 3
  local results = {}

  local function scan(current_dir, depth)
    if depth > max_depth then return end
    local handle = vim.uv.fs_scandir(current_dir)
    if not handle then return end

    while true do
      local name, type = vim.uv.fs_scandir_next(handle)
      if not name then break end

      local full = current_dir .. "/" .. name
      if type == "directory" and not name:match("^%.system_generated") and not name:match("^%.") then
        scan(full, depth + 1)
      elseif type == "file" then
        if name:match("%.md$") or name:match("%.txt$") or name:match("%.json$") or name:match("%.html$") then
          table.insert(results, full)
        end
      end
    end
  end

  scan(dir, 1)
  return results
end

--- Opens a given artifact file in a vertical split with markdown settings.
---@param filepath string File path
function M.open_artifact_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    vim.notify(string.format("[Jetski] Artifact file not found: %s", filepath), vim.log.levels.ERROR)
    return
  end

  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].bufhidden = "hide"

  -- If markdown rendering plugin exists, user gets beautiful display
  vim.notify(string.format("[Jetski] Opened artifact: %s", vim.fn.fnamemodify(filepath, ":t")), vim.log.levels.INFO)
end

--- Opens the latest implementation plan in a split buffer.
---@param explicit_path? string Optional explicit file path
function M.open_plan(explicit_path)
  if explicit_path and vim.fn.filereadable(explicit_path) == 1 then
    M.open_artifact_file(explicit_path)
    return
  end

  -- 1. Search in latest conversation directory
  local conv_dir = M.get_latest_conversation_dir()
  if conv_dir then
    local candidates = {
      conv_dir .. "/implementation_plan.md",
      conv_dir .. "/plan.md",
      conv_dir .. "/tasks.md",
    }
    for _, path in ipairs(candidates) do
      if vim.fn.filereadable(path) == 1 then
        M.open_artifact_file(path)
        return
      end
    end
  end

  -- 2. Search in workspace root
  local ws = workspace.detect_workspace()
  if ws.workspace_root then
    local ws_candidates = {
      ws.workspace_root .. "/implementation_plan.md",
      ws.workspace_root .. "/plan.md",
    }
    for _, path in ipairs(ws_candidates) do
      if vim.fn.filereadable(path) == 1 then
        M.open_artifact_file(path)
        return
      end
    end
  end

  vim.notify("[Jetski] No implementation plan found in current conversation or workspace", vim.log.levels.WARN)
end

--- Opens the latest walkthrough in a split buffer.
---@param explicit_path? string Optional explicit file path
function M.open_walkthrough(explicit_path)
  if explicit_path and vim.fn.filereadable(explicit_path) == 1 then
    M.open_artifact_file(explicit_path)
    return
  end

  local conv_dir = M.get_latest_conversation_dir()
  if conv_dir then
    local candidates = {
      conv_dir .. "/walkthrough.md",
      conv_dir .. "/summary.md",
    }
    for _, path in ipairs(candidates) do
      if vim.fn.filereadable(path) == 1 then
        M.open_artifact_file(path)
        return
      end
    end
  end

  local ws = workspace.detect_workspace()
  if ws.workspace_root then
    local ws_path = ws.workspace_root .. "/walkthrough.md"
    if vim.fn.filereadable(ws_path) == 1 then
      M.open_artifact_file(ws_path)
      return
    end
  end

  vim.notify("[Jetski] No walkthrough found in current conversation or workspace", vim.log.levels.WARN)
end

--- Lists and allows selecting an artifact to view using vim.ui.select.
function M.list_artifacts()
  local conv_dir = M.get_latest_conversation_dir()
  local artifacts = {}

  if conv_dir then
    for _, f in ipairs(M.find_artifacts_in_dir(conv_dir)) do
      table.insert(artifacts, {
        path = f,
        name = vim.fn.fnamemodify(f, ":t"),
        source = "Session: " .. vim.fn.fnamemodify(conv_dir, ":t"):sub(1, 8),
      })
    end
  end

  if #artifacts == 0 then
    vim.notify("[Jetski] No artifacts found in session", vim.log.levels.INFO)
    return
  end

  vim.ui.select(artifacts, {
    prompt = "Select Jetski Artifact to Open:",
    format_item = function(item)
      return string.format("%-30s (%s)", item.name, item.source)
    end,
  }, function(choice)
    if choice then
      M.open_artifact_file(choice.path)
    end
  end)
end

return M
