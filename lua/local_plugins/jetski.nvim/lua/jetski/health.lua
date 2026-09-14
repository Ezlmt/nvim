--- Health check for :checkhealth jetski
local config = require("jetski.config")
local workspace = require("jetski.workspace")
local skill = require("jetski.skill")

local M = {}

local health = vim.health or {
  start = vim.fn["health#report_start"],
  ok = vim.fn["health#report_ok"],
  warn = vim.fn["health#report_warn"],
  error = vim.fn["health#report_error"],
  info = vim.fn["health#report_info"],
}

function M.check()
  health.start("Jetski Neovim Integration")

  -- 1. Check Neovim Version
  if vim.fn.has("nvim-0.10.0") == 1 then
    health.ok(string.format("Neovim version %s (>= 0.10.0 supported)", vim.version()))
  else
    health.warn("Neovim version is older than 0.10.0. Some modern UI features may have limited styling.")
  end

  -- 2. Check Jetski CLI binary
  local cfg = config.get()
  local bin = cfg.cmd
  if not bin or bin == "" then
    bin = config.detect_binary()
  end

  if bin and bin ~= "" then
    local exists = (bin:sub(1, 1) == "/" and vim.fn.filereadable(bin) == 1) or (vim.fn.executable(bin) == 1)
    if exists then
      health.ok(string.format("Jetski CLI binary located: %s", bin))
    else
      health.error(string.format("Configured Jetski CLI binary not found or not executable: %s", bin), {
        "Ensure /google/bin/releases/jetski-devs/tools/cli exists or 'jetski' is in your PATH.",
      })
    end
  else
    health.error("Could not find any Jetski CLI binary", {
      "Verify that /google/bin/releases/jetski-devs/tools/cli is accessible.",
    })
  end

  -- 3. Check Neovim RPC Server
  local servername = vim.v.servername
  if servername and servername ~= "" then
    health.ok(string.format("Neovim RPC server active: %s", servername))
  else
    health.warn("Neovim RPC server name not set. Remote editor commands from agent may not route properly.")
  end

  -- 4. Check Workspace and VCS detection
  local ws = workspace.detect_workspace()
  if ws.is_google3 then
    health.ok(string.format("Google3 CitC workspace detected (client: %s, user: %s)", ws.citc_client or "unknown", ws.citc_user or "unknown"))
    health.info(string.format("Workspace root: %s", ws.workspace_root))
    if ws.vcs == "jj" then
      health.ok("VCS: Jujutsu (jj) detected")
    elseif ws.vcs == "hg" then
      health.ok("VCS: Fig / Mercurial (hg) detected")
    elseif ws.vcs == "p4" then
      health.ok("VCS: Piper / Perforce (p4 / g4) detected")
    else
      health.info(string.format("VCS: %s", ws.vcs or "unknown"))
    end
  elseif ws.type == "git" then
    health.ok(string.format("Git repository detected: %s", ws.workspace_root))
    health.ok("VCS: Git detected")
  else
    health.info(string.format("Working directory: %s", ws.workspace_root))
    health.info(string.format("VCS: %s", ws.vcs or "unknown"))
  end

  -- Check available VCS tools
  local vcs_tools = {}
  if vim.fn.executable("g4") == 1 or vim.fn.executable("/usr/bin/g4") == 1 then
    table.insert(vcs_tools, "g4")
  end
  if vim.fn.executable("p4") == 1 or vim.fn.executable("/usr/bin/p4") == 1 then
    table.insert(vcs_tools, "p4")
  end
  if vim.fn.executable("hg") == 1 or vim.fn.executable("/usr/bin/hg") == 1 then
    table.insert(vcs_tools, "hg")
  end
  if vim.fn.executable("jj") == 1 then
    table.insert(vcs_tools, "jj")
  end
  if vim.fn.executable("git") == 1 then
    table.insert(vcs_tools, "git")
  end
  if #vcs_tools > 0 then
    health.ok(string.format("Available VCS binaries: %s", table.concat(vcs_tools, ", ")))
  else
    health.warn("No recognized VCS binaries (g4, p4, hg, jj, git) found in PATH.")
  end

  -- 5. Check Skill file
  local skill_dest = skill.get_target_skill_path()
  if vim.fn.filereadable(skill_dest) == 1 then
    health.ok(string.format("Jetski agent skill installed: %s", skill_dest))
  else
    health.warn(string.format("Jetski agent skill not found at %s", skill_dest), {
      "Run ':JetskiUpdateSkill' to install the companion skill so the agent knows how to interact with Neovim.",
    })
  end

  -- 6. Check Diff and Comment settings
  health.ok(string.format("Diff review layout: %s | Auto-revert: %s", cfg.diff.layout, tostring(cfg.auto_revert)))
  health.ok(string.format("Comment sign: '%s' | Keymap prefix: '%s'", cfg.comments.sign, cfg.keymap_prefix))
end

return M
