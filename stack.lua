local core = BankStack
local L = core.L
local Debug = core.Debug

local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot
local encode_move = core.encode_move
local moves = core.moves

local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks

do
	-- This is a stack filterer.  It's used to stop full stacks being shuffled around
	-- while compressing bags.
	local function is_partial(itemid, bag, slot)
		-- (stacksize - count) > 0
		local bagslot = encode_bagslot(bag, slot)
		return ((bag_maxstacks[bagslot] or 0) - (bag_stacks[bagslot] or 0)) > 0
	end
	core.is_partial = is_partial
	local bag_groups = {}
	function core.Compress(...)
		for i=1, select("#", ...) do
			local bags = select(i, ...)
			core.Stack(bags, bags, is_partial)
		end
	end
end

-- Stacking:

local target_items = {--[[link = available_slots--]]}
local source_used = {}
local target_slots = {}
local stored_items = {}
local stored_quality_items = {}
local empty_slots = {}

local function crafting_quality_key(itemid)
	if not itemid or not C_TradeSkillUI then return end
	local reagent_quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo
	local crafted_quality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo
	local quality = (reagent_quality and reagent_quality(itemid)) or (crafted_quality and crafted_quality(itemid))
	if not quality or quality < 1 then return end
	-- Quality ranks have different item IDs but share their name and category.
	local name, _, _, _, _, _, _, _, _, _, _, class, subclass, _, expansion = C_Item.GetItemInfo(itemid)
	if name then
		return string.format("%s:%d:%d:%d", name, class, subclass, expansion)
	end
end

local function default_can_move() return true end
-- Returns a table of itemid -> count moved.
function core.Stack(source_bags, target_bags, can_move)
	-- Fill incomplete stacks, optionally creating new stacks for stored items.
	-- source_bags: table, e.g. {1,2,3,4}
	-- target_bags: table, e.g. {1,2,3,4}
	-- can_move: function or nil.  Called as can_move(itemid, bag, slot)
	--   for any slot in source that is not empty and contains an item that
	--   could be moved to target.  If it returns false then ignore the slot.
	if not can_move then can_move = default_can_move end
	local summary_table = {}
	local target_is_bank, target_is_bags = true, true
	for _, bag in ipairs(target_bags) do
		target_is_bank = target_is_bank and core.is_bank_bag(bag)
		target_is_bags = target_is_bags and tContains(core.player_bags, bag)
	end
	local fill_existing = core.db.stack_bank_existing and source_bags ~= target_bags and (target_is_bank or target_is_bags)
	local match_quality = fill_existing and core.db.stack_bank_quality
	-- Model the target bags.
	for _, bag, slot in core.IterateBags(target_bags, nil, "deposit") do
		local bagslot = encode_bagslot(bag, slot)
		local itemid = bag_ids[bagslot]
		if not core.IsIgnored(bag, slot) then
			if itemid and (bag_stacks[bagslot] ~= bag_maxstacks[bagslot]) then
				-- This is an item type that we'll want to bother moving.
				target_items[itemid] = (target_items[itemid] or 0) + 1
				table.insert(target_slots, bagslot)
			end
			if fill_existing then
				if itemid then
					stored_items[itemid] = true
					local quality_key = match_quality and crafting_quality_key(itemid)
					if quality_key then stored_quality_items[quality_key] = true end
				else
					table.insert(empty_slots, bagslot)
				end
			end
		end
	end
	-- Now go through the source bags... in reverse.
	for _, bag, slot in core.IterateBags(source_bags, true, "withdraw") do
		local source_slot = encode_bagslot(bag, slot)
		local itemid = bag_ids[source_slot]
		local quality_key = match_quality and crafting_quality_key(itemid)
		local can_fill = (stored_items[itemid] or stored_quality_items[quality_key])
			and ((target_is_bank and tContains(core.player_bags, bag)) or (target_is_bags and core.is_bank_bag(bag)))
		if not core.IsIgnored(bag, slot) and itemid and (target_items[itemid] or can_fill) and can_move(itemid, bag, slot) then
			for i=#target_slots, 1, -1 do
				local target_slot = target_slots[i]
				if
					bag_ids[source_slot] -- slot hasn't been emptied
					and bag_ids[target_slot] == itemid -- target is same as source
					and target_slot ~= source_slot -- target *isn't* source
					and bag_stacks[target_slot] ~= bag_maxstacks[target_slot] -- target isn't full
					and not source_used[target_slot] -- already moved from slot
				then
					-- can't stack to itself, or to a full slot, or to a slot that has already been used as a source:

					-- record a summary of the move (has to happen before AddMove, since that updates bag_stacks)
					-- only as much as the target has room for actually moves
					local room = bag_maxstacks[target_slot] - bag_stacks[target_slot]
					summary_table[itemid] = (summary_table[itemid] or 0) + math.min(bag_stacks[source_slot], room)

					-- Schedule moving from this slot to the bank slot.
					core.AddMove(source_slot, target_slot)
					source_used[source_slot] = true

					if bag_stacks[target_slot] == bag_maxstacks[target_slot] then
						target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
					end
					if not bag_ids[source_slot] then
						-- This bag slot is emptied, move on.
						break
					end
					if not target_items[itemid] then break end
				end
			end
			if can_fill and bag_ids[source_slot] then
				for i=1, #empty_slots do
					local index = core.db.backfill and (#empty_slots - i + 1) or i
					local target_slot = empty_slots[index]
					local target_bag = decode_bagslot(target_slot)
					if core.CanItemGoInBag(bag, slot, target_bag) then
						summary_table[itemid] = (summary_table[itemid] or 0) + bag_stacks[source_slot]
						core.AddMove(source_slot, target_slot)
						source_used[source_slot] = true
						table.remove(empty_slots, index)
						if bag_stacks[target_slot] < bag_maxstacks[target_slot] then
							target_items[itemid] = (target_items[itemid] or 0) + 1
							table.insert(target_slots, target_slot)
						end
						break
					end
				end
			end
		end
	end
	-- clean up the various cache tables
	wipe(target_items)
	wipe(target_slots)
	wipe(source_used)
	wipe(stored_items)
	wipe(stored_quality_items)
	wipe(empty_slots)
	return summary_table
end

-- The banks that "bank" stands for in a stack, per the bank_target option.
local function expand_bank(bags)
	if bags ~= core.bank_bags then
		return { { bags = bags } }
	end
	local bank_target = core.db.bank_target
	local has_account = #core.account_bags > 0
	local banks = {}
	if has_account and bank_target ~= "character" then
		table.insert(banks, { label = ACCOUNT_BANK_PANEL_TITLE, bags = core.account_bags })
	end
	if bank_target ~= "warband" or not has_account then
		table.insert(banks, { label = BANK, bags = bags })
	end
	return banks
end

local function build_summary_text(summary_table)
	local summary_text = {}
	for itemid, count in pairs(summary_table) do
		table.insert(summary_text, select(2, C_Item.GetItemInfo(itemid)) .. 'x' .. count)
	end
	if #summary_text > 0 then
		return string.join(", ", unpack(summary_text))
	end
end

function core.StackSummary(source_bags, target_bags, can_move)
	local passes = {}
	if source_bags == target_bags then
		passes[1] = { source = source_bags, target = target_bags }
	else
		for _, source in ipairs(expand_bank(source_bags)) do
			for _, target in ipairs(expand_bank(target_bags)) do
				table.insert(passes, { source = source.bags, target = target.bags, label = source.label or target.label })
			end
		end
	end
	for _, pass in ipairs(passes) do
		local summary_text = build_summary_text(core.Stack(pass.source, pass.target, can_move))
		if summary_text then
			if #passes > 1 then
				core.announce(1, L['stacking_bank']:format(pass.label, summary_text))
			else
				core.announce(1, L['stacking']:format(summary_text))
			end
		end
	end
end

SlashCmdList["BANKSTACK"] = core.CommandDecorator(core.StackSummary, "bags bank", 2, true)
SLASH_BANKSTACK1 = "/stack"
SlashCmdList["COMPRESSBAGS"] = core.CommandDecorator(core.Compress, "bags")
SLASH_COMPRESSBAGS1 = "/compress"
SLASH_COMPRESSBAGS2 = "/compressbags"
