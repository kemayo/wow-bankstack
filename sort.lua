local core = BankStack
local L = core.L
local Debug = core.Debug

local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot
local encode_move = core.encode_move
local moves = core.moves

local bagcache = {}
local bag_groups = {}
function core.SortBags(...)
	local start = 1
	local sorter
	if type(...) == "function" then
		start = 2
		sorter = ...
	end
	for i = start, select("#", ...) do
		local bags = select(i, ...)
		for _, bag in ipairs(bags) do
			Debug("Considering bag", bag)
			local bagtype = core.IsSpecialtyBag(bag)
			if not bagtype then bagtype = 'Normal' end
			if not bagcache[bagtype] then bagcache[bagtype] = {} end
			table.insert(bagcache[bagtype], bag)
			Debug(" went with", bag, bagtype)
		end
		for bagtype, sorted_bags in pairs(bagcache) do
			if bagtype ~= 'Normal' then
				Debug("Moving to normal from", bagtype)
				core.Stack(sorted_bags, sorted_bags, core.is_partial)
				core.Stack(bagcache['Normal'], sorted_bags)
				core.Fill(bagcache['Normal'], sorted_bags, core.db.reverse)
				core.Sort(sorted_bags, sorter)
				wipe(sorted_bags)
			end
		end
		if bagcache['Normal'] then
			core.Stack(bagcache['Normal'], bagcache['Normal'], core.is_partial)
			core.Sort(bagcache['Normal'], sorter)
			wipe(bagcache['Normal'])
		end
		wipe(bagcache)
	end
end

-- Sorting:
local inventory_slots = {
	INVTYPE_AMMO = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 12,
	INVTYPE_CLOAK = 13,
	INVTYPE_WEAPON = 14,
	INVTYPE_SHIELD = 15,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 18,
	INVTYPE_WEAPONOFFHAND = 19,
	INVTYPE_HOLDABLE = 20,
	INVTYPE_RANGED = 21,
	INVTYPE_THROWN = 22,
	INVTYPE_RANGEDRIGHT = 23,
	INVTYPE_RELIC = 24,
	INVTYPE_TABARD = 25,
}

-- Sorting
local item_types
local item_subtypes
local function build_sort_order()
	item_types = {}
	item_subtypes = {}
	for i, itype in ipairs({GetAuctionItemClasses()}) do
		item_types[itype] = i
		item_subtypes[itype] = {}
		for ii, istype in ipairs({GetAuctionItemSubClasses(i)}) do
			item_subtypes[itype][istype] = ii
		end
	end
end

local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks
local bag_soulbound = setmetatable({}, {__index = function(self, bagslot)
	local bag, slot = decode_bagslot(bagslot)
	local is_soulbound = core.CheckTooltipFor(bag, slot, ITEM_SOULBOUND) or core.CheckTooltipFor(bag, slot, ITEM_BNETACCOUNTBOUND)
	self[bagslot] = is_soulbound
	return is_soulbound
end,})
local bag_conjured = setmetatable({}, {__index = function(self, bagslot)
	local bag, slot = decode_bagslot(bagslot)
	local is_conjured = core.CheckTooltipFor(bag, slot, ITEM_CONJURED)
	self[bagslot] = is_conjured
	return is_conjured
end,})
local function prime_sort(a, b)
	local a_name, _, a_rarity, a_level, a_minLevel, a_type, a_subType, a_stackCount, a_equipLoc, a_texture, a_price = GetItemInfo(bag_ids[a])
	local b_name, _, b_rarity, b_level, b_minLevel, b_type, b_subType, b_stackCount, b_equipLoc, b_texture, b_price = GetItemInfo(bag_ids[b])
	if a_level ~= b_level then
		return a_level > b_level
	end
	if a_price ~= b_price then
		return a_price > b_price
	end
	return a_name < b_name
end
local initial_order = {}
local function default_sorter(a, b)
	-- a and b are from encode_bagslot
	-- note that "return initial_order[a] < initial_order[b]" would maintain the bag's state
	-- I'm certain this could be made to be more efficient
	local a_id = bag_ids[a]
	local b_id = bag_ids[b]
	
	-- is either slot empty?  If so, move it to the back.
	if (not a_id) or (not b_id) then return a_id end
	
	local a_order, b_order = initial_order[a], initial_order[b]

	-- are they the same item?
	if a_id == b_id then
		local a_count = bag_stacks[a]
		local b_count = bag_stacks[b]
		if a_count == b_count then
			-- maintain the original order
			return a_order < b_order
		else
			-- emptier stacks to the front
			return a_count < b_count
		end
	end
	
	-- Conjured items to the back?
	if core.db.conjured and not bag_conjured[a] == bag_conjured[b] then
		if bag_conjured[a] then return false end
		if bag_conjured[b] then return true end
	end
	
	local a_name, _, a_rarity, a_level, a_minLevel, a_type, a_subType, a_stackCount, a_equipLoc, a_texture = GetItemInfo(a_id)
	local b_name, _, b_rarity, b_level, b_minLevel, b_type, b_subType, b_stackCount, b_equipLoc, b_texture = GetItemInfo(b_id)

	-- Quick sanity-check to make sure we correctly fetched information about the items
	if not (a_name and b_name and a_rarity and b_rarity) then
		-- preserve the existing order in this case
		return a_order < b_order
	end

	-- junk to the back?
	if core.db.junk and not (a_rarity == b_rarity) then
		if a_rarity == 0 then return false end
		if b_rarity == 0 then return true end
	end
	
	-- Soulbound items to the front?
	if core.db.soulbound and bag_soulbound[a] ~= bag_soulbound[b] then
		if bag_soulbound[a] then return true end
		if bag_soulbound[b] then return false end
	end

	if a_rarity ~= b_rarity then
		return a_rarity > b_rarity
	end

	if item_types[a_type] ~= item_types[b_type] then
		return (item_types[a_type] or 99) < (item_types[b_type] or 99)
	end

	-- are they the same type?
	if a_type == ARMOR or a_type == ENCHSLOT_WEAPON then
		-- "or -1" because some things are classified as armor/weapon without being equipable; note Everlasting Underspore Frond
		local a_equipLoc = inventory_slots[a_equipLoc] or -1
		local b_equipLoc = inventory_slots[b_equipLoc] or -1
		if a_equipLoc == b_equipLoc then
			-- sort by level, then name
			return prime_sort(a, b)
		end
		return a_equipLoc < b_equipLoc
	end
	if a_subType == b_subType then
		return prime_sort(a, b)
	end
	return ((item_subtypes[a_type] or {})[a_subType] or 99) < ((item_subtypes[b_type] or {})[b_subType] or 99)
end
local function reverse_sort(a, b) return default_sorter(b, a) end

local bag_sorted = {}
local bag_locked = {}
local function update_sorted(source, destination)
	for i,bs in pairs(bag_sorted) do
		if bs == source then
			bag_sorted[i] = destination
		elseif bs == destination then
			bag_sorted[i] = source
		end
	end
end

local function should_actually_move(source, destination)
	-- work out whether a move from source to destination actually makes sense to do
	
	-- skip it if...
	-- source and destination are the same
	if destination == source then return end
	-- nothing's in the source slot
	if not bag_ids[source] then return end
	-- slot contents are the same and stack sizes are the same
	if bag_ids[source] == bag_ids[destination] and bag_stacks[source] == bag_stacks[destination] then return end
	
	-- go for it!
	return true
end

function core.Sort(bags, sorter)
	-- bags: table, e.g. {1,2,3,4}
	-- sorter: function or nil.  Passed to table.sort.
	if not sorter then sorter = core.db.reverse and reverse_sort or default_sorter end
	if not item_types then build_sort_order() end
	
	for i, bag, slot in core.IterateBags(bags, nil, "both") do
		--(you need withdraw *and* deposit permissions in the guild bank to move items within it)
		local bagslot = encode_bagslot(bag, slot)
		if (not core.db.ignore_bags[bag] and not core.db.ignore[bagslot]) then
			initial_order[bagslot] = i
			table.insert(bag_sorted, bagslot)
		end
	end
	
	table.sort(bag_sorted, sorter)
	for i,s in ipairs(bag_sorted) do Debug("SORTED", i, core.GetItemLink(decode_bagslot(s))) end
	
	-- We now have bag_sorted, which is a table containing all slots that contain items, in the order
	-- that they need to be moved into.
	
	local another_pass_needed = true
	local passes_tried = 0
	while another_pass_needed do
		-- Multiple "passes" are simulated here, for the purpose of fitting as many moves as possible
		-- into a single run of the mover, which moves until it finds a locked item, then breaks until
		-- the game removes the lock. By sequencing moves correctly, locks can be avoided as much as
		-- possible.
		another_pass_needed = false
		local i = 1
		for _, bag, slot in core.IterateBags(bags, nil, "both") do
			-- Make sure the origin slot isn't empty; if so no move needs to be scheduled.
			local destination = encode_bagslot(bag, slot) -- This is like i, increasing as we go on.
			local source = bag_sorted[i]
			
			-- If destination is ignored we skip everything here
			-- Notably, i does not get incremented.
			if not core.db.ignore_bags[bag] and not core.db.ignore[destination] then
				if should_actually_move(source, destination) then
					if not (bag_locked[source] or bag_locked[destination]) then
						core.AddMove(source, destination)
						update_sorted(source, destination)
						bag_locked[source] = true
						bag_locked[destination] = true
					else
						-- If we've moved to the destination or source slots before in this run
						-- then we pass and request another run. This is to make sure as many
						-- moves as possible run per pass.
						another_pass_needed = true
					end
				end
				i = i + 1
			end
		end
		wipe(bag_locked)
		passes_tried = passes_tried + 1
		if passes_tried > 666 then
			Debug("Broke out of passes because it took over 666 tries")
			break
		end
	end
	wipe(bag_soulbound)
	wipe(bag_conjured)
	wipe(bag_sorted)
	wipe(initial_order)
end

SlashCmdList["SORT"] = core.CommandDecorator(core.SortBags, 'bags')
SLASH_SORT1 = "/sort"
SLASH_SORT2 = "/sortbags"

SlashCmdList["SHUFFLE"] = core.CommandDecorator(function(...)
	local sort = {}
	core.SortBags(function(a, b)
		if not sort[a] then
			sort[a] = math.random()
		end
		if not sort[b] then
			sort[b] = math.random()
		end
		return sort[a] < sort[b]
	end, ...)
	wipe(sort)
end, 'bags')
SLASH_SHUFFLE1 = "/shuffle"
SLASH_SHUFFLE2 = "/shufflebags"
