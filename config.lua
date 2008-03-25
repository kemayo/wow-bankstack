local core = BankStack
local L = core.L

local announce = core.announce
local clear = core.clear

local simple_aceoptions
local pass_group
local passthrough_keys = {get = true, set = true, func = true,}
local meta_cache = {}
local ao_meta = {__index = function(k)
	if passthrough_keys[k] and pass_group and pass_group[k] then
		if not meta_cache[pass_group[k]] then
			meta_cache[pass_group[k]] = function(...) pass_group[k](k, ...) end
		end
		return meta_cache[pass_group[k]]
	end
end,}
local aceoptions_formats = {
	DEFAULT = function(k, t) return ' - ' .. t.desc end,
	toggle = function(k, t) return ' - ' .. t.desc .. ' (' .. (t.get() and 'true' or 'false') .. ')' end,
	range = function(k, t) return ' - ' .. t.desc .. ' (' .. t.get() .. ') [' .. t.min .. '-' .. t.max .. ']' end,
	header = function(k, t) return '' end,
}
local function format_aceoptions_description(k, t)
	assert(type(k) == 'string')
	assert(type(t) == 'table')
	return ' ' .. k .. (aceoptions_formats[t.type] and aceoptions_formats[t.type](k, t) or aceoptions_formats.DEFAULT(k, t))
end
local sort_by_order
do
	local key_table
	local ordersort = function(a, b)
		return (key_table[a].order or 100) < (key_table[b].order or 100)
	end
	sort_by_order = function(to_sort, into)
		key_table = to_sort
		for k in pairs(to_sort) do table.insert(into, k) end
		table.sort(into, ordersort)
		return into
	end
end
local sorted_group = {}
local aceoptions_handlers = {
	group = function(k, t, cmd)
		if t.pass then
			pass_group = t
			for k,v in pairs(t.args) do
				setmetatable(v, ao_meta)
			end
		end
		if cmd then
			local cmd, args = string.match(cmd, "^(%a+) ?(.*)")
			if t.args[cmd] then
				return simple_aceoptions(cmd, t.args[cmd], args)
			end
		end
		announce(0, t.name .. ' - ' .. t.desc, 1, 1, 1)
		for _,k in ipairs(sort_by_order(t.args, sorted_group)) do
			announce(0, format_aceoptions_description(k, t.args[k]), 1, 1, 1)
		end
		clear(sorted_group)
		pass_group = nil
	end,
	toggle = function(k, t, cmd)
		t.set(not t.get())
		announce(0, string.format(L.opt_set, t.name, (t.get() and 'true' or 'false')), 1, 1, 1)
	end,
	range = function(k, t, cmd)
		local value = tonumber(cmd)
		if value and value >= t.min and value <= t.max then
			t.set(value)
			announce(0, string.format(L.opt_set, t.name, t.get()), 1, 1, 1)
		else
			announce(0, 'Value was out of bounds', 1, 0, 0)
		end
	end,
	text = function(k, t, cmd)
		if (not t.validate) or t.validate(cmd) then
			t.set(cmd)
			if t.get then announce(0, string.format(L.opt_set, t.name, t.get()), 1, 1, 1) end
		end
	end,
	execute = function(k, t, cmd)
		t.func()
	end,
}
function simple_aceoptions(k, t, cmd)
	-- Aceoptions support but only for what is used below.
	assert(type(t) == 'table')
	assert(t.type)
	assert(aceoptions_handlers[t.type])
	aceoptions_handlers[t.type](k, t, cmd)
end

local sorted_bag_groups = {}
local function print_groups(groups)
	for group in pairs(groups) do
		table.insert(sorted_bag_groups, group)
	end
	table.sort(sorted_bag_groups)
	for _,group in ipairs(sorted_bag_groups) do
		announce(0, "-"..group..": "..string.join(", ", unpack(groups[group])), 1, 1, 1)
	end
	clear(sorted_bag_groups)
end

core.aceoptions = {
	name = "BankStack", desc = "Stacks things", type = "group",
	args = {
		config = {
			name = "config", desc = "basic settings", type = "group", order = 1,
			args = {
				verbosity = {
					name = "verbosity", desc = "talkativitinessism", type = "range", min = 0, max = 2, step = 1,
					get = function() return core.db.verbosity end,
					set = function(v) core.db.verbosity = tonumber(v) end,
				},
				junk = {
					name = "junk", desc = "move junk to the end", type = "toggle",
					get = function() return core.db.junk end,
					set = function(v) core.db.junk = v end,
				},
				soul = {
					name = "soul", desc = "move soul shards to the end", type = "toggle",
					get = function() return core.db.soul end,
					set = function(v) core.db.soul = v end,
				},
				conjured = {
					name = "conjured", desc = "move conjured items to the end", type = "toggle",
					get = function() return core.db.conjured end,
					set = function(v) core.db.conjured = v end,
				},
				reverse = {
					name = "reverse", desc = "reverse the sort", type = "toggle",
					get = function() return core.db.reverse end,
					set = function(v) core.db.reverse = v end,
				},
			},
		},
		ignore = {
			name = "ignore", desc = "ignore slots", type = "group", order = 2,
			args = {
				list = {
					name = "list", desc = "list all ignored slots", type = "execute", order = 1,
					func = function()
						for ignored,_ in pairs(core.db.ignore) do
							local bag, slot = core.decode_bagslot(ignored)
							core.announce(0, "Ignoring: "..bag.." "..slot, 1, 1, 1)
						end
					end,
				},
				add = {
					name = "add", desc = "add an ignore", type = "text", order = 2,
					get = false,
					set = function(v)
						local bag, slot = string.match(v, "^([-%d]+) (%d+)$")
						if bag and slot then
							local bagslot = core.encode_bagslot(tonumber(bag), tonumber(slot))
							core.db.ignore[bagslot] = true
							core.announce(0, bag.." "..slot.." ignored.", 1, 1, 1)
						end
					end,
					usage = "[bag] [slot] (see http://wowwiki.com/BagID)",
					validate = function(v) return string.match(v, "^%d+ %d+$") end,
				},
				remove = {
					name = "remove", desc = "remove an ignore", type = "text", order = 3,
					get = false,
					set = function(v)
						local bag, slot = string.match(v, "^([-%d]+) (%d+)$")
						if bag and slot then
							local bagslot = core.encode_bagslot(tonumber(bag), tonumber(slot))
							core.db.ignore[bagslot] = nil
							announce(0, bag.." "..slot.." no longer ignored.", 1, 1, 1)
						end
					end,
					usage = "[bag] [slot] (see http://wowwiki.com/BagID)",
				},
			},
		},
		group = {
			name = "group", desc = "bag groups", type = "group", order = 3,
			args = {
				list = {
					name = "list", desc = "list all groups", type = "execute", order = 1,
					func = function()
						announce(0, "Built in groups:", 1, 1, 1)
						print_groups(core.groups)
						announce(0, "Custom groups:", 1, 1, 1)
						print_groups(core.db.groups)
					end,
				},
				add = {
					name = "add", desc = "add a group (see http://wowwiki.com/BagID)", type = "text", order = 2,
					get = false,
					set = function(v)
						local group, action = string.match(v, "^(%a+) (.*)$")
						if not core.db.groups[group] then
							core.db.groups[group] = {}
						end
						local bags = clear(core.db.groups[group])
						-- Populate with the new group:
						for v in string.gmatch(action, "[^%s,]+") do
							local bag = tonumber(v)
							if core.is_valid_bag(bag) or core.is_guild_bank_bag(bag) then
								table.insert(bags, bag)
							else
								announce(0, v.." was not a valid bag id.", 1, 0, 0)
							end
						end
						announce(0, "Added group: "..group.." ("..string.join(", ", unpack(bags))..")", 1, 1, 1)
					end,
					usage = "[name] [bagid],[bagid],[bagid]",
					validate = function(v) return string.match(v, "^%a+ [%d%s,]+$") end,
				},
				remove = {
					name = "remove", desc = "remove a group", type = "text", order = 3,
					get = false,
					set = function(v)
						core.db.groups[v] = nil
						announce(0, group .. " removed.", 1, 1, 1)
					end,
					usage = "[name]",
				}
			},
		},
		help = {
			name = "help", desc = "slashcommand reference", type = "execute", order = 101,
			func = function()
				announce(0, "BankStack: Stacks things.", 1, 1, 1)
				announce(0, "/bankstack -- this menu.", 1, 1, 1)
				announce(0, "/sort -- rearrange your bags", 1, 1, 1)
				announce(0, "/sort bank -- rearrange your bank", 1, 1, 1)
				announce(0, "/stack -- fills stacks in your bank from your bags", 1, 1, 1)
				announce(0, "/stack bank bags -- fills stacks in your bags from your bank", 1, 1, 1)
				announce(0, "/compress -- merges stacks in your bags", 1, 1, 1)
				announce(0, "/compress bank -- merges stacks in your bank", 1, 1, 1)
				announce(0, "/fill -- fills empty slots in your bank from your bags", 1, 1, 1)
			end,
		},
	},
}

SLASH_BANKSTACKCONFIG1 = "/bankstack"
SlashCmdList["BANKSTACKCONFIG"] = function(arg)
	simple_aceoptions(nil, core.aceoptions, arg)
end

