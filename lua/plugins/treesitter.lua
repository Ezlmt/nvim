return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	event = "VeryLazy",
	init = function()
		-- Neovim 0.12 compatibility shim for nvim-treesitter (master branch)
		-- In Neovim 0.12+, query captures are passed as tables of nodes (TSNode[])
		-- rather than single nodes. nvim-treesitter query directives/predicates expect single nodes.
		local orig_add_directive = vim.treesitter.query.add_directive
		vim.treesitter.query.add_directive = function(name, handler, opts)
			if type(opts) == "table" and opts.all == false then
				local orig_handler = handler
				handler = function(match, pattern, source, pred, metadata)
					local compat_match = setmetatable({}, {
						__index = function(_, k)
							local v = match[k]
							if type(v) == "table" and not (getmetatable(v) and getmetatable(v).range) then
								return v[#v] or v[1]
							end
							return v
						end,
						__pairs = function()
							return pairs(match)
						end,
					})
					return orig_handler(compat_match, pattern, source, pred, metadata)
				end
			end
			return orig_add_directive(name, handler, opts)
		end

		local orig_add_predicate = vim.treesitter.query.add_predicate
		vim.treesitter.query.add_predicate = function(name, handler, opts)
			if type(opts) == "table" and opts.all == false then
				local orig_handler = handler
				handler = function(match, pattern, source, pred)
					local compat_match = setmetatable({}, {
						__index = function(_, k)
							local v = match[k]
							if type(v) == "table" and not (getmetatable(v) and getmetatable(v).range) then
								return v[#v] or v[1]
							end
							return v
						end,
						__pairs = function()
							return pairs(match)
						end,
					})
					return orig_handler(compat_match, pattern, source, pred)
				end
			end
			return orig_add_predicate(name, handler, opts)
		end

		local orig_get_range = vim.treesitter.get_range
		vim.treesitter.get_range = function(node, source, metadata)
			if type(node) == "table" and not (getmetatable(node) and getmetatable(node).range) then
				node = node[#node] or node[1]
			end
			if not node then
				return { 0, 0, 0, 0 }
			end
			return orig_get_range(node, source, metadata)
		end

		local orig_get_node_text = vim.treesitter.get_node_text
		vim.treesitter.get_node_text = function(node, source, opts)
			if type(node) == "table" and not (getmetatable(node) and getmetatable(node).range) then
				node = node[#node] or node[1]
			end
			if not node then
				return ""
			end
			return orig_get_node_text(node, source, opts)
		end
	end,
	main = "nvim-treesitter.configs",
	opts = {
		ensure_installed = {
			"lua",
			"toml",
			"cpp",
			"c",
			"python",
			"go",
			"rust",
			"proto",
			"bash",
			"json",
			"yaml",
			"markdown",
			"markdown_inline",
		},
		highlight = { enable = true },
		indent = { enable = true },
	},
  opts_extend = { "ensure_installed" },
}
