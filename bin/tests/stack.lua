-- Run from the repository root: lua bin\tests\stack.lua
function wipe(t)
	for key in pairs(t) do t[key] = nil end
end

function tContains(t, value)
	for _, entry in ipairs(t) do
		if entry == value then return true end
	end
	return false
end

string.join = function(separator, ...) return table.concat({...}, separator) end
SlashCmdList = {}
BANK = "Bank"
ACCOUNT_BANK_PANEL_TITLE = "Warband"
C_Item = { GetItemInfo = function(itemid) return nil, tostring(itemid) end }

local function fixture()
	local core = {
		L = { stacking = "%s", stacking_bank = "%s: %s" },
		db = { bank_target = "character", stack_bank_existing = true },
		player_bags = {0},
		bank_bags = {1, 2},
		account_bags = {3},
		bag_ids = {}, bag_stacks = {}, bag_maxstacks = {},
		moves = {}, ignored = {}, blocked = {}, messages = {},
		item_info = {}, reagent_quality = {}, crafted_quality = {},
	}
	BankStack = core
	C_Item.GetItemInfo = function(itemid)
		local info = core.item_info[itemid] or {tostring(itemid), 7, 9, 10}
		return info[1], tostring(itemid), 1, 1, 1, "", "", 10, "", 1, 0, info[2], info[3], 0, info[4]
	end
	C_TradeSkillUI = {
		GetItemReagentQualityByItemInfo = function(itemid) return core.reagent_quality[itemid] end,
		GetItemCraftedQualityByItemInfo = function(itemid) return core.crafted_quality[itemid] end,
	}
	function core.encode_bagslot(bag, slot) return bag * 1000 + slot end
	function core.decode_bagslot(value) return math.floor(value / 1000), value % 1000 end
	function core.is_bank_bag(bag) return bag >= 1 and bag <= 3 end
	function core.IsIgnored(bag, slot) return core.ignored[core.encode_bagslot(bag, slot)] end
	function core.CanItemGoInBag(_, _, bag) return not core.blocked[bag] end
	function core.CommandDecorator(fn) return fn end
	function core.announce(_, text) table.insert(core.messages, text) end
	function core.IterateBags(bags, reverse)
		return coroutine.wrap(function()
			for i=1, #bags do
				local bag = bags[reverse and (#bags - i + 1) or i]
				for j=1, 4 do
					coroutine.yield(j, bag, reverse and (5 - j) or j)
				end
			end
		end)
	end
	function core.put(bag, slot, itemid, count)
		local key = core.encode_bagslot(bag, slot)
		core.bag_ids[key], core.bag_stacks[key], core.bag_maxstacks[key] = itemid, count, 10
	end
	function core.count(bag, slot)
		return core.bag_stacks[core.encode_bagslot(bag, slot)]
	end
	function core.AddMove(source, target)
		local ids, counts, max = core.bag_ids, core.bag_stacks, core.bag_maxstacks
		assert(ids[source], "Cannot move an empty source")
		assert(not ids[target] or ids[target] == ids[source], "Cannot replace another item")
		local moved = math.min(counts[source], (max[target] or max[source]) - (counts[target] or 0))
		assert(moved > 0, "Cannot move to a full stack")
		ids[target], max[target] = ids[source], max[source]
		counts[target] = (counts[target] or 0) + moved
		counts[source] = counts[source] - moved
		if counts[source] == 0 then
			ids[source], counts[source], max[source] = nil, nil, nil
		end
		table.insert(core.moves, {source, target})
	end
	dofile("stack.lua")
	return core
end

local tests = {
	disabled_preserves_full_stack_behavior = function()
		local c = fixture()
		c.db.stack_bank_existing = false
		c.put(1, 1, 101, 10)
		c.put(0, 1, 101, 5)
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
		c.bag_stacks[c.encode_bagslot(1, 1)] = 7
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(1, 1) == 10 and c.count(0, 1) == 2)
	end,
	full_stack_creates_new_stack_and_reports_count = function()
		local c = fixture()
		c.put(1, 1, 101, 10)
		c.put(0, 1, 101, 5)
		c.put(0, 2, 202, 4)
		c.StackSummary(c.player_bags, c.bank_bags)
		assert(c.count(1, 1) == 10 and c.count(1, 2) == 5)
		assert(not c.count(0, 1) and c.count(0, 2) == 4)
		assert(c.messages[1] == "101x5")
	end,
	partial_stacks_are_filled_before_new_stacks = function()
		local c = fixture()
		c.put(1, 1, 101, 7)
		c.put(0, 1, 101, 5)
		c.StackSummary(c.player_bags, c.bank_bags)
		assert(c.count(1, 1) == 10 and c.count(1, 2) == 2)
		assert(not c.count(0, 1) and c.messages[1] == "101x5")
	end,
	new_partial_stack_is_reused = function()
		local c = fixture()
		c.put(1, 1, 101, 10)
		c.put(0, 1, 101, 7)
		c.put(0, 2, 101, 8)
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(1, 2) == 10 and c.count(1, 3) == 5)
		assert(not c.count(0, 1) and not c.count(0, 2))
	end,
	full_bank_keeps_overflow_in_bags = function()
		local c = fixture()
		for _, bag in ipairs(c.bank_bags) do
			for slot=1, 4 do c.put(bag, slot, 101, 10) end
		end
		c.put(0, 1, 101, 5)
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
	end,
	ignored_slots_and_bag_restrictions_are_respected = function()
		local c = fixture()
		c.put(1, 1, 101, 10)
		c.put(0, 1, 101, 5)
		c.put(0, 2, 101, 5)
		c.ignored[c.encode_bagslot(0, 2)] = true
		c.ignored[c.encode_bagslot(2, 1)] = true
		c.blocked[1] = true
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 2) == 5 and not c.count(0, 1))
		assert(not c.count(1, 2) and not c.count(2, 1) and c.count(2, 2) == 5)
	end,
	ignored_items_do_not_establish_bank_presence = function()
		local c = fixture()
		c.put(1, 1, 101, 10)
		c.put(0, 1, 101, 5)
		c.ignored[c.encode_bagslot(1, 1)] = true
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
	end,
	source_filter_is_respected = function()
		local c = fixture()
		c.put(1, 1, 101, 10)
		c.put(0, 1, 101, 5)
		c.Stack(c.player_bags, c.bank_bags, function() return false end)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
	end,
	backfill_and_selected_bank_tab_are_respected = function()
		local c = fixture()
		c.db.backfill = true
		c.put(3, 1, 101, 10)
		c.put(0, 1, 101, 5)
		c.Stack(c.player_bags, {3})
		assert(c.count(3, 4) == 5 and not c.count(0, 1))
	end,
	bank_target_and_per_bank_presence_are_respected = function()
		local c = fixture()
		c.db.bank_target = "warband"
		c.put(1, 1, 101, 10)
		c.put(3, 1, 202, 10)
		c.put(0, 1, 101, 5)
		c.put(0, 2, 202, 5)
		c.StackSummary(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and not c.count(0, 2) and c.count(3, 2) == 5)
		c.db.bank_target = "both"
		wipe(c.messages)
		c.StackSummary(c.player_bags, c.bank_bags)
		assert(not c.count(0, 1) and c.count(1, 2) == 5)
		assert(c.messages[1] == "Bank: 101x5")
	end,
	compression_does_not_create_stacks = function()
		local c = fixture()
		c.put(0, 1, 101, 10)
		c.put(1, 1, 101, 5)
		c.Compress(c.bank_bags)
		assert(c.count(1, 1) == 5 and #c.moves == 0)
		c.Compress(c.player_bags)
		assert(c.count(0, 1) == 10 and #c.moves == 0)
	end,
	withdrawal_creates_stacks_for_existing_items_only = function()
		for _, bank in ipairs({1, 3}) do
			local c = fixture()
			c.put(0, 1, 101, 10)
			c.put(bank, 1, 101, 5)
			c.put(bank, 2, 202, 5)
			c.db.stack_bank_existing = false
			c.Stack({bank}, c.player_bags)
			assert(c.count(bank, 1) == 5 and #c.moves == 0)
			c.db.stack_bank_existing = true
			c.StackSummary({bank}, c.player_bags)
			assert(c.count(0, 1) == 10 and c.count(0, 2) == 5 and not c.count(bank, 1))
			assert(c.count(bank, 2) == 5 and c.messages[1] == "101x5")
		end
	end,
	withdrawal_fills_partial_stacks_then_respects_destination_limits = function()
		local c = fixture()
		c.put(0, 1, 101, 7)
		c.put(0, 3, 202, 10)
		c.put(0, 4, 202, 10)
		c.put(1, 1, 101, 5)
		c.ignored[c.encode_bagslot(0, 2)] = true
		c.Stack(c.bank_bags, c.player_bags)
		assert(c.count(0, 1) == 10 and c.count(1, 1) == 2 and not c.count(0, 2))
		c.ignored[c.encode_bagslot(0, 2)] = nil
		c.blocked[0] = true
		c.Stack(c.bank_bags, c.player_bags)
		assert(c.count(1, 1) == 2 and not c.count(0, 2))
		c.blocked[0] = nil
		c.Stack(c.bank_bags, c.player_bags)
		assert(not c.count(1, 1) and c.count(0, 2) == 2)
	end,
	withdrawal_quality_matching_is_opt_in_and_keeps_ranks_separate = function()
		for _, bank in ipairs({1, 3}) do
			local c = fixture()
			c.item_info[101], c.item_info[102] = {"Herb", 7, 9, 10}, {"Herb", 7, 9, 10}
			c.reagent_quality[101], c.reagent_quality[102] = 1, 2
			c.put(0, 1, 101, 7)
			c.put(bank, 1, 102, 5)
			c.Stack({bank}, c.player_bags)
			assert(c.count(bank, 1) == 5 and #c.moves == 0)
			c.db.stack_bank_quality = true
			c.Stack({bank}, c.player_bags)
			assert(c.count(0, 1) == 7 and c.count(0, 2) == 5 and not c.count(bank, 1))
			assert(c.bag_ids[c.encode_bagslot(0, 2)] == 102)
		end
	end,
	crafting_quality_matching_is_opt_in_and_keeps_ranks_separate = function()
		local c = fixture()
		c.item_info[101], c.item_info[102] = {"Herb", 7, 9, 10}, {"Herb", 7, 9, 10}
		c.reagent_quality[101], c.reagent_quality[102] = 1, 2
		c.put(1, 1, 101, 7)
		c.put(0, 1, 102, 5)
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
		c.db.stack_bank_quality = true
		c.StackSummary(c.player_bags, c.bank_bags)
		assert(c.count(1, 1) == 7 and c.count(1, 2) == 5 and not c.count(0, 1))
		assert(c.bag_ids[c.encode_bagslot(1, 2)] == 102 and c.messages[1] == "102x5")
	end,
	crafted_quality_matching_supports_warband_bank = function()
		local c = fixture()
		c.db.stack_bank_quality, c.db.bank_target = true, "warband"
		c.item_info[101], c.item_info[102] = {"Potion", 0, 1, 10}, {"Potion", 0, 1, 10}
		c.crafted_quality[101], c.crafted_quality[102] = 3, 2
		c.put(3, 1, 101, 10)
		c.put(0, 1, 102, 5)
		c.StackSummary(c.player_bags, c.bank_bags)
		assert(c.count(3, 1) == 10 and c.count(3, 2) == 5 and not c.count(0, 1))
	end,
	withdrawal_respects_upstream_bank_target_expansion = function()
		local c = fixture()
		c.db.bank_target = "warband"
		c.put(0, 1, 101, 10)
		c.put(1, 1, 101, 5)
		c.put(3, 1, 101, 5)
		c.StackSummary(c.bank_bags, c.player_bags)
		assert(c.count(0, 2) == 5 and c.count(1, 1) == 5 and not c.count(3, 1))
	end,
	quality_matching_excludes_unranked_and_unrelated_items = function()
		local c = fixture()
		c.db.stack_bank_quality = true
		c.item_info[101] = {"Herb", 7, 9, 10}
		c.reagent_quality[101] = 1
		c.put(1, 1, 101, 10)
		for itemid, info in pairs({
			[102] = {"Other herb", 7, 9, 10},
			[103] = {"Herb", 7, 9, 9},
			[104] = {"Herb", 7, 8, 10},
			[105] = {"Herb", 7, 9, 10},
		}) do
			c.item_info[itemid] = info
			if itemid ~= 105 then c.reagent_quality[itemid] = 2 end
			c.put(0, itemid - 101, itemid, 5)
		end
		c.Stack(c.player_bags, c.bank_bags)
		assert(#c.moves == 0)
	end,
	quality_matching_requires_parent_option_and_available_api = function()
		local c = fixture()
		c.db.stack_bank_quality, c.db.stack_bank_existing = true, false
		c.item_info[101], c.item_info[102] = {"Herb", 7, 9, 10}, {"Herb", 7, 9, 10}
		c.reagent_quality[101], c.reagent_quality[102] = 1, 2
		c.put(1, 1, 101, 10)
		c.put(0, 1, 102, 5)
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
		c.db.stack_bank_existing = true
		C_TradeSkillUI = nil
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(0, 1) == 5 and #c.moves == 0)
		c.put(0, 2, 101, 5)
		c.Stack(c.player_bags, c.bank_bags)
		assert(c.count(1, 2) == 5 and not c.count(0, 2))
	end,
}

local count = 0
for name, test in pairs(tests) do
	test()
	count = count + 1
	print("PASS " .. name)
end
print(count .. " tests passed")
