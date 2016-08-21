local core = BankStack
local L = core.L

local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot
local encode_move = core.encode_move
local moves = core.moves

local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks

local specialty_bags = {}
function core.FillBags(from, to)
	core.Stack(from, to)
	-- first, try to fill any specialty bags
	for _,bag in ipairs(to) do
		if core.IsSpecialtyBag(bag) then
			table.insert(specialty_bags, bag)
		end
	end
	if #specialty_bags > 0 then
		core.Fill(from, specialty_bags)
	end
	-- and now the rest (no point filtering out the specialty bags here; it's covered)
	core.Fill(from, to)
	wipe(specialty_bags)
end

local empty_slots = {}
local function default_can_move() return true end
local function default_should_halt() return #empty_slots == 0 end

function core.Fill(source_bags, target_bags, reverse, can_move, should_halt)
	-- source_bags: table, e.g. {1,2,3,4}
	-- target_bags: table, e.g. {1,2,3,4}
	-- reverse: bool, whether to fill from the front or back of the bags
	-- can_move: function or nil.  Called as can_move(itemid, bag, slot)
	--   for any slot in source that is not empty and contains an item that
	--   could be moved to target.  If it returns false then ignore the slot.
	-- should_halt: function or nil. Called as should_halt(itemid, bag, slot)
	--   for any slot in source. If it returns true, stop all filling. Default
	--   is to stop if we run out of empty slots to fill to. (Squash uses it
	--   to halt if the bag-state becomes squashed.)
	if reverse == nil then
		reverse = core.db.backfill
	end
	can_move = can_move or default_can_move
	should_halt = should_halt or default_should_halt
	--Create a list of empty slots in the target bags
	for _, bag, slot in core.IterateBags(target_bags, reverse, "deposit") do
		local bagslot = encode_bagslot(bag, slot)
		if not core.IsIgnored(bag, slot) and not bag_ids[bagslot] then
			table.insert(empty_slots, bagslot)
		end
	end
	--Move items from the back of source_bags to the front of target_bags (or
	--front to back if `reverse`)
	for _, bag, slot in core.IterateBags(source_bags, not reverse, "withdraw") do
		if should_halt(bag_ids[bagslot], bag, slot) then break end
		local bagslot = encode_bagslot(bag, slot)
		local target_bag, target_slot = decode_bagslot(empty_slots[1])
		if
			not core.IsIgnored(bag, slot)
			and bag_ids[bagslot]
			and core.CanItemGoInBag(bag, slot, target_bag)
			and can_move(bag_ids[bagslot], bag, slot)
		then
			core.AddMove(bagslot, table.remove(empty_slots, 1))
		end
	end
	wipe(empty_slots)
end

function is_squashed(bags, reverse)
	--Bags are "squashed" if they contain only a contiguous set of items starting at the front of the bag
	local was_filled = true
	for _, bag, slot in core.IterateBags(bags, reverse, "deposit") do
		local bagslot = encode_bagslot(bag, slot)
		if not core.IsIgnored(bag, slot) then
			if not was_filled and bag_ids[bagslot] then
				-- last slot was empty, this slot is not, therefore a gap exists
				return false
			end
			was_filled = bag_ids[bagslot]
		end
	end
	return true
end

function core.Squash(bags, reverse, can_move)
	-- bags: table, e.g. {1,2,3,4}
	return core.Fill(bags, bags, reverse, can_move, function(itemid, bag, slot)
		if is_squashed(bags) then
			return true
		end
		return default_should_halt(itemid, bag, slot)
	end)
end

SlashCmdList["FILL"] = core.CommandDecorator(core.FillBags, "bags bank", 2)
SLASH_FILL1 = "/fill"
SLASH_FILL2 = "/fillbags"

SlashCmdList["SQUASH"] = core.CommandDecorator(core.Squash, "bags", 1)
SLASH_SQUASH1 = "/squash"
SLASH_SQUASH2 = "/squashbags"
