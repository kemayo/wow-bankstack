local core = BankStack
local L = core.L

local link_to_id = core.link_to_id
local encode_bagslot = core.encode_bagslot
local decode_bagslot = core.decode_bagslot
local encode_move = core.encode_move
local clear = core.clear
local moves = core.moves

local bagcache = {}
function core.SortBags(arg)
	local bags = core.get_group(arg)
	if not bags then
		bags = core.player_bags
	end
	if core.contains_bank_bag(bags) then
		if not core.bank_open then
			core.announce(0, L.at_bank, 1, 0, 0)
			return
		end
		core.bankrequired = true
	end

	core.ScanBags()
	for _,bag in ipairs(bags) do
		local bagtype = core.IsSpecialtyBag(bag)
		if not bagtype then bagtype = 'Normal' end
		if not bagcache[bagtype] then bagcache[bagtype] = {} end
		table.insert(bagcache[bagtype], bag)
	end
	for _, sorted_bags in pairs(bagcache) do
		core.Stack(sorted_bags, sorted_bags, core.is_partial)
		core.Sort(sorted_bags)
		clear(sorted_bags)
	end
	core.StartStacking()
end

-- Sorting:
local item_types = {
	[L.ARMOR] = 1,
	[L.WEAPON] = 2,
	[L.QUEST] = 3,
	[L.KEY] = 4,
	[L.RECIPE] = 5,
	[L.REAGENT] = 6,
	[L.TRADEGOODS] = 7,
	[L.GEM] = 8,
	[L.CONSUMABLE] = 9,
	[L.CONTAINER] = 10,
	[L.QUIVER] = 11,
	[L.MISC] = 12,
	[L.PROJECTILE] = 13,
}
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
-- Trade goods have crappy subtypes.  They are "trade goods", "devices", "parts", and "explosives".
--  Yes, three for Engineering, one for the rest.
local trade_goods = {
	--primals and motes
	primal = {23571, 22451, 22452, 21884, 21886, 22457, 22456, 21885, 22572, 22573, 22574, 22575, 22576, 22577, 22578,},
	--tailoring
	bolts = {2996, 2997, 4305, 4339, 14048, 21840, 21842, 21844,},
	cloth = {2589, 2592, 4306, 4338, 14047, 21877, 23854, 23855,},
	--mining
	--gems = {}, --most gems are correctly under "gems", so.
	stone = {2836, 12365, 2838, 7912, 2835},
	ore = {2771, 10620, 3858, 2772, 23424, 11370, 23427, 2776, 23426, 2775, 7911, 23425, 2770, 11370,},
	bars = {12360, 17771, 23447, 23448, 3577, 23449, 2842, 6037, 23446, 2841, 2840, 11371, 23445, 23573, 3575, 3860, 3859, 12359, 3576,},
	--other
	herbs = {13468, 19726, 22790, 8836, 8839, 22710, 2450, 2453, 13463, 22786, 2449, 3818, 22794, 22785, 4625, 22788, 8845, 13464, 3821, 3369, 8846, 13467, 3358, 3356, 3357, 785, 22793, 13465, 22791, 22797, 22792, 2447, 13466, 8831, 22787, 765, 3820, 8838, 2452, 22789, 3355, 8153, 3819,},
	leather = {2934, 4236, 4231, 4233, 15407, 8172, 23793, 4234, 21887, 2318, 2319, 8170, 4304,},
	cooking = {27422,27669,3173,3730,33823,3172,2677,27671,3404,21024,27677,769,5503,27678,2673,2886,2675,2674,33824,1081,22644,13888,8150,27435,27439,4655,12207,9061,27438,2251,723,731,12204,2692,27437,24477,5467,1015,13757,3731,27668,785,12223,2678,23676,730,1468,12037,3685,12184,31670,27674,6291,6308,13754,21153,6317,6289,8365,13759,6361,13758,6362,21071,6303,4603,13756,13760,13889,12203,20424,5466,31671,30817,4470,6889,4402,5465,5468,3713,3174,27425,5471,2665,27676,5469,729,2672,2452,27682,5504,12206,3667,12208,5470,12202,1080,3712,27681,12205,27429,7974,},
	jewelcrafting = {31079, 20817, 20816, 20963, 21752,},
}
local trade_goods_order = {
	primal = 0,
	bolts = 1,
	cloth = 2,
	bars = 3,
	ore = 4,
	stone = 5,
	herbs = 6,
	leather = 7,
	cooking = 8,
	jewelcrafting = 9,
	misc = 10,
}
local function get_trade_goods_order(id)
	local cat
	for k,t in pairs(trade_goods) do
		for _,iid in pairs(t) do
			if id==iid then
				cat = k
				break
			end
		end
	end
	if not cat then return -1 end
	return trade_goods_order[cat]
end

local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks
local function prime_sort(a, b)
	local a_name, _, a_rarity, a_level, a_minLevel, a_type, a_subType, a_stackCount, a_equipLoc, a_texture = GetItemInfo(bag_ids[a])
	local b_name, _, b_rarity, b_level, b_minLevel, b_type, b_subType, b_stackCount, b_equipLoc, b_texture = GetItemInfo(bag_ids[b])
	if a_level == b_level then
		return a_name < b_name
	else
		return a_level > b_level
	end
end
local function default_sorter(a, b)
	-- a and b are from encode_bagslot
	-- note that "return a < b" would maintain the bag's state
	-- I'm certain this could be made to be more efficient
	local a_id = bag_ids[a]
	local b_id = bag_ids[b]
	
	-- is either slot empty?  If so, move it to the back.
	if (not a_id) or (not b_id) then return a_id end
	
	-- are they the same item?
	if a_id == b_id then
		local a_count = bag_stacks[a]
		local b_count = bag_stacks[b]
		if a_count == b_count then
			-- maintain the original ordering
			return a < b
		else
			-- emptier stacks to the front
			return a_count < b_count
		end
	end
	
	local a_name, _, a_rarity, a_level, a_minLevel, a_type, a_subType, a_stackCount, a_equipLoc, a_texture = GetItemInfo(a_id)
	local b_name, _, b_rarity, b_level, b_minLevel, b_type, b_subType, b_stackCount, b_equipLoc, b_texture = GetItemInfo(b_id)
	
	-- junk to the back?
	if core.db.junk then
		if a_rarity == 0 then return false end
		if b_rarity == 0 then return true end
	end
	-- Soul shards to the bank?
	if core.db.soul then
		if a_id == 6265 then return false end
		if b_id == 6265 then return true end
	end
	
	-- are they the same type?
	if item_types[a_type] == item_types[b_type] then
		if a_rarity == b_rarity then
			if a_type == L.ARMOR or a_type == L.WEAPON then
				-- "or -1" because some things are classified as armor/weapon without being equipable; note Everlasting Underspore Frond
				local a_equipLoc = inventory_slots[a_equipLoc] or -1
				local b_equipLoc = inventory_slots[b_equipLoc] or -1
				if a_equipLoc == b_equipLoc then
					-- sort by level, then name
					return prime_sort(a, b)
				else
					return a_equipLoc < b_equipLoc
				end
			else
				if a_subType == b_subType then
					if a_subType == L.TRADEGOODS then
						local a_tgo = get_trade_goods_order(a_id)
						local b_tgo = get_trade_goods_order(b_id)
						if a_tgo == b_tgo then
							return prime_sort(a, b)
						else
							return a_tgo < b_tgo
						end
					end
					return prime_sort(a, b)
				else
					return a_subType < b_subType
				end
			end
		else
			return a_rarity > b_rarity
		end
	else
		return item_types[a_type] < item_types[b_type]
	end
end

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
function core.Sort(bags, sorter)
	-- bags: table, e.g. {1,2,3,4}
	-- sorter: function or nil.  Passed to table.sort.
	-- TODO: quivers and profession bags need to be handled differently. (ContainerIDToInventoryID...)
	if core.running then
		core.announce(0, L.already_running, 1, 0, 0)
		return
	end
	if not sorter then sorter = default_sorter end
	
	for _,bag in ipairs(bags) do
		local slots = GetContainerNumSlots(bag)
		for slot=1, slots do
			local bagslot = encode_bagslot(bag, slot)
			if (not core.db.ignore[bagslot]) then
				table.insert(bag_sorted, bagslot)
			end
		end
	end
	
	table.sort(bag_sorted, sorter)
	--for i,s in ipairs(bag_sorted) do AceLibrary("AceConsole-2.0"):Print(i, GetContainerItemLink(decode_bagslot(s))) end -- handy debug list
	
	local another_pass_needed = true
	while another_pass_needed do
		another_pass_needed = false
		local i = 1
		for _, bag in ipairs(bags) do
			local slots = GetContainerNumSlots(bag)
			for slot=1, slots do
				-- Make sure the origin slot isn't empty; if so no move needs to be scheduled.
				local destination = encode_bagslot(bag, slot) -- This is like i, increasing as we go on.
				local source = bag_sorted[i]
				
				-- If destination is ignored we skip everything here
				-- Notably, i does not get incremented.
				if not core.db.ignore[destination] then
					-- A move is required, and the source isn't empty, and the item's stacks are not the same same size if it's the same item.
					if destination ~= source and bag_ids[source] and not ((bag_ids[source] == bag_ids[destination]) and (bag_stacks[source] == bag_stacks[destination])) then
						if not (bag_locked[source] or bag_locked[destination]) then
							-- If we've moved to the destination or source slots before in this run then we pass and request another run.
							core.AddMove(source, destination)
							update_sorted(source, destination)
							bag_locked[source] = true
							bag_locked[destination] = true
						else
							AceLibrary("AceConsole-2.0"):Print("Skipping", source, destination)
							another_pass_needed = true
						end
					end
					i = i + 1
				end
			end
		end
		clear(bag_locked)
	end
	clear(bag_sorted)
end

SlashCmdList["SORT"] = core.SortBags
SLASH_SORT1 = "/sort"
SLASH_SORT2 = "/sortbags"
