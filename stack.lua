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

local function item_keys(slot, families)
	local itemid = bag_ids[slot]
	local rank = crafting_rank(slot)
	if rank then return itemid .. ":" .. rank, families[itemid] end
	return itemid
end

local function crafting_quality_key(itemid)
	-- Ranks may have different item IDs but share their name and category.
	local name, _, _, _, _, _, _, _, _, _, _, class, subclass, _, expansion = C_Item.GetItemInfo(itemid)
	if name and class and subclass and expansion then
		return string.format("family:%s:%d:%d:%d", name, class, subclass, expansion)
	end
end

local target_items = {--[[link = available_slots--]]}
local source_used = {}
local target_slots = {}

local function default_can_move() return true end

local function stack_into(source, target, summary)
	local itemid, count = bag_ids[source], bag_stacks[source]
	if bag_ids[target] then
		count = math.min(count, bag_maxstacks[target] - bag_stacks[target])
	end
	summary[itemid] = (summary[itemid] or 0) + count
	core.AddMove(source, target)
	return bag_stacks[target] == bag_maxstacks[target]
end

-- Returns a table of itemid -> count moved.
function core.Stack(source_bags, target_bags, can_move)
	-- Fill incomplete stacks in target_bags with items from source_bags.
	-- source_bags: table, e.g. {1,2,3,4}
	-- target_bags: table, e.g. {1,2,3,4}
	-- can_move: function or nil.  Called as can_move(itemid, bag, slot)
	--   for any slot in source that is not empty and contains an item that
	--   could be moved to target.  If it returns false then ignore the slot.
	if not can_move then can_move = default_can_move end
	local summary_table = {}
	-- Model the target bags.
	for _, bag, slot in core.IterateBags(target_bags, nil, "deposit") do
		local bagslot = encode_bagslot(bag, slot)
		local itemid = bag_ids[bagslot]
		if not core.IsIgnored(bag, slot) and itemid and (bag_stacks[bagslot] ~= bag_maxstacks[bagslot]) then
			-- This is an item type that we'll want to bother moving.
			target_items[itemid] = (target_items[itemid] or 0) + 1
			table.insert(target_slots, bagslot)
		end
	end
	-- Now go through the source bags... in reverse.
	for _, bag, slot in core.IterateBags(source_bags, true, "withdraw") do
		local source_slot = encode_bagslot(bag, slot)
		local itemid = bag_ids[source_slot]
		if not core.IsIgnored(bag, slot) and itemid and target_items[itemid] and can_move(itemid, bag, slot) then
			--there's an item in this slot *and* we have room for more of it in the bank somewhere
			for i=#target_slots, 1, -1 do
				local target_slot = target_slots[i]
				if
					bag_ids[source_slot] -- slot hasn't been emptied
					and bag_ids[target_slot] == itemid -- target is same as source
					and target_slot ~= source_slot -- target *isn't* source
					and bag_stacks[target_slot] ~= bag_maxstacks[target_slot] -- target isn't full
					and not source_used[target_slot] -- already moved from slot
				then
					local full = stack_into(source_slot, target_slot, summary_table)
					source_used[source_slot] = true

					if full then
						target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
					end
					if not bag_ids[source_slot] then
						-- This bag slot is emptied, move on.
						break
					end
					if not target_items[itemid] then break end
				end
			end
		end
	end
	-- clean up the various cache tables
	wipe(target_items)
	wipe(target_slots)
	wipe(source_used)
	return summary_table
end

local function is_player_bag(bag)
	return tContains(core.player_bags, bag)
end

local function new_stack_source(source, target)
	if source == target or #target == 0 then return end
	local to_bank = core.is_bank_bag(target[1])
	local target_matches = to_bank and core.is_bank_bag or is_player_bag
	for _, bag in ipairs(target) do
		if not target_matches(bag) then return end
	end
	if to_bank and core.db.stack_to_bank_existing then return is_player_bag end
	if not to_bank and core.db.stack_to_bags_existing then return core.is_bank_bag end
end

local function index_destination(destination, families)
	for _, target in ipairs(destination.slots) do
		if bag_ids[target] then
			local key, family = item_keys(target, families)
			destination.eligible[key] = true
			if family then destination.eligible[family] = true end
		else
			local bag = decode_bagslot(target)
			local kind = core.IsSpecialtyBag(bag)
			table.insert(kind and kind ~= "Normal" and destination.specialty or destination.normal, target)
		end
	end
end

local function create_stacks(pass, families, can_move, empty)
	local destination = pass.overflow
	local partials, eligible = destination.partials, destination.eligible
	for _, source in ipairs(pass.sources) do
		local itemid = bag_ids[source]
		if itemid then
			local bag, slot = decode_bagslot(source)
			local key, family = item_keys(source, families)
			if (eligible[key] or eligible[family]) and can_move(itemid, bag, slot) then
				local rejected = {}
				-- Always fill the new partial stack before opening another for this item and rank.
				local partial = partials[key]
				if partial then
					local target_bag = decode_bagslot(partial)
					if not core.CanItemGoInBag(bag, slot, target_bag) then
						rejected[target_bag] = true
					elseif stack_into(source, partial, pass.summary) then
						partials[key] = nil
					end
				end
				if bag_ids[source] then
					for i = 1, #empty do
						local index = core.db.backfill and (#empty - i + 1) or i
						local target = empty[index]
						local target_bag = decode_bagslot(target)
						if not rejected[target_bag] and core.CanItemGoInBag(bag, slot, target_bag) then
							if not stack_into(source, target, pass.summary) then partials[key] = target end
							table.remove(empty, index)
							break
						end
						rejected[target_bag] = true
					end
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

local function stack_plan(source_bags, target_bags, check_data)
	local passes, sources, destinations, families = {}, {}, {}, {}
	local ready = true
	local function collect(bags, source_matches)
		local slots, seen = {}, {}
		for _, bag, slot in core.IterateBags(bags, source_matches ~= nil, source_matches and "withdraw" or "deposit") do
			local bagslot = encode_bagslot(bag, slot)
			local itemid = bag_ids[bagslot]
			if not seen[bagslot] and (not source_matches or source_matches(bag)) and not core.IsIgnored(bag, slot) then
				if not source_matches then seen[bagslot] = true end
				table.insert(slots, bagslot)
				if itemid and families[itemid] == nil then
					local family = core.db.stack_bank_quality and crafting_quality_key(itemid)
					families[itemid] = family or false
					if check_data and core.supports_stack_quality and (
						(C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemid))
						or (core.db.stack_bank_quality and not family)
					) then
						if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemid) end
						ready = false
					end
				end
			end
		end
		return slots
	end
	if source_bags == target_bags then
		passes[1] = { source = source_bags, target = target_bags }
	else
		local targets = expand_bank(target_bags)
		for _, source in ipairs(expand_bank(source_bags)) do
			for _, target in ipairs(targets) do
				local pass = { source = source.bags, target = target.bags, label = source.label or target.label }
				local source_matches = new_stack_source(pass.source, pass.target)
				if source_matches then
					if not sources[pass.source] then sources[pass.source] = collect(pass.source, source_matches) end
					if not destinations[pass.target] then
						destinations[pass.target] = {
							slots = collect(pass.target), eligible = {},
							specialty = {}, normal = {}, partials = {},
						}
					end
					pass.sources, pass.overflow = sources[pass.source], destinations[pass.target]
				end
				table.insert(passes, pass)
			end
		end
	end
	if ready then return { passes = passes, destinations = destinations, families = families } end
end

local function stack_summary(plan, can_move)
	can_move = can_move or default_can_move
	local passes, families = plan.passes, plan.families
	-- Fill partial stacks in every selected bank before allocating empty slots.
	for _, pass in ipairs(passes) do
		pass.summary = core.Stack(pass.source, pass.target, can_move)
	end
	for _, destination in pairs(plan.destinations) do index_destination(destination, families) end
	for _, pass in ipairs(passes) do
		if pass.overflow then create_stacks(pass, families, can_move, pass.overflow.specialty) end
	end
	for _, pass in ipairs(passes) do
		if pass.overflow then create_stacks(pass, families, can_move, pass.overflow.normal) end
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

function core.StackSummary(source_bags, target_bags, can_move)
	stack_summary(stack_plan(source_bags, target_bags), can_move)
end

function core.StackCommand(groups)
	local plan
	return core.CommandDecorator(function()
		local ready_plan = plan
		plan = nil
		stack_summary(ready_plan)
	end, groups, 2, true, function(source, target)
		plan = stack_plan(source, target, true)
		return plan ~= nil
	end)
end

SlashCmdList["BANKSTACK"] = core.StackCommand("bags bank")
SLASH_BANKSTACK1 = "/stack"
SlashCmdList["COMPRESSBAGS"] = core.CommandDecorator(core.Compress, "bags")
SLASH_COMPRESSBAGS1 = "/compress"
SLASH_COMPRESSBAGS2 = "/compressbags"
