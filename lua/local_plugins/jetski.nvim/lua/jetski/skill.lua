--- Skill management and synchronization for Jetski Neovim integration.
local config = require("jetski.config")

local M = {}

--- Finds the path to the bundled SKILL.md inside the plugin repo.
---@return string|nil
function M.get_bundled_skill_path()
  local info = debug.getinfo(1, "S")
  if not info or not info.source then return nil end
  local src = info.source:sub(2) -- strip leading '@'
  local plugin_root = vim.fn.fnamemodify(src, ":h:h:h")
  local skill_path = plugin_root .. "/SKILL.md"
  if vim.fn.filereadable(skill_path) == 1 then
    return skill_path
  end
  return nil
end

--- Target path in user's global gemini skills directory.
---@return string
function M.get_target_skill_path()
  local home = os.getenv("HOME") or vim.fn.expand("~")
  return home .. "/.gemini/jetski/skills/nvim/SKILL.md"
end

--- Copies the bundled SKILL.md to the user's gemini skills directory.
---@return boolean success
function M.copy_skill_file()
  local src = M.get_bundled_skill_path()
  if not src then
    vim.notify("[Jetski] Bundled SKILL.md not found in plugin repository", vim.log.levels.ERROR)
    return false
  end

  local dest = M.get_target_skill_path()
  local dest_dir = vim.fn.fnamemodify(dest, ":h")

  local mkdir_ok, _ = pcall(vim.fn.mkdir, dest_dir, "p")
  if not mkdir_ok then
    -- Silently return false if filesystem is read-only
    return false
  end

  local uv = vim.uv or vim.loop
  local success, err = uv.fs_copyfile(src, dest)
  if success then
    vim.notify(string.format("[Jetski] Successfully installed skill to %s", dest), vim.log.levels.INFO)
    return true
  else
    return false
  end
end

--- Checks if the skill is installed, and installs it if missing.
function M.check_skill_installed()
  if config.get().skip_skill_check then
    return
  end
  local dest = M.get_target_skill_path()
  if vim.fn.filereadable(dest) == 0 then
    pcall(M.copy_skill_file)
  end
end

--- Explicit user command to update the skill file.
function M.update_skill()
  local ok = M.copy_skill_file()
  if not ok then
    vim.notify("[Jetski] Could not copy skill to " .. M.get_target_skill_path(), vim.log.levels.WARN)
  end
end

return M
