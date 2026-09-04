local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)

-- 兼容性修复：针对系统 Git 使用 reftable 存储、detached HEAD 或元数据异常
-- 使用 package.loaders 注入持久拦截，即便 lazy 在重载模块时清空 package.loaded 也依然生效
local function patch_git(Git)
	if not Git or Git._patched then
		return Git
	end
	Git._patched = true

	local orig_info = Git.info
	Git.info = function(repo, details)
		local ok, ret = pcall(orig_info, repo, details)
		if not ok or not ret or not ret.commit then
			ret = (ok and ret) or {}
			local out = vim.fn.system({ "git", "-C", repo, "rev-parse", "HEAD" })
			if vim.v.shell_error == 0 then
				local commit = vim.trim(out)
				if commit ~= "" then
					ret.commit = commit
					local b_out = vim.fn.system({ "git", "-C", repo, "rev-parse", "--abbrev-ref", "HEAD" })
					if vim.v.shell_error == 0 and vim.trim(b_out) ~= "" and vim.trim(b_out) ~= "HEAD" then
						ret.branch = vim.trim(b_out)
					end
				end
			end
		end

		-- 兜底：如果仍然缺少 commit 或 branch，彻底杜绝 assert 崩溃
		ret = ret or {}
		if not ret.commit or ret.commit == "" then
			local name = vim.fs.basename(repo)
			local lock_ok, Lock = pcall(require, "lazy.manage.lock")
			local lock_entry = (lock_ok and Lock.lock and Lock.lock[name]) or {}
			ret.commit = lock_entry.commit or "HEAD"
			ret.branch = ret.branch or lock_entry.branch or "main"
		end
		if not ret.branch or ret.branch == "" or ret.branch == ".invalid" then
			ret.branch = "main"
		end
		return ret
	end

	local orig_branch = Git.get_branch
	Git.get_branch = function(plugin)
		local ok, b = pcall(orig_branch, plugin)
		if ok and b and type(b) == "string" and b ~= "" then
			return b
		end
		local b_out = vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "--abbrev-ref", "HEAD" })
		if vim.v.shell_error == 0 and vim.trim(b_out) ~= "" and vim.trim(b_out) ~= "HEAD" then
			return vim.trim(b_out)
		end
		return plugin.branch or "main"
	end

	return Git
end

local function patch_lock(Lock)
	if not Lock or Lock._patched then
		return Lock
	end
	Lock._patched = true

	local orig_update = Lock.update
	Lock.update = function(...)
		local status, err = pcall(orig_update, ...)
		if not status and err then
			-- 如果写入 lockfile 出错，用纯安全方式生成完整 lockfile，避免 lockfile 损坏为 "{\n"
			pcall(function()
				local Config = require("lazy.core.config")
				local Git = require("lazy.manage.git")
				vim.fn.mkdir(vim.fn.fnamemodify(Config.options.lockfile, ":p:h"), "p")
				local f = io.open(Config.options.lockfile, "w")
				if not f then
					return
				end
				f:write("{\n")
				local lines = {}
				for name, plugin in pairs(Config.plugins or {}) do
					if not plugin._.is_local and plugin._.installed then
						local info = Git.info(plugin.dir) or {}
						local commit = info.commit or (Lock.lock and Lock.lock[name] and Lock.lock[name].commit) or "HEAD"
						local branch = info.branch or plugin.branch or "main"
						table.insert(lines, ([[  %q: { "branch": %q, "commit": %q }]]):format(name, branch, commit))
					end
				end
				table.sort(lines)
				f:write(table.concat(lines, ",\n"))
				f:write("\n}\n")
				f:close()
			end)
		end
	end

	return Lock
end

-- 注入 package.loaders
table.insert(package.loaders, 1, function(modname)
	if modname == "lazy.manage.git" then
		return function()
			for i = 2, #package.loaders do
				local fn = package.loaders[i](modname)
				if type(fn) == "function" then
					return patch_git(fn(modname))
				end
			end
		end
	elseif modname == "lazy.manage.lock" then
		return function()
			for i = 2, #package.loaders do
				local fn = package.loaders[i](modname)
				if type(fn) == "function" then
					return patch_lock(fn(modname))
				end
			end
		end
	end
end)

-- 如果模块已提前加载，立即应用 patch
if package.loaded["lazy.manage.git"] then
	patch_git(package.loaded["lazy.manage.git"])
end
if package.loaded["lazy.manage.lock"] then
	patch_lock(package.loaded["lazy.manage.lock"])
end

require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
})


