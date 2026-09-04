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

-- 兼容性修复：当系统 Git 使用 reftable 格式或元数据异常时，避免 lockfile 更新触发 "commit is nil"
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
		return ret
	end
end

require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
})
