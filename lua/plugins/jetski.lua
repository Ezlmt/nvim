return {
	"jetski",
	dir = vim.fn.stdpath("config") .. "/lua/local_plugins/jetski.nvim",
	lazy = false,
	cmd = {
		"Jetski",
		"JetskiToggle",
		"JetskiNew",
		"JetskiContinue",
		"JetskiKill",
		"JetskiStatus",
		"JetskiPreload",
		"JetskiAsk",
		"JetskiExplain",
		"JetskiRefactor",
		"JetskiFix",
		"JetskiTest",
		"JetskiComment",
		"JetskiCommentDelete",
		"JetskiCommentList",
		"JetskiCommentSubmit",
		"JetskiCommentClear",
		"JetskiDiff",
		"JetskiAccept",
		"JetskiReject",
		"JetskiCloseDiff",
		"JetskiPlan",
		"JetskiWalkthrough",
		"JetskiArtifacts",
		"JetskiUpdateSkill",
	},
	opts = {
		cmd = "/google/bin/releases/jetski-devs/tools/cli",

		-- 布局模式："vertical" (类似主流 IDE 的右侧边栏) | "float" (居中浮窗) | "horizontal" (底部横条)
		open_mode = "vertical",
		vertical = {
			side = "right",
			width = 0.42,
		},
		float = {
			width = 0.85,
			height = 0.85,
			border = "rounded",
			title = " Jetski Agent ",
		},

		-- 极速唤起：启动时后台静默预热，按下快捷键瞬间秒开，无冷启动等待
		preload = true,

		-- 自动生命周期与文件同步
		kill_on_exit = true, -- 退出 Neovim 时自动释放 Jetski 进程
		auto_close = true, -- CLI 退出时自动关闭窗口并释放缓冲区
		auto_revert = true, -- Jetski 修改文件后自动安全刷新 Neovim 缓冲区

		-- 快捷键前缀（采用主流 IDE 风格的 <leader>a 语义）
		keymap_prefix = "<leader>a",
		enable_default_keymaps = true,
		keymaps = {
			toggle = "<leader>aj",
			new_session = "<leader>an",
			continue_session = "<leader>ak",
			ask = "<leader>aa",
			explain = "<leader>ae",
			refactor = "<leader>ar",
			fix = "<leader>af",
			test = "<leader>at",
			comment = "<leader>ac",
			comment_delete = "<leader>ad",
			comment_list = "<leader>al",
			comment_submit = "<leader>as",
			comment_clear = "<leader>aC",
			diff_review = "<leader>yd",
			diff_accept = "<leader>ya",
			diff_reject = "<leader>yr",
			diff_close = "<leader>yq",
			open_plan = "<leader>ap",
			open_walkthrough = "<leader>aw",
			artifacts = "<leader>aA",
		},
	},
	keys = {
		-- 1. 主流 IDE 风格一键呼出/隐藏快捷键 (支持 Normal 模式与 Terminal 模式随时切换)
		{
			"<M-a>",
			function()
				require("jetski").toggle()
			end,
			mode = { "n", "t" },
			desc = "Toggle Jetski Panel (Alt+a)",
		},
		{
			"<leader>ai",
			function()
				require("jetski").toggle()
			end,
			desc = "Toggle Jetski Panel (Leader + ai)",
		},
		{
			"<leader>aj",
			function()
				require("jetski").toggle()
			end,
			desc = "Toggle Jetski Panel (Leader + aj)",
		},
		{
			"<leader>tj",
			function()
				require("jetski").toggle()
			end,
			desc = "Toggle Jetski Panel (under Toggle group)",
		},

		-- 2. 会话生命周期
		{
			"<leader>an",
			function()
				require("jetski").new_session()
			end,
			desc = "New Jetski Session",
		},
		{
			"<leader>ak",
			function()
				require("jetski").continue_session()
			end,
			desc = "Continue Last Session",
		},

		-- 3. 智能代码上下文交互 (Normal & Visual 模式)
		{
			"<leader>aa",
			function()
				require("jetski").ask()
			end,
			mode = { "n", "v" },
			desc = "Ask Jetski (Buffer / Selection Context)",
		},
		{
			"<leader>ae",
			function()
				require("jetski").explain()
			end,
			mode = { "n", "v" },
			desc = "Explain Code with Jetski",
		},
		{
			"<leader>ar",
			function()
				require("jetski").refactor()
			end,
			mode = { "n", "v" },
			desc = "Refactor Code with Jetski",
		},
		{
			"<leader>af",
			function()
				require("jetski").fix()
			end,
			desc = "Fix LSP / Compiler Diagnostics",
		},
		{
			"<leader>at",
			function()
				require("jetski").test()
			end,
			mode = { "n", "v" },
			desc = "Generate Unit Tests",
		},

		-- 4. 代码批注与审阅 (类似 Cider-J CommentsManager)
		{
			"<leader>ac",
			function()
				require("jetski.comments").add_comment()
			end,
			mode = "n",
			desc = "Add/Edit Comment on Line",
		},
		{
			"<leader>ac",
			function()
				require("jetski.comments").add_visual_comment()
			end,
			mode = "v",
			desc = "Add Comment on Selection",
		},
		{
			"<leader>as",
			function()
				require("jetski.comments").submit_all_comments()
			end,
			desc = "Submit All Comments to Jetski",
		},
		{
			"<leader>al",
			function()
				require("jetski.comments").list_comments()
			end,
			desc = "List Pending Comments",
		},
		{
			"<leader>aC",
			function()
				require("jetski.comments").clear_all_comments()
			end,
			desc = "Clear All Comments",
		},

		-- 5. Diff 审查与变更采纳
		{
			"<leader>yd",
			function()
				require("jetski.diff").review_diff()
			end,
			desc = "Review Agent Diff",
		},
		{
			"<leader>ya",
			function()
				require("jetski.diff").accept_diff()
			end,
			desc = "Accept Agent Diff Edits",
		},
		{
			"<leader>yr",
			function()
				require("jetski.diff").reject_diff()
			end,
			desc = "Reject Agent Diff Edits",
		},
		{
			"<leader>yq",
			function()
				require("jetski.diff").close_diff_review()
			end,
			desc = "Close Diff Review",
		},

		-- 6. Implementation Plan 与 Artifacts 浏览
		{
			"<leader>ap",
			function()
				require("jetski.artifacts").open_plan()
			end,
			desc = "Open Implementation Plan",
		},
		{
			"<leader>aw",
			function()
				require("jetski.artifacts").open_walkthrough()
			end,
			desc = "Open Walkthrough",
		},
		{
			"<leader>aA",
			function()
				require("jetski.artifacts").list_artifacts()
			end,
			desc = "Browse Artifacts",
		},
	},
	config = function(_, opts)
		require("jetski").setup(opts)
	end,
}
