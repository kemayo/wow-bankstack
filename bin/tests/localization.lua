-- Run from the repository root: lua bin\tests\localization.lua
local ns = {}
local locale_path = "locale" .. package.config:sub(1, 1)
assert(loadfile(locale_path .. "locale.lua"))("BankStack", ns)
assert(loadfile(locale_path .. "enUS.lua"))("BankStack", ns)
assert(ns.L.OPTIONS_CONFIG_DESCRIPTION == "Basic settings")
assert(ns.L.HELP_COMMANDS:find("/stack bank bags", 1, true))

local english = ns.L
local prefix = "[translated] "
local translated = setmetatable({}, {
	__index = function(_, key)
		assert(rawget(english, key), "Missing English fallback: " .. key)
		return prefix .. english[key]
	end,
})

function _G.wipe(t)
	for key in pairs(t) do t[key] = nil end
	return t
end

_G.string.join = function(separator, ...) return table.concat({...}, separator) end
_G.unpack = unpack or _G.table.unpack
SlashCmdList = {}
_G.BANK = prefix .. "Bank"
_G.ACCOUNT_BANK_PANEL_TITLE = prefix .. "Warband"
for _, name in ipairs({
	"OPTIONS", "BAG_FILTER_JUNK", "NO", "ITEM_CONJURED", "ITEM_SOULBOUND",
	"IGNORE", "ADD", "REMOVE", "GROUPS", "ADVANCED_OPTIONS", "HELP_LABEL", "NONE",
	"BAG_CLEANUP_BAGS", "BAG_CLEANUP_BAGS_DESCRIPTION", "BAG_CLEANUP_BANK",
}) do
	_G[name] = prefix .. name
end
function _G.GetBindingText(binding, binding_prefix)
	assert(binding_prefix == "KEY_")
	return prefix .. binding
end
local registered, categories, messages, modules = {}, {}, {}, {}
local core = {
	L = translated,
	has_account_bank = true,
	has_new_bank = true,
	db = {ignore = {}, ignore_bags = {}, groups = {}, fubar_keybinds = {}},
	groups = {bags = {0}},
}
BankStack = core
function core.announce(_, text) messages[#messages + 1] = text end
function core.encode_bagslot(bag, slot) return bag * 1000 + slot end
function core.decode_bagslot(value) return math.floor(value / 1000), value % 1000 end
function core.is_valid_bag(bag) return bag == 0 end
function core.is_guild_bank_bag(bag) return bag >= 51 and bag <= 58 end
function core.CommandDecorator(fn) return fn end
function core.RegisterCallback() end
function core:NewModule(name)
	local module = {RegisterEvent = function() end}
	modules[name] = module
	return module
end
core.db_object = {
	RegisterNamespace = function(_, _, defaults) return defaults end,
}

local libraries = {
	["AceConfigRegistry-3.0"] = {
		RegisterOptionsTable = function(_, name, options) registered[name] = options end,
	},
	["AceConfigDialog-3.0"] = {
		AddToBlizOptions = function(_, name, label)
			categories[name] = label
			return {}, 1
		end,
	},
	["AceDBOptions-3.0"] = {
		GetOptionsTable = function() return {name = prefix .. "Profiles"} end,
	},
}
_G.LibStub = setmetatable({
	GetLibrary = function(_, name) return assert(libraries[name], name) end,
}, {
	__call = function(_, name, optional)
		if optional then return libraries[name] end
		return assert(libraries[name], name)
	end,
})

assert(loadfile("config.lua"))("BankStack", ns)
core.setup_config()
assert(loadfile("auto.lua"))()
modules.Auto:OnInitialize()
assert(loadfile("blizzard.lua"))("BankStack")
local setup_buttons = modules.Blizzard.SetupButtons
modules.Blizzard.SetupButtons = function() end
modules.Blizzard:OnInitialize()

local function assert_translated(value)
	assert(type(value) == "string" and value:sub(1, #prefix) == prefix, tostring(value))
end
local function check_options(options)
	for key, value in pairs(options) do
		if (key == "name" or key == "desc" or key == "usage") and type(value) == "string" then
			if value ~= "Blizzard" then assert_translated(value) end
		elseif key == "values" then
			for _, label in pairs(value) do assert_translated(label) end
		elseif type(value) == "table" then
			check_options(value)
		end
	end
end
for _, options in pairs(registered) do check_options(options) end
for name, label in pairs(categories) do
	if name ~= "BankStack" then assert_translated(label) end
end
assert(core.options.plugins.auto.auto.args.bank_opened.values.sort_bags == translated.ACTION_SORTBAGS)
assert(core.options.args.blizzard.plugins.hijack.hijack.name == translated.OPTIONS_BLIZZARD_REPLACE_BUTTONS)
core.has_new_bank = false
modules.Blizzard:OnInitialize()
assert(core.options.args.blizzard.plugins.hijack.hijack.name == translated.OPTIONS_BLIZZARD_SHOW_BUTTONS)

local ignore = registered.BankStackIgnore.args
ignore.add.set(nil, "-1 2")
assert(core.db.ignore[core.encode_bagslot(-1, 2)])
assert(messages[#messages] == translated.CHAT_MSG_SLOT_IGNORED:format(-1, 2))
ignore.list.func()
assert(messages[#messages] == translated.CHAT_MSG_IGNORING_SLOT:format(-1, 2))
ignore.remove.set(nil, "-1 2")
assert(not core.db.ignore[core.encode_bagslot(-1, 2)])
assert(messages[#messages] == translated.CHAT_MSG_SLOT_UNIGNORED:format(-1, 2))
ignore.add.set(nil, "-1")
assert(core.db.ignore_bags[-1])
assert(messages[#messages] == translated.CHAT_MSG_BAG_IGNORED:format(-1))
ignore.list.func()
assert(messages[#messages] == translated.CHAT_MSG_IGNORING_BAG:format(-1))
ignore.remove.set(nil, "-1")
assert(not core.db.ignore_bags[-1])
assert(messages[#messages] == translated.CHAT_MSG_BAG_UNIGNORED:format(-1))

local groups = registered.BankStackGroups.args
groups.add.set(nil, "test 0,999")
assert(#core.db.groups.test == 1 and core.db.groups.test[1] == 0)
assert(messages[#messages - 1] == translated.CHAT_MSG_INVALID_BAG_ID:format("999"))
assert(messages[#messages] == translated.CHAT_MSG_GROUP_ADDED:format("test", "0"))
groups.list.func()
assert(messages[#messages - 3] == translated.CHAT_MSG_BUILT_IN_GROUPS)
assert(messages[#messages - 1] == translated.CHAT_MSG_CUSTOM_GROUPS)
groups.remove.set(nil, "test")
assert(not core.db.groups.test)
assert(messages[#messages] == translated.CHAT_MSG_GROUP_REMOVED:format("test"))

local launcher = registered.BankStackLauncher
launcher.set({"sortbags"}, "ALT-CTRL-SHIFT-BUTTON1")
assert(core.db.fubar_keybinds["ALT-CTRL-SHIFT-BUTTON1"] == "sortbags")
assert(launcher.get({"sortbags"}) == "ALT-CTRL-SHIFT-BUTTON1")
assert(launcher.args.sortbags.values["ALT-CTRL-SHIFT-BUTTON1"] ==
	GetBindingText("ALT-CTRL-SHIFT-BUTTON1", "KEY_"))
assert(core.options.name == OPTIONS)
assert(core.options.args.sorting.args.junk.name == BAG_FILTER_JUNK)
assert(core.options.args.sorting.args.junk.values[0] == NO)
assert(core.options.args.sorting.args.conjured.name == ITEM_CONJURED)
assert(core.options.args.sorting.args.soulbound.name == ITEM_SOULBOUND)
assert(registered.BankStackIgnore.name == IGNORE)
assert(registered.BankStackIgnore.args.add.name == ADD)
assert(registered.BankStackIgnore.args.remove.name == REMOVE)
assert(registered.BankStackGroups.name == GROUPS)
assert(registered.BankStackAdvanced.name == ADVANCED_OPTIONS)
assert(categories.BankStackHelp == HELP_LABEL)
assert(core.options.plugins.auto.auto.args.bank_opened.values.none == NONE)

local button_descriptions = {}
_G.BagItemAutoSortButton = {}
_G.BankPanel = {AutoSortButton = {}}
function modules.Blizzard:MakeButton(_, _, label, desc)
	button_descriptions[label] = desc
	return {SetAllPoints = function() end}
end
core.has_new_bank = true
setup_buttons(modules.Blizzard)
assert(button_descriptions[BAG_CLEANUP_BANK] == translated.TOOLTIP_SORT_BANK)
assert(button_descriptions[BAG_CLEANUP_BAGS] == BAG_CLEANUP_BAGS_DESCRIPTION)

local dataobject
libraries["LibDataBroker-1.1"] = {
	GetDataObjectByName = function() end,
	NewDataObject = function(_, _, object) dataobject = object; return object end,
}
dofile("ldb.lua")
local tooltip_lines = {}
dataobject.OnTooltipShow({
	AddLine = function() end,
	AddDoubleLine = function(_, left, right)
		tooltip_lines[#tooltip_lines + 1] = {left, right}
	end,
})
assert(tooltip_lines[1][1] == GetBindingText("ALT-CTRL-SHIFT-BUTTON1", "KEY_"))
assert(tooltip_lines[2][1] == NONE)
assert(tooltip_lines[1][2] == translated.ACTION_SORTBAGS)

print("PASS localized settings, categories, actions, bindings, tooltips, and formatted chat messages")
