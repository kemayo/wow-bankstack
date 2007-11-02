local core = BankStack
local L = core.L

local link_to_id = core.link_to_id
local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot
local encode_move = core.encode_move
local clear = core.clear
local moves = core.moves

SlashCmdList["BANKSTACK"] = core.BankStack
SLASH_BANKSTACK1 = "/bankstack"
SlashCmdList["COMPRESSBAGS"] = core.Compress
SLASH_COMPRESSBAGS1 = "/compress"
SLASH_COMPRESSBAGS2 = "/compressbags"

function core.BankStack(arg)
	if not core.bank_open then
		core.announce(0, L.at_bank, 1, 0, 0)
		return
	end
	core.bankrequired = true
	core.Stack(
		arg=="reverse" and core.bank_bags or core.player_bags,
		arg=="reverse" and core.player_bags or core.bank_bags
	)
	core.StartStacking()
end
do
	-- This is a stack filterer.  It's used to stop full stacks being shuffled around
	-- while compressing bags.
	local function is_partial(itemid, bag, slot)
		-- (stacksize - count) > 0
		return (select(8, GetItemInfo(itemid)) - select(2, GetContainerItemInfo(bag, slot))) > 0
	end
	function core.Compress(arg)
		local bags
		if arg=="bank" then
			if not core.bank_open then
				core.announce(0, L.at_bank, 1, 0, 0)
				return
			else
				bags = core.bank_bags
				core.bankrequired = true
			end
		else
			bags = core.player_bags
		end
		core.Stack(bags, bags, is_partial)
		core.StartStacking()
	end
end

-- Stacking:

local target_items = {--[[link = available_slots--]]}
local target_links = {--[[encode_bagslot = link--]]}
local target_sinks = {--[[encode_bagslot = room_in_slot--]]}
local source_used = {}

local function default_can_move() return true end
function core.Stack(source_bags, target_bags, can_move)
	-- Fill incomplete stacks in target_bags with items from source_bags.
	-- source_bags: table, e.g. {1,2,3,4}
	-- target_bags: table, e.g. {1,2,3,4}
	-- can_move: function or nil.  Called as can_move(itemid, bag, slot)
	--   for any slot in source that is not empty and contains an item that
	--   could be moved to target.  If it returns false then ignore the slot.
	-- Note: This function just creates a list of moves to make, then unhides
	-- frame to get its OnUpdate going.
	-- TODO: Stack so remaining empty stacks are earlier in the bag, and get used up first?
	if current_id then
		core.announce(0, L.already_running, 1, 0, 0)
		return
	end
	if not can_move then can_move = default_can_move end
	-- Model the target bags.
	for _,bag in pairs(target_bags) do
		local slots = GetContainerNumSlots(bag)
		for slot=1, slots do
			local link = link_to_id(GetContainerItemLink(bag, slot))
			if link then
				local stack_size = select(8, GetItemInfo(link))
				local count = select(2, GetContainerItemInfo(bag, slot))
				-- If this stack is full we don't care about it
				-- Sadly, making this more general means we can't filter on GetItemCount(link) here, too.
				if count ~= stack_size then
					local id = encode_bagslot(bag, slot)
					target_items[link] = (target_items[link] and target_items[link] or 0) + 1
					target_links[id] = link
					target_sinks[id] = stack_size - count
				end
			end
		end
	end
	-- Now go through the source bags...
	for _,bag in pairs(source_bags) do
		local slots = GetContainerNumSlots(bag)
		for slot=1, slots do
			local link = link_to_id(GetContainerItemLink(bag, slot))
			if link and target_items[link] and can_move(link, bag, slot) then
				--there's an item in this slot *and* we have room for more of it in the bank somewhere
				local source_slot = encode_bagslot(bag, slot)
				local count = select(2, GetContainerItemInfo(bag, slot))
				for target_slot, target_link in pairs(target_links) do
					if not target_items[link] then break end
					-- can't stack to itself, or to a slot that has already been used as a source:
					if target_link == link and target_slot ~= source_slot and not source_used[target_slot] then
						-- Schedule moving from this slot to the bank slot.
						table.insert(moves, encode_move(source_slot, target_slot))
						source_used[source_slot] = true
						-- Deal with the bank slot:
						local room = target_sinks[target_slot]
						if room > count then
							-- This bag slot is emptied, and there's still room in the bank slot for more
							target_sinks[target_slot] = room - count
							if target_sinks[source_slot] then
								target_items[link] = (target_items[link] > 1) and (target_items[link] - 1) or nil
								target_sinks[source_slot] = nil
								target_links[source_slot] = nil
							end
							break
						else
							-- The bank slot will be filled; remove it from future consideration
							target_items[link] = (target_items[link] > 1) and (target_items[link] - 1) or nil
							target_sinks[target_slot] = nil
							target_links[target_slot] = nil
							if room == count then
								-- This bag slot is emptied; stop searching the bank for this item
								if target_sinks[source_slot] then
									-- If this source slot is also in the targets, remove it.
									target_sinks[source_slot] = nil
									target_links[source_slot] = nil
									target_items[link] = (target_items[link] > 1) and (target_items[link] - 1) or nil
								end
								break
							else
								-- Still items in this bag slot; update the count and keep looking in target.
								if target_sinks[source_slot] then
									-- If this source slot is also in the targets, update its counts.
									target_sinks[source_slot] = target_sinks[source_slot] - room
								end
								count = count - room
							end
						end
					end
				end
			end
		end
	end
	-- clean up the various cache tables
	clear(target_items)
	clear(target_links)
	clear(target_sinks)
	clear(source_used)
end
