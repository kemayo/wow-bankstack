local core = BankStack
local L = core.L

local link_to_id = core.link_to_id
local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot
local encode_move = core.encode_move
local moves = core.moves

local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks

local specialty_bags = {}
function core.FillBags(arg)
	local to, from
	if arg and #arg > 2 then
		from, to = string.match(arg, "^([^%s]+)%s+([^%s]+)$")
		from = core.get_group(from)
		to = core.get_group(to)
	end
	if not (from and to) then
		from = core.player_bags
		to = core.bank_bags
	end
	if core.check_for_banks(from) or core.check_for_banks(to) then return end
	
	core.ScanBags()
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
	core.StartStacking()
end

local empty_slots = {}
function core.Fill(source_bags, target_bags, reverse)
	-- source_bags and target_bags are tables ({1,2,3})
	-- Note: assumes that any item can be placed in any bag.
	if core.running then
		core.announce(0, L.already_running, 1, 0, 0)
		return
	end
	if reverse == nil then
		reverse = core.db.backfill
	end
	--Create a list of empty slots.
	for _, bag, slot in core.IterateBags(target_bags, reverse, "deposit") do
		local bagslot = encode_bagslot(bag, slot)
		if (not core.db.ignore[bagslot]) and not bag_ids[bagslot] then
			table.insert(empty_slots, bagslot)
		end
	end
	--Move items from the back of source_bags to the front of target_bags
	for _, bag, slot in core.IterateBags(source_bags, not reverse, "withdraw") do
		if #empty_slots == 0 then break end
		local bagslot = encode_bagslot(bag, slot)
		local target_bag, target_slot = decode_bagslot(empty_slots[1])
		if
			(not core.db.ignore[bagslot])
			and
			bag_ids[bagslot]
			and
			core.CanItemGoInBag(bag, slot, target_bag)
		then
			core.AddMove(bagslot, table.remove(empty_slots, 1))
		end
	end
	wipe(empty_slots)
end

SlashCmdList["FILL"] = core.FillBags
SLASH_FILL1 = "/fill"
SLASH_FILL2 = "/fillbags"
