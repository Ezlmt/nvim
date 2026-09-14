--- Agent edit diff review and buffer synchronization (Parity with Cider-J AgentEditManager).
local config = require("jetski.config")
local workspace = require("jetski.workspace")

local M = {}

--- Snapshots of files prior to agent edits:
--- M.snapshots[abs_filepath] = { lines = table, timestamp = number, source = string }
M.snapshots = {}

--- Active diff review session state:
--- M.active_diff = { orig_win = number, mod_win = number, orig_buf = number, mod_buf = number, filepath = string, saved_opts = table, source = string }
M.active_diff = nil

--- Checks whether two line arrays are identical, ignoring trailing carriage returns (\r).
--- Treats empty array and single empty-line array as equivalent empty states.
---@param lines_a string[]
---@param lines_b string[]
---@return boolean
function M.are_lines_equal(lines_a, lines_b)
  local function is_empty(lines)
    return not lines or #lines == 0 or (#lines == 1 and lines[1]:gsub("\r$", "") == "")
  end
  if is_empty(lines_a) and is_empty(lines_b) then
    return true
  end
  if not lines_a or not lines_b or #lines_a ~= #lines_b then
    return false
  end
  for i = 1, #lines_a do
    local a = lines_a[i]:gsub("\r$", "")
    local b = lines_b[i]:gsub("\r$", "")
    if a ~= b then
      return false
    end
  end
  return true
end

--- Configures Neovim to automatically reload buffers modified externally by the agent,
--- capturing pre-reload snapshots so diff review has the pristine original state.
function M.setup_autoread()
  if not config.get().auto_revert then
    return
  end

  local group = vim.api.nvim_create_augroup("JetskiAutoRead", { clear = true })

  -- Listen to FileChangedShell to capture pre-reload snapshot if fired
  vim.api.nvim_create_autocmd({ "FileChangedShell" }, {
    group = group,
    pattern = "*",
    callback = function(ev)
      local filepath = workspace.normalize_path(ev.file)
      if vim.api.nvim_buf_is_loaded(ev.buf) then
        if not M.snapshots[filepath] then
          local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
          M.snapshots[filepath] = {
            lines = lines,
            timestamp = vim.uv.now(),
            source = "pre_reload",
          }
        end
      end
      if vim.bo[ev.buf].modified then
        vim.v.fcs_choice = "ask"
      else
        vim.v.fcs_choice = "reload"
      end
    end,
  })

  -- When buffer is reloaded from disk: if active diff is reviewing this buffer, update diff highlights
  vim.api.nvim_create_autocmd({ "FileChangedShellPost" }, {
    group = group,
    pattern = "*",
    callback = function(ev)
      if M.active_diff and ev.buf == M.active_diff.mod_buf then
        vim.schedule(function()
          pcall(vim.cmd, "diffupdate")
        end)
      end
    end,
  })

  -- Check files when entering Neovim or buffers, or leaving terminal
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "WinEnter", "TermLeave", "CursorHold", "CursorHoldI" }, {
    group = group,
    pattern = "*",
    callback = function()
      if vim.fn.mode() ~= "c" and vim.fn.mode() ~= "t" then
        pcall(vim.cmd, "silent! checktime")
      end
    end,
  })

  -- Automatically close diff mode on save/commit if configured
  if config.get().diff.auto_accept_on_commit then
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      group = group,
      pattern = "*",
      callback = function(ev)
        if M.active_diff and ev.buf == M.active_diff.mod_buf and not M._is_rejecting then
          local target = M.active_diff.filepath
          vim.schedule(function()
            if M.active_diff and M.active_diff.filepath == target and not M._is_rejecting then
              M.accept_diff(target)
            end
          end)
        end
      end,
    })
  end
end

--- Snapshots all loaded, named file buffers in the current Neovim session.
--- Called automatically whenever a prompt or instruction is sent to Jetski.
function M.snapshot_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" and vim.bo[bufnr].buftype == "" and not name:find("^jetski://") and vim.fn.filereadable(name) == 1 then
        local filepath = workspace.normalize_path(name)
        -- Only snapshot if not currently in diff review for this file
        if not (M.active_diff and M.active_diff.filepath == filepath) then
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          -- Update snapshot if not present or if content has changed since previous snapshot
          if not M.snapshots[filepath] or not M.are_lines_equal(M.snapshots[filepath].lines, lines) then
            M.snapshots[filepath] = {
              lines = lines,
              timestamp = vim.uv.now(),
              source = "pre_prompt",
            }
          end
        end
      end
    end
  end
end

--- Takes a pre-edit snapshot of the current state of a file if not already recorded.
---@param filepath string File path
function M.record_pre_edit_snapshot(filepath)
  filepath = workspace.normalize_path(filepath)
  if M.snapshots[filepath] then
    return
  end

  local lines = {}
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  elseif vim.fn.filereadable(filepath) == 1 then
    lines = vim.fn.readfile(filepath)
  end

  M.snapshots[filepath] = {
    lines = lines,
    timestamp = vim.uv.now(),
    source = "manual",
  }
end

--- Fetches base version lines from VCS (Jujutsu/jj, Fig/hg in Google3, Perforce/p4/g4, Git, or CitC snapshot).
---@param filepath string
---@return string[]|nil lines, string|nil source
function M.get_vcs_base_lines(filepath)
  filepath = workspace.normalize_path(filepath)
  local ws = workspace.detect_workspace(filepath)

  -- Helper to check if p4/g4 output is valid content and not an error/status message
  local function is_valid_p4_output(out)
    if vim.v.shell_error ~= 0 or not out or #out == 0 then
      return false
    end
    local first = out[1] or ""
    if first:find("%- no such file")
      or first:find("must create client")
      or first:find("not in client view")
      or first:find("This is a Fig workspace")
      or first:find("Did you mean to run")
      or first:find("is not under client")
    then
      return false
    end
    return true
  end

  -- 1. CitC / Google3 Jujutsu (jj)
  if ws.is_google3 and ws.workspace_root then
    local citc_base = vim.fn.fnamemodify(ws.workspace_root, ":h")
    local jj_root = nil
    if citc_base and vim.fn.isdirectory(citc_base .. "/.jj") == 1 then
      jj_root = citc_base
    elseif vim.fn.isdirectory(ws.workspace_root .. "/.jj") == 1 then
      jj_root = ws.workspace_root
    end

    if jj_root then
      local rel_path = ws.relative_path or ""
      local target_path = rel_path:find("^google3/") and ("root:" .. rel_path) or ("root:google3/" .. rel_path)
      local out = vim.fn.systemlist({ "jj", "-R", jj_root, "file", "show", "-r", "@-", target_path })
      if vim.v.shell_error == 0 and out then
        return out, "jj:@-"
      end
    end
  else
    -- General Jujutsu repository
    local jj_dir = vim.fs.root(filepath, ".jj")
    if jj_dir then
      local rel_path = filepath:sub(#jj_dir + 2)
      local out = vim.fn.systemlist({ "jj", "-R", jj_dir, "file", "show", "-r", "@-", "root:" .. rel_path })
      if vim.v.shell_error == 0 and out then
        return out, "jj:@-"
      end
    end
  end

  -- 2. Mercurial / Fig in Google3 or CitC
  if (ws.is_google3 and ws.vcs ~= "p4") or vim.fn.isdirectory(vim.fn.fnamemodify(filepath, ":h") .. "/.hg") == 1 then
    local citc_base = ws.workspace_root and vim.fn.fnamemodify(ws.workspace_root, ":h")
    local hg_bin = vim.fn.executable("/usr/bin/hg") == 1 and "/usr/bin/hg" or (vim.fn.executable("hg") == 1 and "hg" or nil)

    if hg_bin and citc_base then
      local rel_to_citc = filepath:find(citc_base, 1, true) == 1 and filepath:sub(#citc_base + 2) or (ws.relative_path or "")
      if ws.is_google3 and not rel_to_citc:find("^google3/") and rel_to_citc ~= "" then
        rel_to_citc = "google3/" .. rel_to_citc
      end
      local target_arg = rel_to_citc ~= "" and ("path:" .. rel_to_citc) or filepath
      local out = vim.fn.systemlist({ hg_bin, "-R", citc_base, "cat", "-r", ".", target_arg })
      if vim.v.shell_error == 0 and out then
        return out, "hg:."
      end

      -- If hg cat failed, try instant .snapshot/head fallback before slow p4base
      if vim.fn.isdirectory(citc_base .. "/.snapshot") == 1 then
        local snap_file = citc_base .. "/.snapshot/head/" .. rel_to_citc
        if vim.fn.filereadable(snap_file) == 1 then
          local snap_out = vim.fn.readfile(snap_file)
          if snap_out then
            return snap_out, "citc:snapshot/head"
          end
        end
      end

      -- Try 'p4base' revision if available
      out = vim.fn.systemlist({ hg_bin, "-R", citc_base, "cat", "-r", "p4base", target_arg })
      if vim.v.shell_error == 0 and out then
        return out, "hg:p4base"
      end
    elseif hg_bin then
      local out = vim.fn.systemlist({ hg_bin, "cat", "-r", ".", filepath })
      if vim.v.shell_error == 0 and out then
        return out, "hg:."
      end
    end
  end

  -- 3. CitC .snapshot/head fallback (instant zero-subprocess virtual mount read)
  if ws.is_google3 and ws.workspace_root then
    local citc_base = vim.fn.fnamemodify(ws.workspace_root, ":h")
    if citc_base and vim.fn.isdirectory(citc_base .. "/.snapshot") == 1 then
      local rel_to_citc = filepath:find(citc_base, 1, true) == 1 and filepath:sub(#citc_base + 2) or (ws.relative_path or "")
      local snap_file = citc_base .. "/.snapshot/head/" .. (rel_to_citc:find("^google3/") and rel_to_citc or ("google3/" .. rel_to_citc))
      if vim.fn.filereadable(snap_file) == 1 then
        local out = vim.fn.readfile(snap_file)
        if out then
          return out, "citc:snapshot/head"
        end
      end
    end
  end

  -- 4. Perforce / Piper (g4 / p4) in Google3 or CitC
  if ws.is_google3 and ws.vcs == "p4" and ws.depot_path then
    local p4_bins = { "/usr/bin/g4", "/usr/bin/p4", "g4", "p4" }
    for _, bin in ipairs(p4_bins) do
      if vim.fn.executable(bin) == 1 then
        -- 4a. Try depot path #have (client synced revision)
        local out = vim.fn.systemlist({ bin, "print", "-q", ws.depot_path .. "#have" })
        if is_valid_p4_output(out) then
          return out, "p4:#have"
        end

        -- 4b. Try local filepath #have
        out = vim.fn.systemlist({ bin, "print", "-q", filepath .. "#have" })
        if is_valid_p4_output(out) then
          return out, "p4:#have"
        end

        -- 4c. Try depot path #head
        out = vim.fn.systemlist({ bin, "print", "-q", ws.depot_path .. "#head" })
        if is_valid_p4_output(out) then
          return out, "p4:#head"
        end
        break
      end
    end
  end

  -- 5. Git repository
  if ws.type == "git" or ws.vcs == "git" then
    local git_root = ws.workspace_root or vim.fs.root(filepath, ".git")
    if git_root then
      local rel_to_git = filepath:sub(#git_root + 2)
      -- 5a. Try git index (staged version)
      local out = vim.fn.systemlist({ "git", "-C", git_root, "show", ":" .. rel_to_git })
      if vim.v.shell_error == 0 and out then
        return out, "git:index"
      end

      -- 5b. Try git HEAD commit
      out = vim.fn.systemlist({ "git", "-C", git_root, "show", "HEAD:" .. rel_to_git })
      if vim.v.shell_error == 0 and out then
        return out, "git:HEAD"
      end
    end
  else
    local git_dir = vim.fn.finddir(".git", vim.fn.fnamemodify(filepath, ":h") .. ";")
    if git_dir and git_dir ~= "" then
      local root = vim.fn.fnamemodify(git_dir, ":h")
      local rel_to_git = filepath:sub(#root + 2)
      local out = vim.fn.systemlist({ "git", "-C", root, "show", "HEAD:" .. rel_to_git })
      if vim.v.shell_error == 0 and out then
        return out, "git:HEAD"
      end
    end
  end

  if not ws.is_google3 then
    -- 6. Non-Google3 Mercurial (hg)
    if vim.fn.executable("hg") == 1 or vim.fn.executable("/usr/bin/hg") == 1 then
      local hg_bin = vim.fn.executable("/usr/bin/hg") == 1 and "/usr/bin/hg" or "hg"
      local out = vim.fn.systemlist({ hg_bin, "cat", "-r", ".", filepath })
      if vim.v.shell_error == 0 and out and #out > 0 then
        return out, "hg:."
      end
    end

    -- 7. Non-Google3 Perforce (p4)
    if vim.fn.executable("p4") == 1 or vim.fn.executable("/usr/bin/p4") == 1 then
      local p4_bin = vim.fn.executable("/usr/bin/p4") == 1 and "/usr/bin/p4" or "p4"
      local out = vim.fn.systemlist({ p4_bin, "print", "-q", filepath .. "#have" })
      if is_valid_p4_output(out) then
        return out, "p4:#have"
      end
      out = vim.fn.systemlist({ p4_bin, "print", "-q", filepath .. "#head" })
      if is_valid_p4_output(out) then
        return out, "p4:#head"
      end
    end
  end

  return nil, nil
end

--- Returns files with pending agent edits (where snapshot differs from disk or in-memory content).
---@return string[]
function M.get_agent_modified_files()
  local modified = {}
  local seen = {}
  local function add(p)
    if p and p ~= "" and not seen[p] then
      seen[p] = true
      table.insert(modified, p)
    end
  end

  for path, snap in pairs(M.snapshots) do
    local is_diff = false
    local bufnr = vim.fn.bufnr(path)
    local is_loaded = bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr)
    local file_exists = vim.fn.filereadable(path) == 1

    if snap.source == "accepted" or snap.source == "rejected" then
      if not file_exists and not is_loaded then
        -- File no longer exists on disk or in memory; purge stale snapshot
        M.snapshots[path] = nil
      else
        -- Check if file was modified again after acceptance/rejection
        if is_loaded then
          local mem_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          if not M.are_lines_equal(snap.lines, mem_lines) then
            is_diff = true
          end
        end
        if not is_diff and file_exists then
          local ok_read, disk_lines = pcall(vim.fn.readfile, path)
          if ok_read and disk_lines and not M.are_lines_equal(snap.lines, disk_lines) then
            is_diff = true
          end
        end
      end
    else
      -- Pending snapshot (source = "pre_prompt", "pre_reload", "manual", "new file", or VCS base)
      if is_loaded then
        local mem_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if not M.are_lines_equal(snap.lines, mem_lines) then
          is_diff = true
        end
      end
      if not is_diff and file_exists then
        local ok_read, disk_lines = pcall(vim.fn.readfile, path)
        if ok_read and disk_lines and not M.are_lines_equal(snap.lines, disk_lines) then
          is_diff = true
        end
      elseif not is_diff and not file_exists and #snap.lines > 0 and snap.source ~= "new file" then
        -- File was snapshotted before agent ran, but was deleted
        is_diff = true
      elseif not is_diff and not file_exists and not is_loaded then
        -- Snapshot of a non-existent file with 0 lines or new file that was deleted
        M.snapshots[path] = nil
      end
    end

    if is_diff then
      add(path)
    end
  end

  return modified
end

--- Collects all modified filepaths currently known across snapshots, loaded buffers, and VCS.
---@return string[] Array of absolute file paths with changes
function M.get_all_modified_files()
  local modified = {}
  local seen = {}

  local function add(p)
    if p and p ~= "" and not seen[p] then
      seen[p] = true
      table.insert(modified, p)
    end
  end

  -- 1. Files modified by the agent
  for _, p in ipairs(M.get_agent_modified_files()) do
    add(p)
  end

  -- 2. Loaded file buffers that are modified in Neovim
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified and vim.bo[bufnr].buftype == "" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" and not name:find("^jetski://") then
        add(workspace.normalize_path(name))
      end
    end
  end

  -- 3. VCS modified files
  local vcs_files = workspace.get_vcs_modified_files()
  for _, p in ipairs(vcs_files) do
    local has_pending_diff = true
    local snap = M.snapshots[p]
    if snap and snap.lines then
      local cur = nil
      local b = vim.fn.bufnr(p)
      if b ~= -1 and vim.api.nvim_buf_is_loaded(b) then
        cur = vim.api.nvim_buf_get_lines(b, 0, -1, false)
      elseif vim.fn.filereadable(p) == 1 then
        local ok_read, disk_lines = pcall(vim.fn.readfile, p)
        if ok_read then cur = disk_lines end
      end
      if cur and M.are_lines_equal(snap.lines, cur) then
        has_pending_diff = false
      end
    end
    if has_pending_diff then
      add(p)
    end
  end

  return modified
end

--- Smart resolution of target file for diff review.
--- Handles explicit arguments, active editor window, background terminal focus, and snapshots.
---@param filepath? string
---@return string|nil
function M.resolve_diff_target(filepath)
  -- 1. Explicit filepath argument
  if filepath and filepath ~= "" then
    return workspace.normalize_path(filepath)
  end

  -- If diff is already active, prioritize its target
  if M.active_diff and M.active_diff.filepath then
    return M.active_diff.filepath
  end

  -- Find active candidate path from current buffer or active editor window
  local cur_candidate = nil
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_name = vim.api.nvim_buf_get_name(cur_buf)
  local cur_buftype = vim.bo[cur_buf].buftype
  if cur_buftype == "" and cur_name ~= "" and not cur_name:find("^jetski://") then
    cur_candidate = workspace.normalize_path(cur_name)
  else
    local terminal = require("jetski.terminal")
    local editor_win = terminal.find_editor_window()
    if editor_win then
      local edit_buf = vim.api.nvim_win_get_buf(editor_win)
      local edit_name = vim.api.nvim_buf_get_name(edit_buf)
      if vim.bo[edit_buf].buftype == "" and edit_name ~= "" and not edit_name:find("^jetski://") then
        cur_candidate = workspace.normalize_path(edit_name)
      end
    end
  end

  -- 2. First prioritize files modified by the AGENT
  local agent_modified = M.get_agent_modified_files()
  if #agent_modified > 0 then
    if cur_candidate and cur_candidate ~= "" then
      for _, mod_path in ipairs(agent_modified) do
        if mod_path == cur_candidate then
          return cur_candidate
        end
      end
    end
    if #agent_modified == 1 then
      return agent_modified[1]
    end
    return nil -- Multiple agent modified files: caller will open picker
  end

  -- 3. Fallback to general modified files (open buffers or VCS)
  local all_modified = M.get_all_modified_files()
  if cur_candidate and cur_candidate ~= "" then
    for _, mod_path in ipairs(all_modified) do
      if mod_path == cur_candidate then
        return cur_candidate
      end
    end
  end

  if #all_modified == 1 then
    return all_modified[1]
  end

  if #all_modified > 1 then
    return nil
  end

  if cur_candidate and cur_candidate ~= "" then
    return cur_candidate
  end

  local info = workspace.get_active_file_info()
  if info.is_named and info.abs_path ~= "" and not info.abs_path:find("^jetski://") then
    return info.abs_path
  end

  return nil
end

--- Complete helper for :JetskiDiff, :JetskiAccept, :JetskiReject.
--- Autocompletes snapshotted files, open buffers, and VCS modified files.
--- Provides both relative paths and depot paths for clean ergonomic tab completion.
---@param arg_lead string
---@return string[]
function M.complete_diff_files(arg_lead)
  local candidates = {}
  local seen = {}

  local ws = workspace.detect_workspace()
  local root = ws.workspace_root
  local cwd = vim.fn.getcwd()

  local function add(p)
    if not p or p == "" then return end
    local full = workspace.normalize_path(p)
    local items = { full }

    -- Add path relative to CWD
    if full:find(cwd, 1, true) == 1 then
      local rel_cwd = full:sub(#cwd + 2)
      if rel_cwd ~= "" then table.insert(items, rel_cwd) end
    end

    -- Add path relative to workspace root
    if root and full:find(root, 1, true) == 1 then
      local rel_root = full:sub(#root + 2)
      if rel_root ~= "" then table.insert(items, rel_root) end
    end

    -- Add filename only
    local fname = vim.fn.fnamemodify(full, ":t")
    if fname ~= "" then table.insert(items, fname) end

    for _, item in ipairs(items) do
      if not seen[item] then
        seen[item] = true
        if not arg_lead or arg_lead == "" or item:find(arg_lead, 1, true) == 1 or item:find(arg_lead, 1, true) then
          table.insert(candidates, item)
        end
      end
    end
  end

  -- Snapshots
  for p, _ in pairs(M.snapshots) do
    add(p)
  end

  -- Loaded file buffers
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == "" then
      local n = vim.api.nvim_buf_get_name(b)
      if n ~= "" and not n:find("^jetski://") then
        add(n)
      end
    end
  end

  -- VCS modified files
  local vcs_files = workspace.get_vcs_modified_files()
  for _, p in ipairs(vcs_files) do
    add(p)
  end

  table.sort(candidates)
  return candidates
end

--- Opens an interactive side-by-side diff review between the pre-edit snapshot/base and current file.
---@param filepath? string Optional file path to review (defaults to active buffer or smart resolution)
function M.review_diff(filepath)
  -- 1. Resolve target file
  local target = M.resolve_diff_target(filepath)

  if not target or target == "" then
    local agent_mod = M.get_agent_modified_files()
    local modified = #agent_mod > 0 and agent_mod or M.get_all_modified_files()
    if #modified > 1 then
      vim.ui.select(modified, {
        prompt = "Select modified file to review diff:",
        format_item = function(item)
          local ws = workspace.detect_workspace(item)
          if ws.workspace_root and item:find(ws.workspace_root, 1, true) == 1 then
            return item:sub(#ws.workspace_root + 2)
          end
          return vim.fn.fnamemodify(item, ":.")
        end,
      }, function(choice)
        if choice then
          M.review_diff(choice)
        end
      end)
      return
    elseif #modified == 1 then
      target = modified[1]
    else
      vim.notify("[Jetski] No active file or modified file found to review", vim.log.levels.WARN)
      return
    end
  end

  filepath = workspace.normalize_path(target)

  -- 2. Close existing diff review if one is active
  M.close_diff_review()

  -- 3. Prepare modified buffer
  local bufnr = vim.fn.bufnr(filepath)
  local is_loaded = bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr)
  local mod_buf = bufnr ~= -1 and bufnr or vim.fn.bufadd(filepath)
  if not is_loaded then
    vim.fn.bufload(mod_buf)
  end

  local file_exists_on_disk = vim.fn.filereadable(filepath) == 1

  -- 4. Disk vs In-Memory sync and pre-edit snapshot capture
  if is_loaded and file_exists_on_disk then
    local mem_lines = vim.api.nvim_buf_get_lines(mod_buf, 0, -1, false)
    local ok_read, disk_lines = pcall(vim.fn.readfile, filepath)
    if ok_read and disk_lines and not M.are_lines_equal(mem_lines, disk_lines) then
      local snap = M.snapshots[filepath]
      if snap and snap.lines then
        if M.are_lines_equal(snap.lines, mem_lines) and not M.are_lines_equal(snap.lines, disk_lines) then
          -- Disk was modified externally after in-memory snapshot was taken. Reload mod_buf from disk!
          pcall(vim.api.nvim_buf_call, mod_buf, function() vim.cmd("edit!") end)
        end
        -- Else: mem_lines differs from snap.lines (in-memory changes present). Keep mem_lines in mod_buf!
      elseif not vim.bo[mod_buf].modified then
        -- No snapshot, but buffer was clean in memory: disk was modified externally.
        -- Record pre-reload in-memory lines as snapshot and reload.
        M.snapshots[filepath] = {
          lines = mem_lines,
          timestamp = vim.uv.now(),
          source = "pre_edit",
        }
        pcall(vim.api.nvim_buf_call, mod_buf, function() vim.cmd("edit!") end)
      else
        -- User has unsaved edits in memory and no snapshot exists:
        -- Record disk lines as the base snapshot so diff compares disk vs user's unsaved edits
        M.snapshots[filepath] = {
          lines = disk_lines,
          timestamp = vim.uv.now(),
          source = "disk",
        }
      end
    end
  elseif is_loaded and not file_exists_on_disk then
    -- File was deleted on disk externally
    if not vim.bo[mod_buf].modified and M.snapshots[filepath] and #M.snapshots[filepath].lines > 0 then
      vim.api.nvim_buf_set_lines(mod_buf, 0, -1, false, {})
    end
  end

  -- Sync buffer if unmodified
  if vim.api.nvim_buf_is_loaded(mod_buf) and not vim.bo[mod_buf].modified and file_exists_on_disk then
    pcall(vim.api.nvim_buf_call, mod_buf, function() vim.cmd("silent! checktime") end)
  end

  -- Normalize CRLF on mod_buf in memory to avoid spurious diff markers
  local raw_curr_lines = vim.api.nvim_buf_get_lines(mod_buf, 0, -1, false)
  local clean_curr_lines = {}
  local has_cr = false
  for _, line in ipairs(raw_curr_lines) do
    if line:find("\r$") then
      has_cr = true
      table.insert(clean_curr_lines, (line:gsub("\r$", "")))
    else
      table.insert(clean_curr_lines, line)
    end
  end
  local was_modified = vim.bo[mod_buf].modified
  if has_cr then
    vim.api.nvim_buf_set_lines(mod_buf, 0, -1, false, clean_curr_lines)
    vim.bo[mod_buf].modified = was_modified
  end

  local curr_lines = clean_curr_lines

  -- 6. Resolve original base lines
  local orig_lines = nil
  local orig_source = nil

  -- Priority 1: In-memory snapshot if recorded
  local snapshot = M.snapshots[filepath]
  if snapshot and snapshot.lines then
    orig_lines = snapshot.lines
    orig_source = snapshot.source or "snapshot"
  end

  -- Priority 2: VCS base lines
  if not orig_lines then
    local vcs_lines, vcs_src = M.get_vcs_base_lines(filepath)
    if vcs_lines then
      orig_lines = vcs_lines
      orig_source = vcs_src
      M.snapshots[filepath] = {
        lines = orig_lines,
        timestamp = vim.uv.now(),
        source = vcs_src,
      }
    end
  end

  -- Priority 3: Newly created file (exists on disk or modified in buffer, not in VCS, no snapshot)
  if not orig_lines and (file_exists_on_disk or vim.bo[mod_buf].modified) and #curr_lines > 0 and (not (#curr_lines == 1 and curr_lines[1] == "")) then
    orig_lines = {}
    orig_source = "new file"
    M.snapshots[filepath] = {
      lines = orig_lines,
      timestamp = vim.uv.now(),
      source = "new file",
    }
  end

  -- Priority 4: Deleted file (no longer on disk, but has snapshot or base lines)
  if not file_exists_on_disk and orig_lines and #orig_lines > 0 and not vim.bo[mod_buf].modified then
    curr_lines = {}
  end

  local fname = vim.fn.fnamemodify(filepath, ":t")

  -- 7. If still no diff found, inform the user
  if not orig_lines or M.are_lines_equal(orig_lines, curr_lines) then
    vim.notify(string.format("[Jetski] No changes detected for %s (matches %s)", fname, orig_source or "base version"), vim.log.levels.INFO)
    return
  end

  -- 8. Target window for the modified file: NEVER overwrite terminal window, quickfix, or special buffer!
  local terminal = require("jetski.terminal")
  local cur_win = vim.api.nvim_get_current_win()
  local cur_win_buf = vim.api.nvim_win_get_buf(cur_win)
  local cur_bt = vim.bo[cur_win_buf].buftype
  local cur_name = vim.api.nvim_buf_get_name(cur_win_buf)
  local is_special_win = (terminal.is_open() and (cur_win == terminal.term_win or cur_win_buf == terminal.term_buf))
    or cur_bt ~= ""
    or cur_name:find("^jetski://")
    or vim.wo[cur_win].diff

  -- Check if mod_buf is already displayed in a valid non-diff window in the current tabpage
  local existing_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == mod_buf and not vim.wo[win].diff then
      existing_win = win
      break
    end
  end

  local mod_win = nil
  if existing_win then
    mod_win = existing_win
  elseif is_special_win then
    local editor_win = terminal.find_editor_window()
    if editor_win then
      mod_win = editor_win
    else
      vim.cmd("topleft split")
      mod_win = vim.api.nvim_get_current_win()
    end
  else
    mod_win = cur_win
  end

  vim.api.nvim_win_set_buf(mod_win, mod_buf)

  -- 9. Create scratch buffer for original content
  local orig_buf_name = "jetski://original/" .. fname .. " [" .. vim.fn.fnamemodify(filepath, ":h:t") .. "]"
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == orig_buf_name then
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == b then
          pcall(vim.api.nvim_win_close, w, true)
        end
      end
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end

  local orig_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[orig_buf].buftype = "nofile"
  vim.bo[orig_buf].bufhidden = "hide"
  vim.bo[orig_buf].swapfile = false
  pcall(vim.api.nvim_buf_set_name, orig_buf, orig_buf_name)

  -- Strip trailing carriage returns before displaying
  local clean_orig_lines = {}
  for _, line in ipairs(orig_lines) do
    table.insert(clean_orig_lines, (line:gsub("\r$", "")))
  end
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, clean_orig_lines)

  -- Set filetype and fileformat to match mod_buf
  local ft = vim.bo[mod_buf].filetype
  if ft and ft ~= "" then
    vim.bo[orig_buf].filetype = ft
  end
  local ff = vim.bo[mod_buf].fileformat
  if ff and ff ~= "" then
    vim.bo[orig_buf].fileformat = ff
  end
  vim.bo[orig_buf].modifiable = false

  -- 10. Save window options to restore cleanly on diff close
  local saved_mod_win_opts = {
    wrap = vim.wo[mod_win].wrap,
    diff = vim.wo[mod_win].diff,
    scrollbind = vim.wo[mod_win].scrollbind,
    cursorbind = vim.wo[mod_win].cursorbind,
    winbar = vim.wo[mod_win].winbar,
    foldmethod = vim.wo[mod_win].foldmethod,
    foldenable = vim.wo[mod_win].foldenable,
    foldcolumn = vim.wo[mod_win].foldcolumn,
  }

  -- 11. Split windows: old/original on the left, new/modified on the right
  local layout = config.get().diff.layout or "vertical"
  local split_cmd = layout == "horizontal" and "split" or "vsplit"

  vim.api.nvim_set_current_win(mod_win)
  vim.cmd("leftabove " .. split_cmd)
  local orig_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(orig_win, orig_buf)
  vim.api.nvim_win_set_buf(mod_win, mod_buf)

  -- Guarantee old is on the left / top and new is on the right / bottom
  if layout ~= "horizontal" then
    local p_orig = vim.api.nvim_win_get_position(orig_win)
    local p_mod = vim.api.nvim_win_get_position(mod_win)
    if p_orig[2] > p_mod[2] then
      orig_win, mod_win = mod_win, orig_win
      vim.api.nvim_win_set_buf(orig_win, orig_buf)
      vim.api.nvim_win_set_buf(mod_win, mod_buf)
    end
    -- Equalize widths 50/50
    local total_w = vim.api.nvim_win_get_width(orig_win) + vim.api.nvim_win_get_width(mod_win)
    local half = math.floor(total_w / 2)
    pcall(vim.api.nvim_win_set_width, orig_win, half)
    pcall(vim.api.nvim_win_set_width, mod_win, total_w - half)
  else
    local p_orig = vim.api.nvim_win_get_position(orig_win)
    local p_mod = vim.api.nvim_win_get_position(mod_win)
    if p_orig[1] > p_mod[1] then
      orig_win, mod_win = mod_win, orig_win
      vim.api.nvim_win_set_buf(orig_win, orig_buf)
      vim.api.nvim_win_set_buf(mod_win, mod_buf)
    end
    -- Equalize heights 50/50
    local total_h = vim.api.nvim_win_get_height(orig_win) + vim.api.nvim_win_get_height(mod_win)
    local half = math.floor(total_h / 2)
    pcall(vim.api.nvim_win_set_height, orig_win, half)
    pcall(vim.api.nvim_win_set_height, mod_win, total_h - half)
  end

  -- Turn off diff in all other windows in this tabpage first
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= orig_win and win ~= mod_win and vim.wo[win].diff then
      pcall(vim.api.nvim_win_call, win, function() vim.cmd("diffoff") end)
    end
  end

  -- Activate diff mode on both windows
  vim.api.nvim_win_call(orig_win, function()
    vim.cmd("diffthis")
  end)
  vim.api.nvim_win_call(mod_win, function()
    vim.cmd("diffthis")
  end)

  -- Immediately update diff rendering and folds
  pcall(vim.cmd, "diffupdate")

  -- Focus modified window on the right for user interaction
  vim.api.nvim_set_current_win(mod_win)

  -- Setup winbars with helpful controls
  local km = config.get().keymaps or {}
  local accept_k = km.diff_accept or "<leader>ya"
  local reject_k = km.diff_reject or "<leader>yr"
  local close_k = km.diff_close or "<leader>yq"
  local winbar_text = string.format("%%#Title# [Jetski Diff] %%#Normal#Accept: %s (:JetskiAccept) | Reject: %s (:JetskiReject) | Close: %s | Nav: ]c / [c", accept_k, reject_k, close_k)
  pcall(function()
    vim.wo[orig_win].winbar = string.format("%%#Comment# [Original: %s] %s", orig_source or "base", winbar_text)
    vim.wo[mod_win].winbar = "%#Special# [Modified by Agent] " .. winbar_text
  end)

  M.active_diff = {
    orig_win = orig_win,
    mod_win = mod_win,
    orig_buf = orig_buf,
    mod_buf = mod_buf,
    filepath = filepath,
    saved_opts = saved_mod_win_opts,
    source = orig_source,
  }

  -- Keybindings
  local accept_key = km.diff_accept or "<leader>ya"
  local reject_key = km.diff_reject or "<leader>yr"
  local close_key = km.diff_close or "<leader>yq"

  vim.keymap.set("n", "q", function() M.close_diff_review() end, { buffer = orig_buf, silent = true, desc = "Close Jetski diff" })
  vim.keymap.set("n", "<leader>yq", function() M.close_diff_review() end, { buffer = orig_buf, silent = true, desc = "Close Jetski diff" })
  vim.keymap.set("n", "<leader>yq", function() M.close_diff_review() end, { buffer = mod_buf, silent = true, desc = "Close Jetski diff" })
  vim.keymap.set("n", "<leader>ya", function() M.accept_diff(filepath) end, { buffer = orig_buf, silent = true, desc = "Accept Jetski edits" })
  vim.keymap.set("n", "<leader>ya", function() M.accept_diff(filepath) end, { buffer = mod_buf, silent = true, desc = "Accept Jetski edits" })
  vim.keymap.set("n", "<leader>yr", function() M.reject_diff(filepath) end, { buffer = orig_buf, silent = true, desc = "Reject Jetski edits" })
  vim.keymap.set("n", "<leader>yr", function() M.reject_diff(filepath) end, { buffer = mod_buf, silent = true, desc = "Reject Jetski edits" })

  if accept_key ~= "<leader>ya" then
    vim.keymap.set("n", accept_key, function() M.accept_diff(filepath) end, { buffer = orig_buf, silent = true, desc = "Accept Jetski edits" })
    vim.keymap.set("n", accept_key, function() M.accept_diff(filepath) end, { buffer = mod_buf, silent = true, desc = "Accept Jetski edits" })
  end
  if reject_key ~= "<leader>yr" then
    vim.keymap.set("n", reject_key, function() M.reject_diff(filepath) end, { buffer = orig_buf, silent = true, desc = "Reject Jetski edits" })
    vim.keymap.set("n", reject_key, function() M.reject_diff(filepath) end, { buffer = mod_buf, silent = true, desc = "Reject Jetski edits" })
  end
  if close_key ~= "<leader>yq" then
    vim.keymap.set("n", close_key, function() M.close_diff_review() end, { buffer = orig_buf, silent = true, desc = "Close Jetski diff" })
    vim.keymap.set("n", close_key, function() M.close_diff_review() end, { buffer = mod_buf, silent = true, desc = "Close Jetski diff" })
  end

  -- Setup auto-cleanup autocommands: clean up if either window closes or either buffer is wiped
  local cleanup_group = vim.api.nvim_create_augroup("JetskiDiffCleanup_" .. orig_buf, { clear = true })
  vim.api.nvim_create_autocmd({ "BufWipeout" }, {
    group = cleanup_group,
    buffer = orig_buf,
    once = true,
    callback = function()
      if M.active_diff and M.active_diff.orig_buf == orig_buf then
        M.close_diff_review()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout" }, {
    group = cleanup_group,
    buffer = mod_buf,
    once = true,
    callback = function()
      if M.active_diff and M.active_diff.mod_buf == mod_buf then
        M.close_diff_review()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    group = cleanup_group,
    pattern = { tostring(orig_win), tostring(mod_win) },
    callback = function(ev)
      local closed_win = tonumber(ev.match)
      if M.active_diff and (M.active_diff.orig_win == closed_win or M.active_diff.mod_win == closed_win) then
        vim.schedule(function()
          M.close_diff_review()
        end)
      end
    end,
  })

  vim.notify(string.format("[Jetski] Reviewing diff for %s (vs %s)", fname, orig_source or "base"), vim.log.levels.INFO)
end

--- Closes active diff view and restores normal window options and keymaps.
function M.close_diff_review()
  if not M.active_diff then
    return
  end

  local d = M.active_diff
  M.active_diff = nil

  -- Clean up diff autocmd group
  if d.orig_buf then
    pcall(vim.api.nvim_del_augroup_by_name, "JetskiDiffCleanup_" .. d.orig_buf)
  end

  -- 1. Unbind buffer-local keymaps from mod_buf so macro recording and normal keys are fully restored
  if vim.api.nvim_buf_is_valid(d.mod_buf) then
    local km = config.get().keymaps or {}
    local keys = { "<leader>ya", "<leader>yr", "<leader>yq", "q", km.diff_accept, km.diff_reject, km.diff_close }
    for _, k in ipairs(keys) do
      if k and k ~= "" then
        pcall(vim.keymap.del, "n", k, { buffer = d.mod_buf })
      end
    end
  end

  -- If mod_win was closed by user, reuse orig_win for mod_buf so editor stays on file
  if not vim.api.nvim_win_is_valid(d.mod_win) and vim.api.nvim_win_is_valid(d.orig_win) then
    pcall(vim.api.nvim_win_set_buf, d.orig_win, d.mod_buf)
    d.mod_win = d.orig_win
    d.orig_win = nil
  end

  -- 2. Turn off diff and close orig_win
  if d.orig_win and vim.api.nvim_win_is_valid(d.orig_win) then
    pcall(vim.api.nvim_win_call, d.orig_win, function()
      vim.cmd("diffoff")
    end)
    pcall(vim.api.nvim_win_close, d.orig_win, true)
  end

  -- 3. Turn off diff and restore saved options on mod_win
  if d.mod_win and vim.api.nvim_win_is_valid(d.mod_win) then
    pcall(vim.api.nvim_win_call, d.mod_win, function()
      vim.cmd("diffoff")
      local saved = d.saved_opts or {}
      pcall(function() vim.wo[d.mod_win].winbar = saved.winbar or "" end)
      if saved.wrap ~= nil then
        pcall(function() vim.wo[d.mod_win].wrap = saved.wrap end)
      end
      if saved.foldmethod ~= nil then
        pcall(function() vim.wo[d.mod_win].foldmethod = saved.foldmethod end)
      end
      if saved.foldenable ~= nil then
        pcall(function() vim.wo[d.mod_win].foldenable = saved.foldenable end)
      end
      if saved.foldcolumn ~= nil then
        pcall(function() vim.wo[d.mod_win].foldcolumn = saved.foldcolumn end)
      end
      pcall(function() vim.wo[d.mod_win].scrollbind = false end)
      pcall(function() vim.wo[d.mod_win].cursorbind = false end)
    end)
    pcall(vim.api.nvim_set_current_win, d.mod_win)
  end

  -- 4. Delete scratch orig_buf
  if d.orig_buf and vim.api.nvim_buf_is_valid(d.orig_buf) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == d.orig_buf then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end
    pcall(vim.api.nvim_buf_delete, d.orig_buf, { force = true })
  end
end

--- Accepts all agent edits for the file, closes diff review, and clears snapshot.
--- If called without arguments, accepts active diff or resolves the target file.
---@param filepath? string File path to accept
function M.accept_diff(filepath)
  local target = filepath or (M.active_diff and M.active_diff.filepath) or M.resolve_diff_target()
  M.close_diff_review()

  if not target then
    vim.notify("[Jetski] No modified file to accept", vim.log.levels.INFO)
    return
  end

  target = workspace.normalize_path(target)
  local bufnr = vim.fn.bufnr(target)
  local file_exists = vim.fn.filereadable(target) == 1

  if file_exists then
    -- If mod_buf was edited/obtained in memory, save it to disk
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified then
      pcall(vim.api.nvim_buf_call, bufnr, function() vim.cmd("write") end)
    end
    -- Update snapshot to current accepted content so subsequent diffs compare against this state
    local lines = {}
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    else
      local ok_read, read_lines = pcall(vim.fn.readfile, target)
      lines = ok_read and read_lines or {}
    end
    M.snapshots[target] = {
      lines = lines,
      timestamp = vim.uv.now(),
      source = "accepted",
    }
  else
    -- File was deleted: clean up buffer if open
    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
    M.snapshots[target] = nil
  end

  local fname = vim.fn.fnamemodify(target, ":t")
  local agent_remaining = M.get_agent_modified_files()
  local remaining = #agent_remaining > 0 and agent_remaining or M.get_all_modified_files()
  local rem_count = 0
  for _, p in ipairs(remaining) do
    if p ~= target then
      rem_count = rem_count + 1
    end
  end
  if rem_count > 0 then
    vim.notify(string.format("[Jetski] Accepted edits for %s (%d modified file(s) remaining)", fname, rem_count), vim.log.levels.INFO)
  else
    vim.notify(string.format("[Jetski] Accepted edits for %s", fname), vim.log.levels.INFO)
  end
end

--- Rejects all agent edits, restores original pre-edit content, and saves file.
--- If the file was newly created by the agent, deletes the created file cleanly.
---@param filepath? string File path to reject
function M.reject_diff(filepath)
  local target = filepath or (M.active_diff and M.active_diff.filepath) or M.resolve_diff_target()
  if not target then
    M.close_diff_review()
    vim.notify("[Jetski] No modified file to reject", vim.log.levels.INFO)
    return
  end
  target = workspace.normalize_path(target)

  local snapshot = M.snapshots[target]
  local restore_lines = snapshot and snapshot.lines
  local is_new_file = (snapshot and snapshot.source == "new file")
    or (M.active_diff and M.active_diff.filepath == target and M.active_diff.source == "new file")

  if not restore_lines and not is_new_file then
    local vcs_lines, _ = M.get_vcs_base_lines(target)
    restore_lines = vcs_lines
  end

  M.close_diff_review()

  local fname = vim.fn.fnamemodify(target, ":t")
  local agent_remaining = M.get_agent_modified_files()
  local remaining = #agent_remaining > 0 and agent_remaining or M.get_all_modified_files()
  local rem_count = 0
  for _, p in ipairs(remaining) do
    if p ~= target then
      rem_count = rem_count + 1
    end
  end

  if is_new_file then
    -- File was created by agent and rejected: delete it cleanly
    if vim.fn.filereadable(target) == 1 then
      vim.fn.delete(target)
    end
    local bufnr = vim.fn.bufnr(target)
    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
    M.snapshots[target] = nil
    if rem_count > 0 then
      vim.notify(string.format("[Jetski] Rejected edits. Deleted new file %s (%d modified file(s) remaining)", fname, rem_count), vim.log.levels.INFO)
    else
      vim.notify(string.format("[Jetski] Rejected edits. Deleted new file %s", fname), vim.log.levels.INFO)
    end
  elseif restore_lines then
    M._is_rejecting = true
    -- Ensure parent directory exists before writing
    pcall(vim.fn.mkdir, vim.fn.fnamemodify(target, ":h"), "p")
    local ok_write = pcall(vim.fn.writefile, restore_lines, target)
    local bufnr = vim.fn.bufnr(target)
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, restore_lines)
      if ok_write then
        vim.bo[bufnr].modified = false
      end
    end
    M._is_rejecting = false
    -- Update snapshot to restored content
    M.snapshots[target] = {
      lines = restore_lines,
      timestamp = vim.uv.now(),
      source = "rejected",
    }
    if rem_count > 0 then
      vim.notify(string.format("[Jetski] Rejected edits for %s (%d modified file(s) remaining)", fname, rem_count), vim.log.levels.INFO)
    else
      vim.notify(string.format("[Jetski] Rejected edits. Restored original %s", fname), vim.log.levels.INFO)
    end
  else
    M.snapshots[target] = nil
    vim.notify("[Jetski] No pre-edit snapshot or base version found to restore from", vim.log.levels.WARN)
  end
end

return M
