local function fail(msg)
	io.stderr:write(msg .. "\n")
	vim.cmd("cquit 1")
end

local PRESET_CONTEXTS = {
	["zide-core"] = {
		"zig:zig:src/main.zig",
		"lua:lua:assets/themes/init.lua",
		"markdown:markdown:docs/todo/editor/theme_import.md",
		"vimdoc:help:dev_references/editors/neovim/runtime/doc/treesitter.txt",
	},
}

local function parse_args(argv)
	local opts = {
		profile = "base",
		contexts = {},
	}
	local i = 1
	while i <= #argv do
		local arg = argv[i]
		if arg == "--colorscheme" then
			i = i + 1
			opts.colorscheme = argv[i]
		elseif arg == "--out" then
			i = i + 1
			opts.out = argv[i]
		elseif arg == "--background" then
			i = i + 1
			opts.background = argv[i]
		elseif arg == "--profile" then
			i = i + 1
			opts.profile = argv[i]
		elseif arg == "--file" then
			i = i + 1
			opts.file = argv[i]
		elseif arg == "--filetype" then
			i = i + 1
			opts.filetype = argv[i]
		elseif arg == "--context" then
			i = i + 1
			table.insert(opts.contexts, argv[i])
		elseif arg == "--preset" then
			i = i + 1
			opts.preset = argv[i]
		else
			fail("unknown arg: " .. tostring(arg))
		end
		if argv[i] == nil then
			fail("missing value for previous arg")
		end
		i = i + 1
	end
	if not opts.colorscheme or opts.colorscheme == "" then
		fail("missing required --colorscheme <name>")
	end
	return opts
end

local function apply_preset_contexts(opts)
	if not opts.preset then
		return
	end
	local contexts = PRESET_CONTEXTS[opts.preset]
	if not contexts then
		fail("unknown preset: " .. tostring(opts.preset))
	end
	for _, spec in ipairs(contexts) do
		table.insert(opts.contexts, spec)
	end
end

local function hex_color(value)
	if type(value) ~= "number" then
		return nil
	end
	return string.format("#%06x", value)
end

local STYLE_KEYS = {
	"bold",
	"italic",
	"underline",
	"undercurl",
	"underdouble",
	"underdotted",
	"underdashed",
	"strikethrough",
	"reverse",
	"nocombine",
	"standout",
}

local function normalize_value(raw)
	if raw.link then
		return { link = raw.link }
	end

	local out = {}
	if raw.fg then
		out.fg = hex_color(raw.fg)
	end
	if raw.bg then
		out.bg = hex_color(raw.bg)
	end
	if raw.sp then
		out.sp = hex_color(raw.sp)
	end
	for _, key in ipairs(STYLE_KEYS) do
		if raw[key] then
			out[key] = true
		end
	end
	return next(out) and out or nil
end

local function parse_context(spec)
	local first = spec:find(":", 1, true)
	if not first then
		return { name = spec, filetype = spec }
	end
	local second = spec:find(":", first + 1, true)
	if second then
		return {
			name = spec:sub(1, first - 1),
			filetype = spec:sub(first + 1, second - 1),
			file = spec:sub(second + 1),
		}
	end
	return {
		name = spec:sub(1, first - 1),
		filetype = spec:sub(first + 1),
	}
end

local function absolutize_context_path(path)
	if not path or path == "" then
		return path
	end
	if vim.startswith(path, "/") then
		return path
	end
	return vim.fn.fnamemodify(path, ":p")
end

local function configure_buffer_context(file, filetype, profile)
	if not file and not filetype then
		return nil
	end

	if file then
		local escaped = vim.fn.fnameescape(absolutize_context_path(file))
		vim.cmd.edit(escaped)
	else
		vim.cmd.enew()
	end

	if filetype then
		vim.bo.filetype = filetype
	end

	if profile == "treesitter" then
		local lang = filetype
		if not lang or lang == "" then
			lang = vim.bo.filetype
		end
		if lang and lang ~= "" then
			local ok, err = pcall(vim.treesitter.start, 0, lang)
			if not ok then
				return tostring(err)
			end
		end
	end
	return nil
end

local function export_highlights()
	local names = vim.fn.getcompletion("", "highlight")
	table.sort(names)

	local groups = {}
	local captures = {}
	local links = {}

	for _, name in ipairs(names) do
		local raw = vim.api.nvim_get_hl(0, { name = name, link = true })
		local value = normalize_value(raw)
		if value then
			if value.link then
				links[name] = value.link
			elseif vim.startswith(name, "@") then
				captures[name] = value
			else
				groups[name] = value
			end
		end
	end

	return groups, captures, links
end

local function count_keys(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

local function export_snapshot(meta)
	local groups, captures, links = export_highlights()
	return {
		metadata = meta,
		groups = groups,
		captures = captures,
		links = links,
		counts = {
			groups = count_keys(groups),
			captures = count_keys(captures),
			links = count_keys(links),
		},
	}
end

local function aggregate_contexts(base, contexts)
	local out = {
		groups = vim.deepcopy(base.groups),
		captures = vim.deepcopy(base.captures),
		links = vim.deepcopy(base.links),
	}
	for _, context in ipairs(contexts) do
		for key, value in pairs(context.groups) do
			out.groups[key] = value
		end
		for key, value in pairs(context.captures) do
			out.captures[key] = value
		end
		for key, value in pairs(context.links) do
			out.links[key] = value
		end
	end
	out.counts = {
		groups = count_keys(out.groups),
		captures = count_keys(out.captures),
		links = count_keys(out.links),
	}
	return out
end

local function main(argv)
	local opts = parse_args(argv)
	apply_preset_contexts(opts)
	if opts.background then
		vim.o.background = opts.background
	end

	local ok, err = pcall(vim.cmd.colorscheme, opts.colorscheme)
	if not ok then
		fail("failed to load colorscheme '" .. opts.colorscheme .. "': " .. tostring(err))
	end

	local base_ts_error = configure_buffer_context(opts.file, opts.filetype, opts.profile)
	local base = export_snapshot({
		colorscheme = vim.g.colors_name or opts.colorscheme,
		background = vim.o.background,
		profile = opts.profile,
		nvim_version = vim.version(),
		file = opts.file,
		filetype = opts.filetype or vim.bo.filetype,
		treesitter_error = base_ts_error,
	})

	local contexts = {}
	for _, spec in ipairs(opts.contexts) do
		local context = parse_context(spec)
		vim.cmd("silent! bufdo bwipeout!")
		local ts_error = configure_buffer_context(context.file, context.filetype, opts.profile)
		table.insert(contexts, export_snapshot({
			name = context.name,
			colorscheme = vim.g.colors_name or opts.colorscheme,
			background = vim.o.background,
			profile = opts.profile,
			nvim_version = vim.version(),
			file = context.file,
			filetype = context.filetype or vim.bo.filetype,
			treesitter_error = ts_error,
		}))
	end

	local aggregate = aggregate_contexts(base, contexts)
	local payload = {
		metadata = {
			profile = opts.profile,
			colorscheme = vim.g.colors_name or opts.colorscheme,
			background = vim.o.background,
			nvim_version = vim.version(),
			context_count = #contexts,
			preset = opts.preset,
		},
		base = base,
		contexts = contexts,
		aggregate = aggregate,
	}

	local encoded = vim.json.encode(payload)
	if opts.out then
		vim.fn.writefile({ encoded }, opts.out)
	else
		io.stdout:write(encoded .. "\n")
	end
end

local argv = {}
for i = 1, #vim.v.argv do
	if vim.v.argv[i] == "--" then
		for j = i + 1, #vim.v.argv do
			table.insert(argv, vim.v.argv[j])
		end
		break
	end
end

main(argv)
vim.cmd("qall")
