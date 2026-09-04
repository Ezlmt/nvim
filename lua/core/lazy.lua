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

-- 兼容性修复：当系统 Git 使用 reftable 格式或元数据异常时，彻底杜绝 "commit is nil" 报错
local git_ok, Git = pcall(require, "lazy.manage.git")
if git_ok and Git.info then
	local orig_info = Git.info
	Git.info = function(repo, details)
		local ret = orig_info(repo, details)
		if not ret or not ret.commit then
			local out = vim.fn.system({ "git", "-C", repo, "rev-parse", "HEAD" })
			if vim.v.shell_error == 0 then
				local commit = vim.trim(out)
				if commit ~= "" then
					local b_out = vim.fn.system({ "git", "-C", repo, "rev-parse", "--abbrev-ref", "HEAD" })
					local branch = (vim.v.shell_error == 0 and vim.trim(b_out) ~= "HEAD") and vim.trim(b_out) or "main"
					ret = ret or {}
					ret.commit = commit
					if not ret.branch or ret.branch == ".invalid" then
						ret.branch = branch
					end
				end
			end
		end
		-- 终极兜底：如果依然拿不到 commit（如克隆中断、空目录），避免 assert 崩溃
		if not ret then
			ret = {}
		end
		if not ret.commit then
			local name = vim.fs.basename(repo)
			local lock_ok, Lock = pcall(require, "lazy.manage.lock")
			local lock_entry = (lock_ok and Lock.lock and Lock.lock[name]) or {}
			ret.commit = lock_entry.commit or "HEAD"
			ret.branch = ret.branch or lock_entry.branch or "main"
		end
		return ret
	end
end

-- 保护 lock.update，即使写入 lockfile 出现异常也不中断 Neovim 启动与异步任务
local lock_ok, Lock = pcall(require, "lazy.manage.lock")
if lock_ok and Lock.update then
	local orig_update = Lock.update
	Lock.update = function(...)
		local status, err = pcall(orig_update, ...)
		if not status and err then
			vim.schedule(function()
				vim.notify("[lazy] lockfile 更新提示: " .. tostring(err), vim.log.levels.WARN)
			end)
		end
	end
end

require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
})

