local myname, ns = ...

local core = BankStack
local L = core.L
local Debug = core.Debug

local announce = core.announce

local sorted_bag_groups = {}
local function print_groups(groups)
	for group in pairs(groups) do
		table.insert(sorted_bag_groups, group)
	end
	table.sort(sorted_bag_groups)
	for _,group in ipairs(sorted_bag_groups) do
		announce(0, "-"..group..": "..string.join(", ", unpack(groups[group])), 1, 1, 1)
	end
	wipe(sorted_bag_groups)
end

local options = {
	name = OPTIONS, desc = L['OPTIONS_CONFIG_DESCRIPTION'], type = "group", order = 10,
	get = function(info) return core.db[info[#info]] end,
	set = function(info, value) core.db[info[#info]] = value end,
	args = {
		bank = {
			name = BANK,
			type = "group",
			inline = true,
			hidden = not core.has_account_bank,
			order = 15,
			args = {
				bank_target = {
					name = L['OPTIONS_BANK_TARGET'],
					desc = L['OPTIONS_BANK_TARGET_DESCRIPTION'],
					type = "select",
					descStyle = "inline",
					values = {
						warband = ACCOUNT_BANK_PANEL_TITLE,
						character = BANK,
						both = L['OPTIONS_BANK_TARGET_BOTH'],
					},
					order = 10,
				},
			},
		},
		sorting = {
			name = L['OPTIONS_SORTING'],
			type = "group",
			inline = true,
			order = 10,
			args = {
				junk = {
					name = BAG_FILTER_JUNK, desc = L['OPTIONS_JUNK_DESCRIPTION'], type = "select",
					descStyle = "inline",
					values = {
						[0] = NO,
						[1] = L['OPTIONS_JUNK_END'],
						[2] = L['OPTIONS_JUNK_BACK'],
					},
					order = 10,
				},
				conjured = {
					name = ITEM_CONJURED, desc = L['OPTIONS_CONJURED_DESCRIPTION'], type = "toggle",
					descStyle = "inline",
					order = 20,
				},
				soulbound = {
					name = ITEM_SOULBOUND, desc = L['OPTIONS_SOULBOUND_DESCRIPTION'], type = "toggle",
					descStyle = "inline",
					order = 30,
				},
				reverse = {
					name = L['OPTIONS_REVERSE'], desc = L['OPTIONS_REVERSE_DESCRIPTION'], type = "toggle",
					descStyle = "inline",
					order = 40,
				},
				backfill = {
					name = L['OPTIONS_BACKFILL'], desc = L['OPTIONS_BACKFILL_DESCRIPTION'], type = "toggle",
					descStyle = "inline",
					order = 50,
				},
			},
		},
		blizzard = {
			name = "Blizzard",
			type = "group",
			inline = true,
			order = 20,
			args = {
				respect = {
					name = L['OPTIONS_RESPECT_BLIZZARD'],
					desc = L['OPTIONS_RESPECT_BLIZZARD_DESCRIPTION'],
					descStyle = "inline", width="full",
					type = "toggle",
					get = function() return core.db.ignore_blizzard end,
					set = function(info, value) core.db.ignore_blizzard = value end,
					order = 10,
				},
			},
			plugins = {},
		},
	},
	plugins = {},
}
core.options = options

local bag_slot_pattern = "^(-?[%d]+)%s*(%d*)$"

local ignore_options = {
	name = IGNORE, desc = L['OPTIONS_IGNORE_DESCRIPTION'], type = "group", order = 20,
	args = {
		list = {
			name = L['OPTIONS_LIST'], desc = L['OPTIONS_IGNORE_LIST_DESCRIPTION'], type = "execute", order = 1,
			func = function()
				for ignored,_ in pairs(core.db.ignore_bags) do
					core.announce(0, L['CHAT_MSG_IGNORING_BAG']:format(ignored), 1, 1, 1)
				end
				for ignored,_ in pairs(core.db.ignore) do
					local bag, slot = core.decode_bagslot(ignored)
					core.announce(0, L['CHAT_MSG_IGNORING_SLOT']:format(bag, slot), 1, 1, 1)
				end
			end,
		},
		add = {
			name = ADD, desc = L['OPTIONS_IGNORE_ADD_DESCRIPTION'], type = "input", order = 2,
			get = false,
			set = function(info, v)
				local bag, slot = v:match(bag_slot_pattern)
				bag = tonumber(bag)
				slot = tonumber(slot)
				if bag and slot then
					local bagslot = core.encode_bagslot(bag, slot)
					core.db.ignore[bagslot] = true
					core.announce(0, L['CHAT_MSG_SLOT_IGNORED']:format(bag, slot), 1, 1, 1)
				elseif bag then
					core.db.ignore_bags[bag] = true
					core.announce(0, L['CHAT_MSG_BAG_IGNORED']:format(bag), 1, 1, 1)
				end
			end,
			usage = L['USAGE_BAG_SLOT'],
			validate = function(info, v)
				-- "and true or false" because returning a string counts as false
				return v:match(bag_slot_pattern) and true or false
			end,
		},
		remove = {
			name = REMOVE, desc = L['OPTIONS_IGNORE_REMOVE_DESCRIPTION'], type = "input", order = 3,
			get = false,
			set = function(info, v)
				local bag, slot = v:match(bag_slot_pattern)
				bag = tonumber(bag)
				slot = tonumber(slot)
				if bag and slot then
					local bagslot = core.encode_bagslot(bag, slot)
					core.db.ignore[bagslot] = nil
					announce(0, L['CHAT_MSG_SLOT_UNIGNORED']:format(bag, slot), 1, 1, 1)
				elseif bag then
					core.db.ignore_bags[bag] = nil
					announce(0, L['CHAT_MSG_BAG_UNIGNORED']:format(bag), 1, 1, 1)
				end
			end,
			usage = L['USAGE_BAG_SLOT'],
			validate = function(info, v)
				-- "and true or false" because returning a string counts as false
				return v:match(bag_slot_pattern) and true or false
			end,
		},
	},
}
local group_options = {
	name = GROUPS, desc = L['OPTIONS_GROUPS_DESCRIPTION'], type = "group", order = 30,
	args = {
		list = {
			name = L['OPTIONS_LIST'], desc = L['OPTIONS_GROUPS_LIST_DESCRIPTION'], type = "execute", order = 1,
			func = function()
				announce(0, L['CHAT_MSG_BUILT_IN_GROUPS'], 1, 1, 1)
				print_groups(core.groups)
				announce(0, L['CHAT_MSG_CUSTOM_GROUPS'], 1, 1, 1)
				print_groups(core.db.groups)
			end,
		},
		add = {
			name = ADD, desc = L['OPTIONS_GROUPS_ADD_DESCRIPTION'], type = "input", order = 2,
			get = false,
			set = function(info, v)
				local group, action = string.match(v, "^([^%s]+) (.*)$")
				if not core.db.groups[group] then
					core.db.groups[group] = {}
				end
				local bags = wipe(core.db.groups[group])
				-- Populate with the new group:
				for maybe_bagid in string.gmatch(action, "[^%s,]+") do
					local bag = tonumber(maybe_bagid)
					if core.is_valid_bag(bag) or core.is_guild_bank_bag(bag) then
						table.insert(bags, bag)
					else
						announce(0, L['CHAT_MSG_INVALID_BAG_ID']:format(maybe_bagid), 1, 0, 0)
					end
				end
				announce(0, L['CHAT_MSG_GROUP_ADDED']:format(group, string.join(", ", unpack(bags))), 1, 1, 1)
			end,
			usage = L['USAGE_GROUP_ADD'],
			validate = function(_, v) return string.match(v, "^[^%s]+ [-%d%s,]+$") and true or false end,
		},
		remove = {
			name = REMOVE, desc = L['OPTIONS_GROUPS_REMOVE_DESCRIPTION'], type = "input", order = 3,
			get = false,
			set = function(info, v)
				core.db.groups[v] = nil
				announce(0, L['CHAT_MSG_GROUP_REMOVED']:format(v), 1, 1, 1)
			end,
			usage = L['USAGE_GROUP_REMOVE'],
		}
	},
}

local help_options = {
	name = L['HELP_TITLE'], type="group",
	args = {
		header = { name = L['HELP_HEADER'], type = "header", order = 10, },
		commands = {
			type = "description", order = 20,
			name = L['HELP_COMMANDS'],
		},
	},
}

local keybindings = {
	['BUTTON1'] = GetBindingText("BUTTON1", "KEY_"),
	['ALT-BUTTON1'] = GetBindingText("ALT-BUTTON1", "KEY_"),
	['CTRL-BUTTON1'] = GetBindingText("CTRL-BUTTON1", "KEY_"),
	['ALT-CTRL-BUTTON1'] = GetBindingText("ALT-CTRL-BUTTON1", "KEY_"),
	['SHIFT-BUTTON1'] = GetBindingText("SHIFT-BUTTON1", "KEY_"),
	['ALT-SHIFT-BUTTON1'] = GetBindingText("ALT-SHIFT-BUTTON1", "KEY_"),
	['CTRL-SHIFT-BUTTON1'] = GetBindingText("CTRL-SHIFT-BUTTON1", "KEY_"),
	['ALT-CTRL-SHIFT-BUTTON1'] = GetBindingText("ALT-CTRL-SHIFT-BUTTON1", "KEY_"),
}

local launcher_options = {
	name = L['OPTIONS_CLICK_ASSIGNMENTS'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'],
	type = "group",
	get = function(info)
		local k = info[#info]
		for b, a in pairs(core.db.fubar_keybinds) do
			if a == k then
				return b
			end
		end
	end,
	set = function(info, v)
		-- clear current binding
		local k = info[#info]
		for b, a in pairs(core.db.fubar_keybinds) do
			if a == k then
				core.db.fubar_keybinds[b] = false
			end
		end
		-- set new binding
		if keybindings[v] then
			core.db.fubar_keybinds[v] = k
		end
	end,
	args = {
		help = {
			type = "description", order = 1,
			name = L['HELP_LAUNCHER'],
		},

		sortbags = {name = L['ACTION_SORTBAGS'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'], type = "select", values = keybindings, order = 10,},
		sortbank = {name = L['ACTION_SORTBANK'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'], type = "select", values = keybindings, order = 20,},
		stackbank = {name = L['ACTION_STACKBANK'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'], type = "select", values = keybindings, order = 30,},
		stackbags = {name = L['ACTION_STACKBAGS'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'], type = "select", values = keybindings, order = 40,},
		compressbags = {name = L['ACTION_COMPRESSBAGS'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'], type = "select", values = keybindings, order = 50,},
		compressbank = {name = L['ACTION_COMPRESSBANK'], desc = L['OPTIONS_CLICK_ASSIGNMENTS_DESCRIPTION'], type = "select", values = keybindings, order = 60,},
	},
}

local advanced_options = {
	name = ADVANCED_OPTIONS, desc = L['OPTIONS_ADVANCED_DESCRIPTION'], type = "group", order = 100,
	get = function(info) return core.db[info[#info]] end,
	set = function(info, value) core.db[info[#info]] = value end,
	args = {
		verbosity = {
			name = L['OPTIONS_VERBOSITY'], desc = L['OPTIONS_VERBOSITY_DESCRIPTION'], type = "range", min = 0, max = 2, step = 1,
			descStyle = "inline",
		},
		conservative_guild = {
			name = L['OPTIONS_CAUTIOUS_GUILD'],
			desc = L['OPTIONS_CAUTIOUS_GUILD_DESCRIPTION'],
			descStyle = "inline",
			type = "toggle",
		},
		timing = {
			name = L['OPTIONS_TIMING'], inline = true, type = "group",
			args = {
				desc = {
					type = "description", order = 0,
					name = L['OPTIONS_TIMING_DESCRIPTION'],
				},
				stutter_duration = {
					name = L['OPTIONS_STUTTER_INTERVAL'], type = "range",
					desc = L['OPTIONS_STUTTER_INTERVAL_DESCRIPTION'],
					min = 0, max = 1, step = 0.05,
					order = 10,
				},
				stutter_delay = {
					name = L['OPTIONS_STUTTER_DELAY'], type = "range",
					desc = L['OPTIONS_STUTTER_DELAY_DESCRIPTION'],
					min = 0, max = 1, step = 0.05,
					order = 20,
				},
				processing_delay = {
					name = L['OPTIONS_PROCESSING_DELAY'], type = "range",
					desc = L['OPTIONS_PROCESSING_DELAY_DESCRIPTION'],
					min = 0, max = 1, step = 0.05,
					order = 30,
				},
				processing_delay_guild = {
					name = L['OPTIONS_PROCESSING_DELAY_GUILD'], type = "range",
					desc = L['OPTIONS_PROCESSING_DELAY_GUILD_DESCRIPTION'],
					min = 0, max = 1, step = 0.05,
					order = 40,
				},
			},
		}
	},
}

local categoryID
core.setup_config = function()
	local acreg = LibStub("AceConfigRegistry-3.0")
	acreg:RegisterOptionsTable(myname, options)
	acreg:RegisterOptionsTable(myname .. "Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(core.db_object))
	acreg:RegisterOptionsTable(myname .. "Help", help_options)
	acreg:RegisterOptionsTable(myname .. "Launcher", launcher_options)
	acreg:RegisterOptionsTable(myname .. "Advanced", advanced_options)
	acreg:RegisterOptionsTable(myname .. "Groups", group_options)
	acreg:RegisterOptionsTable(myname .. "Ignore", ignore_options)

	local acdia = LibStub("AceConfigDialog-3.0")
	categoryID = select(2, acdia:AddToBlizOptions(myname, myname))
	acdia:AddToBlizOptions(myname .. "Ignore", IGNORE, myname)
	acdia:AddToBlizOptions(myname .. "Groups", GROUPS, myname)
	acdia:AddToBlizOptions(myname .. "Launcher", L['OPTIONS_LAUNCHER'], myname)
	acdia:AddToBlizOptions(myname .. "Advanced", ADVANCED_OPTIONS, myname)
	acdia:AddToBlizOptions(myname .. "Profiles", L['OPTIONS_PROFILES'], myname)
	acdia:AddToBlizOptions(myname .. "Help", HELP_LABEL, myname)
end

core.open_config = function()
	if not categoryID then return end
	Settings.OpenToCategory(categoryID)
	--LibStub("AceConfigDialog-3.0"):Open(myname)
end

SLASH_BANKSTACKCONFIG1 = "/bankstack"
SlashCmdList["BANKSTACKCONFIG"] = function(arg)
	core.open_config()
end
