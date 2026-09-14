--- Workspace and path resolution for Google3 / CitC and Git repositories.
local M = {}

--- Detects the VCS type for a target path or workspace root.
---@param target string File path or directory
---@param is_google3 boolean
---@param workspace_root? string
---@return string "jj" | "hg" | "p4" | "git" | "unknown"
local function detect_vcs(target, is_google3, workspace_root)
  if workspace_root then
    local parent = vim.fn.fnamemodify(workspace_root, ":h")
    if vim.fn.isdirectory(workspace_root .. "/.jj") == 1 or (parent and vim.fn.isdirectory(parent .. "/.jj") == 1) then
      return "jj"
    end
    if vim.fn.isdirectory(workspace_root .. "/.hg") == 1 or (parent and vim.fn.isdirectory(parent .. "/.hg") == 1) then
      return "hg"
    end
  end

  local jj_dir = vim.fs.root(target, ".jj")
  if jj_dir then
    return "jj"
  end

  local hg_dir = vim.fs.root(target, ".hg")
  if hg_dir then
    return "hg"
  end

  local git_dir = vim.fs.root(target, ".git")
  if git_dir then
    return "git"
  end

  if is_google3 then
    return "p4"
  end

  if vim.env.P4CLIENT and vim.env.P4CLIENT ~= "" then
    return "p4"
  end

  return "unknown"
end

--- Detects workspace information for a given file path or current working directory.
---@param path? string Optional path to inspect (defaults to current buffer or cwd)
---@return table Workspace metadata
function M.detect_workspace(path)
  local target = path
  if not target or target == "" then
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name ~= "" then
      target = buf_name
    else
      target = vim.fn.getcwd()
    end
  end
  target = vim.fn.fnamemodify(target, ":p")

  -- 1. Check for CitC Google3 workspace pattern: /google/src/cloud/<user>/<client>/google3/...
  local user, client = target:match("/google/src/cloud/([^/]+)/([^/]+)")
  if user and client then
    local citc_root = string.format("/google/src/cloud/%s/%s/google3", user, client)
    local rel_path = ""
    if target:find(citc_root, 1, true) == 1 then
      rel_path = target:sub(#citc_root + 2)
    end
    local vcs = detect_vcs(target, true, citc_root)
    return {
      type = "google3_citc",
      is_google3 = true,
      citc_user = user,
      citc_client = client,
      workspace_root = citc_root,
      workspace_uri = "file://" .. citc_root,
      relative_path = rel_path,
      depot_path = rel_path ~= "" and ("//depot/google3/" .. rel_path) or "//depot/google3",
      vcs = vcs,
      is_p4 = (vcs == "p4"),
      is_hg = (vcs == "hg"),
      is_jj = (vcs == "jj"),
      is_git = (vcs == "git"),
    }
  end

  -- 2. Check for general google3 path: .../google3/...
  local g3_idx = target:find("/google3/", 1, true)
  if g3_idx then
    local g3_root = target:sub(1, g3_idx + 7)
    local rel_path = target:sub(g3_idx + 9)
    local vcs = detect_vcs(target, true, g3_root)
    return {
      type = "google3",
      is_google3 = true,
      workspace_root = g3_root,
      workspace_uri = "file://" .. g3_root,
      relative_path = rel_path,
      depot_path = "//depot/google3/" .. rel_path,
      vcs = vcs,
      is_p4 = (vcs == "p4"),
      is_hg = (vcs == "hg"),
      is_jj = (vcs == "jj"),
      is_git = (vcs == "git"),
    }
  end

  -- 3. Check for Git root
  local git_root = vim.fs.root(target, ".git")
  if git_root then
    local rel_path = ""
    if target:find(git_root, 1, true) == 1 then
      rel_path = target:sub(#git_root + 2)
    end
    local vcs = detect_vcs(target, false, git_root)
    return {
      type = "git",
      is_google3 = false,
      workspace_root = git_root,
      workspace_uri = "file://" .. git_root,
      relative_path = rel_path,
      depot_path = nil,
      vcs = vcs,
      is_p4 = (vcs == "p4"),
      is_hg = (vcs == "hg"),
      is_jj = (vcs == "jj"),
      is_git = (vcs == "git"),
    }
  end

  -- 4. Fallback to CWD
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
  local cwd_user, cwd_client = cwd:match("/google/src/cloud/([^/]+)/([^/]+)")
  if cwd_user and cwd_client then
    local citc_root = string.format("/google/src/cloud/%s/%s/google3", cwd_user, cwd_client)
    local vcs = detect_vcs(cwd, true, citc_root)
    local rel_p = target:find(citc_root, 1, true) == 1 and target:sub(#citc_root + 2) or ""
    return {
      type = "google3_citc",
      is_google3 = true,
      citc_user = cwd_user,
      citc_client = cwd_client,
      workspace_root = citc_root,
      workspace_uri = "file://" .. citc_root,
      relative_path = rel_p,
      depot_path = rel_p ~= "" and ("//depot/google3/" .. rel_p) or "//depot/google3",
      vcs = vcs,
      is_p4 = (vcs == "p4"),
      is_hg = (vcs == "hg"),
      is_jj = (vcs == "jj"),
      is_git = (vcs == "git"),
    }
  end

  local cwd_g3_idx = cwd:find("/google3/", 1, true)
  if cwd_g3_idx then
    local g3_root = cwd:sub(1, cwd_g3_idx + 7)
    local vcs = detect_vcs(cwd, true, g3_root)
    return {
      type = "google3",
      is_google3 = true,
      workspace_root = g3_root,
      workspace_uri = "file://" .. g3_root,
      relative_path = "",
      depot_path = "//depot/google3",
      vcs = vcs,
      is_p4 = (vcs == "p4"),
      is_hg = (vcs == "hg"),
      is_jj = (vcs == "jj"),
      is_git = (vcs == "git"),
    }
  end

  local cwd_git_root = vim.fs.root(cwd, ".git")
  if cwd_git_root then
    local vcs = detect_vcs(cwd, false, cwd_git_root)
    return {
      type = "git",
      is_google3 = false,
      workspace_root = cwd_git_root,
      workspace_uri = "file://" .. cwd_git_root,
      relative_path = "",
      depot_path = nil,
      vcs = vcs,
      is_p4 = (vcs == "p4"),
      is_hg = (vcs == "hg"),
      is_jj = (vcs == "jj"),
      is_git = (vcs == "git"),
    }
  end

  local vcs = detect_vcs(target, false, cwd)
  return {
    type = "cwd",
    is_google3 = false,
    workspace_root = cwd,
    workspace_uri = "file://" .. cwd,
    relative_path = target:sub(#cwd + 2),
    depot_path = nil,
    vcs = vcs,
    is_p4 = (vcs == "p4"),
    is_hg = (vcs == "hg"),
    is_jj = (vcs == "jj"),
    is_git = (vcs == "git"),
  }
end

--- Returns comprehensive context info for the currently active buffer and cursor.
--- Falls back to an editor window if the current window is a terminal or Jetski special buffer.
---@param bufnr? number Optional explicit buffer number
---@return table
function M.get_active_file_info(bufnr)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
    local buftype = vim.bo[bufnr].buftype
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if buftype == "terminal" or bufname:find("^jetski://") then
      -- If current buffer is terminal or a Jetski buffer, find the active editor window
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(win)
        local bt = vim.bo[b].buftype
        local bn = vim.api.nvim_buf_get_name(b)
        if bt == "" and bn ~= "" and not bn:find("^jetski://") then
          bufnr = b
          break
        end
      end
    end
  end

  local raw_path = vim.api.nvim_buf_get_name(bufnr)
  local is_special = raw_path:find("^jetski://") ~= nil or vim.bo[bufnr].buftype ~= ""
  local is_named = raw_path ~= "" and not is_special
  local abs_path = is_named and M.normalize_path(raw_path) or ""
  local ws = M.detect_workspace(abs_path ~= "" and abs_path or nil)

  local cursor = { 1, 0 }
  if bufnr == vim.api.nvim_get_current_buf() then
    cursor = vim.api.nvim_win_get_cursor(0)
  end
  local line = cursor[1]
  local col = cursor[2] + 1
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local filetype = vim.bo[bufnr].filetype

  local top_line = vim.fn.line("w0")
  local bot_line = vim.fn.line("w$")

  return {
    bufnr = bufnr,
    abs_path = abs_path,
    is_named = is_named,
    filename = is_named and vim.fn.fnamemodify(abs_path, ":t") or "[No Name]",
    relative_path = ws.relative_path,
    depot_path = ws.depot_path,
    workspace_root = ws.workspace_root,
    is_google3 = ws.is_google3,
    vcs = ws.vcs,
    is_p4 = ws.is_p4,
    is_hg = ws.is_hg,
    is_jj = ws.is_jj,
    is_git = ws.is_git,
    line = line,
    col = col,
    total_lines = total_lines,
    filetype = filetype,
    visible_top = top_line,
    visible_bot = bot_line,
  }
end

--- Normalizes a path, resolving Google3 depot paths and relative google3/ paths to absolute paths.
---@param path string
---@return string
function M.normalize_path(path)
  if not path or path == "" then return "" end
  if path:sub(1, 7) == "file://" then
    path = path:sub(8)
  end

  local ws = M.detect_workspace()

  -- Convert Google3 depot path //depot/google3/... or depot/google3/...
  if path:find("^//depot/google3/") or path:find("^depot/google3/") then
    local rel = path:gsub("^//depot/google3/", ""):gsub("^depot/google3/", "")
    if ws.is_google3 and ws.workspace_root then
      return vim.fn.fnamemodify(ws.workspace_root .. "/" .. rel, ":p")
    end
  end

  -- Convert relative google3/... path
  if path:find("^google3/") then
    local rel = path:sub(9)
    if ws.is_google3 and ws.workspace_root then
      return vim.fn.fnamemodify(ws.workspace_root .. "/" .. rel, ":p")
    end
  end

  -- If path is already absolute, return normalized
  if path:sub(1, 1) == "/" then
    return vim.fn.fnamemodify(path, ":p")
  end

  -- Check if path exists relative to CWD
  local cwd_path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.filereadable(cwd_path) == 1 or vim.fn.isdirectory(cwd_path) == 1 then
    return cwd_path
  end

  -- If not relative to CWD, check relative to workspace_root
  if ws.workspace_root then
    local ws_path = vim.fn.fnamemodify(ws.workspace_root .. "/" .. path, ":p")
    if vim.fn.filereadable(ws_path) == 1 or vim.fn.isdirectory(ws_path) == 1 then
      return ws_path
    end
    local citc_base = vim.fn.fnamemodify(ws.workspace_root, ":h")
    if citc_base then
      local base_path = vim.fn.fnamemodify(citc_base .. "/" .. path, ":p")
      if vim.fn.filereadable(base_path) == 1 or vim.fn.isdirectory(base_path) == 1 then
        return base_path
      end
    end
    return ws_path
  end

  return cwd_path
end

--- Retrieves a list of modified or untracked file paths from the active VCS.
---@return string[] Array of absolute file paths
function M.get_vcs_modified_files()
  local ws = M.detect_workspace()
  local root = ws.workspace_root
  if not root then return {} end

  local results = {}
  local seen = {}

  local function add_file(p, allow_deleted)
    local full = M.normalize_path(p)
    if full ~= "" and not seen[full] then
      if vim.fn.filereadable(full) == 1 or allow_deleted then
        seen[full] = true
        table.insert(results, full)
      end
    end
  end

  -- CitC Mercurial / Fig
  if ws.is_google3 and (ws.vcs == "hg" or ws.vcs == "unknown") then
    local citc_base = vim.fn.fnamemodify(root, ":h")
    local hg_bin = vim.fn.executable("/usr/bin/hg") == 1 and "/usr/bin/hg" or (vim.fn.executable("hg") == 1 and "hg" or nil)
    if hg_bin then
      local lines = vim.fn.systemlist({ hg_bin, "-R", citc_base, "status" })
      if vim.v.shell_error == 0 then
        for _, line in ipairs(lines) do
          local status_char, rel = line:match("^([%w%?!])%s+(.+)$")
          if rel then
            local is_deleted = (status_char == "R" or status_char == "!")
            local candidate = rel:find("^google3/") and (citc_base .. "/" .. rel) or (root .. "/" .. rel)
            add_file(candidate, is_deleted)
          end
        end
      end
    end
  end

  -- Jujutsu
  if ws.vcs == "jj" then
    local jj_root = ws.is_google3 and vim.fn.fnamemodify(root, ":h") or root
    local lines = vim.fn.systemlist({ "jj", "-R", jj_root, "diff", "--summary" })
    if vim.v.shell_error == 0 then
      for _, line in ipairs(lines) do
        local status_char, rel = line:match("^([%w%?!])%s+(.+)$")
        if rel then
          local is_deleted = (status_char == "D")
          local candidate = rel:find("^google3/") and (jj_root .. "/" .. rel) or (root .. "/" .. rel)
          add_file(candidate, is_deleted)
        end
      end
    end
  end

  -- Git
  if ws.type == "git" or ws.vcs == "git" then
    local lines = vim.fn.systemlist({ "git", "-C", root, "status", "--porcelain" })
    if vim.v.shell_error == 0 then
      for _, line in ipairs(lines) do
        local status_str, rel = line:match("^%s*(%S+)%s+(.+)$")
        if rel then
          local new_path = rel:match("->%s*(.+)$") or rel
          local is_deleted = status_str and status_str:find("D") ~= nil
          add_file(root .. "/" .. new_path, is_deleted)
        end
      end
    end
  end

  -- Piper / Perforce (only if explicitly detected as p4)
  if ws.is_google3 and ws.vcs == "p4" then
    local p4_bin = vim.fn.executable("/usr/bin/g4") == 1 and "/usr/bin/g4" or (vim.fn.executable("g4") == 1 and "g4" or (vim.fn.executable("p4") == 1 and "p4" or nil))
    if p4_bin then
      local lines = vim.fn.systemlist({ p4_bin, "opened" })
      if vim.v.shell_error == 0 then
        for _, line in ipairs(lines) do
          local depot = line:match("^(//depot/google3/[^#%s]+)")
          if depot then
            add_file(depot, false)
          end
        end
      end
    end
  end

  return results
end

return M
