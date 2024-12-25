local M = {}

-- command exec

---@alias command string|function

---@class OperatorConfig
---@field next command Command to jump next.
---@field prev command Command to jump next.
---@field desc string|nil The opts of map command
---@field mode string|table|nil Mode for the keybindings. If not set, "n" will be used.

-- record the last operation
---@type command
M._next = nil
---@type command
M._prev = nil

---@param command command
local function replay(command)
	if command == nil then
		vim.notify(string.format("nothing to repeat"), vim.log.levels.INFO, { title = "nap.nvim" })
		return
	end

	if type(command) == "string" then
		local keys = vim.api.nvim_replace_termcodes(command, true, false, true)
		vim.api.nvim_feedkeys(keys, "n", false)
	else
		command()
	end
end

function M.repeat_next()
	replay(M._next)
end

function M.repeat_prev()
	replay(M._prev)
end

-- add/override an operator
---@param operator string Operator key, usually is a single character.
---@param config nil|OperatorConfig Operator configs, including commands and description.
function M.map(operator, config)
	local mode = config and config.mode or "n" or "n"
	local lhs = M.options.prefix .. operator

	if not config then
		vim.keymap.del(mode, lhs)
		return
	end

	vim.keymap.set(mode, lhs, function()
		M._next = config.next
		M._prev = config.prev
	end, {
		desc = M.options.desc_prefix .. (config.desc or ""),
	})
end

-- setup

---@class Option
M.defaults = {
	prefix = "<leader>n", -- <prefix><operator> to jump to next
	desc_prefix = "nap.nvim - ", -- Prefix string added to keymaps description
	-- a list of keys to exclude from the following default operators.
	-- if set to boolean true, then exclude everything
	exclude_default_operators = {},
	-- All operators.
	---@type table<string, OperatorConfig>
	operators = {
		["b"] = {
			next = "<cmd>bnext<cr>",
			prev = "<cmd>bprevious<cr>",
			desc = "navigate buffer",
		},
		["B"] = {
			next = "<cmd>blast<cr>",
			prev = "<cmd>bfirst<cr>",
			desc = "navigate buffer extremes",
		},
		["d"] = {
			next = vim.diagnostic.goto_next,
			prev = vim.diagnostic.goto_prev,
			desc = "navigate diagnostics",
			mode = { "n", "x", "o" },
		},
		["q"] = {
			next = "<cmd>cnext<cr>",
			prev = "<cmd>cprevious<cr>",
			desc = "navigate quickfix",
		},
		["Q"] = {
			next = "<cmd>clast<cr>",
			prev = "<cmd>cfirst<cr>",
			desc = "navigate quickfix extremes",
		},
		["z"] = {
			next = "zj",
			prev = "zk",
			desc = "navigate folds",
			mode = { "n", "x", "o" },
		},
	},
}

---@param options Option
function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, options or {})

	if M.options.exclude_default_operators ~= true then
		-- buld a table for search speed
		local exclude_table = {}
		for _, v in ipairs(M.options.exclude_default_operators) do
			exclude_table[v] = true
		end
		for key, config in pairs(M.options.operators) do
			if exclude_table[key] == nil then
				M.map(key, config)
			end
		end
	end
end

-- plugin integrations

---@return OperatorConfig
function M.trouble()
	local trouble = require("trouble")
	local jump = function(f)
		return function()
			trouble[f]({ jump = true })
		end
	end

	return {
		next = jump("next"),
		prev = jump("prev"),
		mode = { "n", "x", "o" },
		desc = "navigate trouble",
	}
end

---@return OperatorConfig
function M.undo()
	return {
		next = vim.cmd.earlier,
		prev = vim.cmd.later,
		mode = { "n", "x", "o" },
		desc = "navigate undo tree",
	}
end

---@return OperatorConfig
function M.gitsigns()
	local gitsigns = require("gitsigns")

	return {
		next = gitsigns.next_hunk,
		prev = gitsigns.prev_hunk,
		mode = { "n", "x", "o" },
		desc = "navigate diffs",
	}
end

---@return OperatorConfig
function M.illuminate()
	local illuminate = require("illuminate")

	return {
		next = illuminate.goto_next_reference,
		prev = illuminate.goto_prev_reference,
		mode = { "n", "x", "o" },
		desc = "navigate cursor symbol",
	}
end

return M
