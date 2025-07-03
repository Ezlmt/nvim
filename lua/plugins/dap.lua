return {
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		keys = {
			{
				"<F5>",
				function()
					require("dap").continue()
				end,
				desc = "Debug • go on/start",
			},
			{
				"<F10>",
				function()
					require("dap").step_over()
				end,
				desc = "Debug • Step Over",
			},
			{
				"<F11>",
				function()
					require("dap").step_into()
				end,
				desc = "Debug • Step Into",
			},
			{
				"<F12>",
				function()
					require("dap").step_out()
				end,
				desc = "Debug • Step Out",
			},
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Debug • Breakpoint",
			},
			{
				"<leader>dB",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition > "))
				end,
				desc = "Debug • Conditional Breakpoint",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "Debug • REPL",
			},
			{
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Debug • Rerun",
			},
		},
		config = function()
			local palette_ok, palette = pcall(function()
				return require("catppuccin.palettes").get_palette() -- latte/frappe/…
			end)
			if not palette_ok then
				palette = {
					red = "#f38ba8",
					yellow = "#f9e2af",
					sky = "#89dceb",
					mauve = "#cba6f7",
					green = "#a6e3a1",
				}
			end

			local icons = {
				breakpoint = "",
				breakpoint_cond = "",
				breakpoint_rejected = "",
				logpoint = "󰌶",
				stopped = "",
			}

			local sign = vim.fn.sign_define
			sign("DapBreakpoint", { text = icons.breakpoint, texthl = "DapBreakpoint" })
			sign("DapBreakpointCondition", { text = icons.breakpoint_cond, texthl = "DapBreakpointCondition" })
			sign("DapBreakpointRejected", { text = icons.breakpoint_rejected, texthl = "DapBreakpointRejected" })
			sign("DapLogPoint", { text = icons.logpoint, texthl = "DapLogPoint" })
			sign("DapStopped", {
				text = icons.stopped,
				texthl = "DapStopped",
				linehl = "DapStoppedLine",
				numhl = "DapStopped",
			})

			local hl = vim.api.nvim_set_hl
			local function define_hl()
				hl(0, "DapBreakpoint", { fg = palette.red, bold = true })
				hl(0, "DapBreakpointCondition", { fg = palette.yellow, bold = true })
				hl(0, "DapBreakpointRejected", { fg = palette.sky, bold = true })
				hl(0, "DapLogPoint", { fg = palette.mauve, bold = true })
				hl(0, "DapStopped", { fg = palette.green, bold = true })
				hl(0, "DapStoppedLine", { bg = palette.surface0 })
			end
			define_hl()
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		event = "VeryLazy",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},
		opts = {
			layouts = {
				{
					elements = { "scopes", "breakpoints", "stacks", "watches" },
					size = 40,
					position = "left",
				},
				{
					elements = { "repl", "console" },
					size = 10,
					position = "bottom",
				},
			},
		},
		config = function(_, opts)
			local dap, dapui = require("dap"), require("dapui")
			dapui.setup(opts)
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		event = "VeryLazy",
		dependencies = {
			"williamboman/mason.nvim",
			"mfussenegger/nvim-dap",
		},
		opts = {
			handlers = {},
			ensure_installed = {},
		},
	},
}
