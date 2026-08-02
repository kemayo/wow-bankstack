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
local summary = {}

local function default_can_move() return true end
local function stack_once(source_bags, target_bags, can_move, summary_out)
	-- Fill incomplete stacks in target_bags with items from source_bags.
	-- source_bags: table, e.g. {1,2,3,4}
	-- target_bags: table, e.g. {1,2,3,4}
	-- can_move: function or nil.  Called as can_move(itemid, bag, slot)
	--   for any slot in source that is not empty and contains an item that
	--   could be moved to target.  If it returns false then ignore the slot.
	if not can_move then can_move = default_can_move end
	local summary_table = summary_out or summary
	wipe(summary_table)
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
					-- can't stack to itself, or to a full slot, or to a slot that has already been used as a source:

					-- record a summary of the move (has to happen before AddMove, since that updates bag_stacks)
					summary_table[itemid] = (summary_table[itemid] or 0) + bag_stacks[source_slot]

					-- Schedule moving from this slot to the bank slot.
					core.AddMove(source_slot, target_slot)
					source_used[source_slot] = true

					if bag_stacks[target_slot] == bag_maxstacks[target_slot] then
						target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
					end
					if bag_stacks[source_slot] == 0 then
						-- This bag slot is emptied, move on.
						target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
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

local function resolve_stack_targets(target_bags)
	if target_bags ~= core.bank_bags then
		return { { bags = target_bags } }
	end
	local targets = {}
	local bank_target = core.db.bank_target or "both"
	local account_bags = core.account_bags or {}
	local has_account = #account_bags > 0

	local function add(label, bags)
		if bags and #bags > 0 then
			table.insert(targets, { label = label, bags = bags })
		end
	end

	if bank_target == "warband" then
		if has_account then
			add("Warband bank", account_bags)
		else
			add("Character bank", target_bags)
		end
	elseif bank_target == "character" then
		add("Character bank", target_bags)
	else
		if has_account then
			add("Warband bank", account_bags)
		end
		add("Character bank", target_bags)
	end

	if #targets == 0 then
		table.insert(targets, { bags = target_bags })
	end
	return targets
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

function core.Stack(source_bags, target_bags, can_move)
	local targets = resolve_stack_targets(target_bags)
	for _, target in ipairs(targets) do
		stack_once(source_bags, target.bags, can_move)
	end
end

function core.StackSummary(...)
	local source_bags, target_bags, can_move = ...
	local targets = resolve_stack_targets(target_bags)
	for _, target in ipairs(targets) do
		local target_summary = {}
		stack_once(source_bags, target.bags, can_move, target_summary)
		local summary_text = build_summary_text(target_summary)
		if summary_text then
			local prefix = "Stacking items"
			if #targets > 1 and target.label then
				prefix = prefix .. " (" .. target.label .. ")"
			end
			core.announce(1, prefix .. ": " .. summary_text)
		end
	end
end

SlashCmdList["BANKSTACK"] = core.CommandDecorator(core.StackSummary, "bags bank", 2)
SLASH_BANKSTACK1 = "/stack"
SlashCmdList["COMPRESSBAGS"] = core.CommandDecorator(core.Compress, "bags")
SLASH_COMPRESSBAGS1 = "/compress"
SLASH_COMPRESSBAGS2 = "/compressbags"
