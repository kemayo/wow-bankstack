local core = BankStack
local L = core.L

SLASH_BANKSTACKCONFIG1 = "/bankstack"
SlashCmdList["BANKSTACKCONFIG"] = function(arg)
	local command, arguments = string.match(arg, "^(%a+) ?(.*)")
	if core.menu_options[command] then
		return core.menu_options[command](arguments)
	end
	core.announce(0, "BankStack:", 1, 1, 1)
	for k,v in pairs(core.menu_options) do
		core.announce(0, " -"..k, 1, 1, 1)
	end
end

local config_settings = {
	verbosity = {
		get = function() return core.db.verbosity end,
		set = function(v)
			if string.match(v, "^[0-2]$") then
				core.db.verbosity = tonumber(v)
			end
		end,
		desc = "0-2",
	},
	junk = {
		get = function() return core.db.junk and "true" or "false" end,
		set = function() core.db.junk = not core.db.junk end,
		desc = "move junk to the end",
	},
	soul = {
		get = function() return core.db.soul and "true" or "false" end,
		set = function() core.db.soul = not core.db.soul end,
		desc = "move soul shards to the end",
	},
}
core.menu_options = {
	help = function()
		core.announce(0, "BankStack: Stacks things.", 1, 1, 1)
		core.announce(0, "/bankstack -- this menu.", 1, 1, 1)
		core.announce(0, "/sort -- rearrange your bags", 1, 1, 1)
		core.announce(0, "/sort bank -- rearrange your bank", 1, 1, 1)
		core.announce(0, "/stack -- fills stacks in your bank from your bags", 1, 1, 1)
		core.announce(0, "/stack reverse -- fills stacks in your bags from your bank", 1, 1, 1)
		core.announce(0, "/compress -- merges stacks in your bags", 1, 1, 1)
		core.announce(0, "/compress bank -- merges stacks in your bank", 1, 1, 1)
	end,
	config = function(arg)
		local command, arguments = string.match(arg, "^(%a+) ?(.*)")
		if config_settings[command] then
			config_settings[command].set(arguments)
			return core.announce(0, string.format(L.opt_set, command, config_settings[command].get()), 1, 1, 1)
		end
		core.announce(0, L.options, 1, 1, 1)
		for option, details in pairs(config_settings) do
			core.announce(0, " -" .. option .. ": " .. details.get() .. " (" .. details.desc .. ")", 1, 1, 1)
		end
	end,
}
