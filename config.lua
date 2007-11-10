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
		core.announce(0, "/stack bank bags -- fills stacks in your bags from your bank", 1, 1, 1)
		core.announce(0, "/compress -- merges stacks in your bags", 1, 1, 1)
		core.announce(0, "/compress bank -- merges stacks in your bank", 1, 1, 1)
	end,
	config = function(arg)
		local command, arguments = string.match(arg, "^(%a+) ?(.*)$")
		if config_settings[command] then
			config_settings[command].set(arguments)
			return core.announce(0, string.format(L.opt_set, command, config_settings[command].get()), 1, 1, 1)
		end
		core.announce(0, L.options, 1, 1, 1)
		for option, details in pairs(config_settings) do
			core.announce(0, " -" .. option .. ": " .. details.get() .. " (" .. details.desc .. ")", 1, 1, 1)
		end
	end,
	ignore = function(arg)
		local bag, slot = string.match(arg, "^([-%d]+) (%d+)$")
		if bag and slot then
			local bagslot = core.encode_bagslot(tonumber(bag), tonumber(slot))
			if core.db.ignore[bagslot] then
				core.db.ignore[bagslot] = nil
				core.announce(0, bag.." "..slot.." is no longer ignored.", 1, 1, 1)
			else
				core.db.ignore[bagslot] = true
				core.announce(0, bag.." "..slot.." ignored.", 1, 1, 1)
			end
		else
			core.announce(0, "/bankstack ignore [bag] [slot]", 1, 1, 1)
			core.announce(0, "(See http://wowwiki.com/BagID)", 1, 1, 1)
			for ignored,_ in pairs(core.db.ignore) do
				local bag, slot = core.decode_bagslot(ignored)
				core.announce(0, "Ignoring: "..bag.." "..slot, 1, 1, 1)
			end
		end
	end,
	group = function(arg)
		local group, action = string.match(arg, "^([^ ]+) ?(.*)$")
		if group and action then
			if action == 'remove' then
				core.db.groups[group] = nil
				core.announce(0, group .. " removed.", 1, 1, 1)
			else
				if not string.match(action, "^[%d%s,]$") then
					return core.announce(0, "Not a valid bag list.", 1, 0, 0)
				end
				if not core.db.groups[group] then
					core.db.groups[group] = {}
				end
				local bags = core.db.groups[group]
				-- Clean out the old group:
				if #bags > 0 then
					for i=#bags, 1, -1 do table.remove(bags, i) end
				end
				-- Populate with the new group:
				for v in string.gmatch(action, "[^%s,]+") do
					local bag = tonumber(v)
					if core.is_valid_bag(bag) then
						table.insert(bags, bag)
					else
						core.announce(0, v.." was not a valid bag id.", 1, 0, 0)
					end
				end
				core.announce(0, "Added group: "..group.." ("..string.join(", ", unpack(bags))..")", 1, 1, 1)
			end
		else
			core.announce(0, "/bankstack group [group] [remove | bagids]", 1, 1, 1)
			core.announce(0, "Example: /bankstack group herbs 6,7,8", 1, 1, 1)
			core.announce(0, "(See http://wowwiki.com/BagID)", 1, 1, 1)
			core.announce(0, "Built in groups:", 1, 1, 1)
			for group, bags in pairs(core.groups) do
				core.announce(0, "-"..group..": "..string.join(", ", unpack(bags)), 1, 1, 1)
			end
			core.announce(0, "Custom groups:", 1, 1, 1)
			for group, bags in pairs(core.db.groups) do
				core.announce(0, "-"..group..": "..string.join(", ", unpack(bags)), 1, 1, 1)
			end
		end
	end,
}
