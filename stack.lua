local core = BankStack
local L = core.L
local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot

local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks
local bag_links = core.bag_links

do
	-- This is a stack filterer.  It's used to stop full stacks being shuffled around
	-- while compressing bags.
	local function is_partial(itemid, bag, slot)
		-- (stacksize - count) > 0
		local bagslot = encode_bagslot(bag, slot)
		return ((bag_maxstacks[bagslot] or 0) - (bag_stacks[bagslot] or 0)) > 0
	end
	core.is_partial = is_partial
	function core.Compress(...)
		for i=1, select("#", ...) do
			local bags = select(i, ...)
			core.Stack(bags, bags, is_partial)
		end
	end
end

-- Stacking:

local reagent_quality = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo
local crafted_quality = C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo
core.supports_stack_quality = reagent_quality ~= nil or crafted_quality ~= nil

local function crafting_rank(bagslot)
	if not core.supports_stack_quality then return end
	local link = bag_links[bagslot]
	local quality = reagent_quality and reagent_quality(link)
	if (not quality or quality < 1) and crafted_quality then
		quality = crafted_quality(link)
	end
	if quality and quality >= 1 then return quality end
end

local function stored_item_key(slot)
	local itemid = bag_ids[slot]
	if itemid == 82800 then -- Pet Cage shares an item ID across species.
		local species = bag_links[slot] and bag_links[slot]:match("|Hbattlepet:(%d+):")
		return species and ("battlepet:" .. species)
	end
	local rank = crafting_rank(slot)
	return rank and (itemid .. ":" .. rank) or itemid, rank
end

local function crafting_quality_key(itemid)
	-- Ranks may have different item IDs but share their name and category.
	local name, _, _, _, _, _, _, _, _, _, _, class, subclass, _, expansion = C_Item.GetItemInfo(itemid)
	if name and class and subclass and expansion then
		return string.format("%s:%d:%d:%d", name, class, subclass, expansion)
	end
end

local function default_can_move() return true end
local function destination_slots(bags, is_ignored)
	local slots, seen = {}, {}
	for _, bag, slot in core.IterateBags(bags, nil, "deposit") do
		local bagslot = encode_bagslot(bag, slot)
		if not seen[bagslot] and not is_ignored(bag, slot) then
			seen[bagslot] = true
			table.insert(slots, bagslot)
		end
	end
	return slots
end

local function add_partial(partials, key, slot)
	local slots = partials[key]
	if not slots then slots = {}; partials[key] = slots end
	table.insert(slots, slot)
end

local function queue_move(summary, source, destination, count)
	local itemid = bag_ids[source]
	summary[itemid] = (summary[itemid] or 0) + count
	core.AddMove(source, destination)
end

local function merge_partials(summary, source, targets, used_sources)
	if not targets then return end
	for i = #targets, 1, -1 do
		local target = targets[i]
		if target ~= source and not (used_sources and used_sources[target]) then
			local room = bag_maxstacks[target] - bag_stacks[target]
			queue_move(summary, source, target, math.min(bag_stacks[source], room))
			if used_sources then used_sources[source] = true end
			if bag_stacks[target] == bag_maxstacks[target] then table.remove(targets, i) end
			if not bag_ids[source] then break end
		end
	end
end

local function merge_existing(pass, can_move, is_ignored)
	local partials, used_sources = {}, {}
	for _, slot in ipairs(destination_slots(pass.target, is_ignored)) do
		local itemid = bag_ids[slot]
		if itemid and bag_stacks[slot] < bag_maxstacks[slot] then
			add_partial(partials, itemid, slot)
		end
	end
	for _, bag, slot in core.IterateBags(pass.source, true, "withdraw") do
		local source = encode_bagslot(bag, slot)
		local itemid = bag_ids[source]
		local targets = partials[itemid]
		if targets and #targets > 0 and not is_ignored(bag, slot) and can_move(itemid, bag, slot) then
			merge_partials(pass.summary, source, targets, used_sources)
		end
	end
end

function core.Stack(source_bags, target_bags, can_move)
	local pass = { source = source_bags, target = target_bags, summary = {} }
	merge_existing(pass, can_move or default_can_move, core.NewIgnoreChecker())
	return pass.summary
end

local function is_player_bag(bag)
	return tContains(core.player_bags, bag)
end

local function all_bags_match(bags, matches)
	for _, bag in ipairs(bags) do
		if not matches(bag) then return false end
	end
	return #bags > 0
end

local function new_stack_source(pass)
	if pass.source == pass.target then return end
	if core.db.stack_to_bank_existing and all_bags_match(pass.target, core.is_bank_bag) then
		return is_player_bag
	end
	if core.db.stack_to_bags_existing and all_bags_match(pass.target, is_player_bag) then
		return core.is_bank_bag
	end
end

local function take_empty_slot(empty, bag, slot)
	local suitable = {}
	for i = 1, #empty do
		local index = core.db.backfill and (#empty - i + 1) or i
		local target = empty[index]
		if not bag_ids[target] then
			local target_bag = decode_bagslot(target)
			if suitable[target_bag] == nil then suitable[target_bag] = not not core.CanItemGoInBag(bag, slot, target_bag) end
			if suitable[target_bag] then return table.remove(empty, index) end
		end
	end
end

local function create_stacks(pass, can_move, is_ignored, new_stacks, specialty, want_specialty)
	local source_matches = new_stack_source(pass)
	if not source_matches then return end
	local slots = destination_slots(pass.target, is_ignored)
	local empty, has_new_partial = {}, false
	for _, slot in ipairs(slots) do
		if not bag_ids[slot] then
			local bag = decode_bagslot(slot)
			if specialty[bag] == nil then
				local kind = core.IsSpecialtyBag(bag)
				specialty[bag] = not not (kind and kind ~= "Normal")
			end
			if specialty[bag] == want_specialty then table.insert(empty, slot) end
		elseif new_stacks[slot] and bag_stacks[slot] < bag_maxstacks[slot] then
			has_new_partial = true
		end
	end
	if #empty == 0 and not has_new_partial then return end

	local partials, stored, families = {}, {}, {}
	local include_ranks = core.db.stack_bank_quality
	for _, slot in ipairs(slots) do
		local itemid = bag_ids[slot]
		if itemid then
			local key, rank = stored_item_key(slot)
			if key then
				stored[key] = true
				local family = include_ranks and rank and crafting_quality_key(itemid)
				if family then families[family] = true end
				if new_stacks[slot] and bag_stacks[slot] < bag_maxstacks[slot] then add_partial(partials, key, slot) end
			end
		end
	end

	for _, bag, slot in core.IterateBags(pass.source, true, "withdraw") do
		local source = encode_bagslot(bag, slot)
		local itemid = bag_ids[source]
		if itemid and source_matches(bag) and not is_ignored(bag, slot) then
			local key, rank = stored_item_key(source)
			if (stored[key] or (include_ranks and rank and families[crafting_quality_key(itemid)]))
				and can_move(itemid, bag, slot)
			then
				merge_partials(pass.summary, source, partials[key])
				local target = bag_ids[source] and take_empty_slot(empty, bag, slot)
				if target then
					queue_move(pass.summary, source, target, bag_stacks[source])
					new_stacks[target] = true
					if bag_stacks[target] < bag_maxstacks[target] then add_partial(partials, key, target) end
				end
			end
		end
	end
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

local function stack_passes(source_bags, target_bags)
	if source_bags == target_bags then
		return {{ source = source_bags, target = target_bags, summary = {} }}
	end
	local passes = {}
	local targets = expand_bank(target_bags)
	for _, source in ipairs(expand_bank(source_bags)) do
		for _, target in ipairs(targets) do
			table.insert(passes, { source = source.bags, target = target.bags, label = source.label or target.label, summary = {} })
		end
	end
	return passes
end

local function stack_data_ready(source_bags, target_bags)
	if not core.supports_stack_quality then return true end
	if not (core.db.stack_to_bank_existing or core.db.stack_to_bags_existing) then return true end

	local is_ignored = core.NewIgnoreChecker()
	local checked = {}
	local ready = true
	local is_cached = C_Item.IsItemDataCachedByID
	local request_data = C_Item.RequestLoadItemDataByID
	local include_ranks = core.db.stack_bank_quality
	local function check_items(bags, role, matches)
		for _, bag, slot in core.IterateBags(bags, nil, role) do
			local itemid = bag_ids[encode_bagslot(bag, slot)]
			if itemid and not checked[itemid] and (not matches or matches(bag)) and not is_ignored(bag, slot) then
				checked[itemid] = true
				if (is_cached and not is_cached(itemid)) or (include_ranks and not crafting_quality_key(itemid)) then
					if request_data then request_data(itemid) end
					ready = false
				end
			end
		end
	end
	for _, pass in ipairs(stack_passes(source_bags, target_bags)) do
		local source_matches = new_stack_source(pass)
		if source_matches then
			check_items(pass.source, "withdraw", source_matches)
			check_items(pass.target, "deposit")
		end
	end
	return ready
end

function core.StackSummary(source_bags, target_bags, can_move)
	local passes = stack_passes(source_bags, target_bags)
	local is_ignored = core.NewIgnoreChecker()
	can_move = can_move or default_can_move
	-- Fill partial stacks in every selected bank before allocating empty slots.
	for _, pass in ipairs(passes) do
		merge_existing(pass, can_move, is_ignored)
	end
	local new_stacks, specialty = {}, {}
	for _, pass in ipairs(passes) do
		create_stacks(pass, can_move, is_ignored, new_stacks, specialty, true)
	end
	for _, pass in ipairs(passes) do
		create_stacks(pass, can_move, is_ignored, new_stacks, specialty, false)
		local summary_text = build_summary_text(pass.summary)
		if summary_text then
			if #passes > 1 then
				core.announce(1, L['stacking_bank']:format(pass.label, summary_text))
			else
				core.announce(1, L['stacking']:format(summary_text))
			end
		end
	end
end

function core.StackCommand(groups)
	return core.CommandDecorator(core.StackSummary, groups, 2, true, stack_data_ready)
end

SlashCmdList["BANKSTACK"] = core.StackCommand("bags bank")
SLASH_BANKSTACK1 = "/stack"
SlashCmdList["COMPRESSBAGS"] = core.CommandDecorator(core.Compress, "bags")
SLASH_COMPRESSBAGS1 = "/compress"
SLASH_COMPRESSBAGS2 = "/compressbags"
