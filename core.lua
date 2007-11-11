assert(BankStackLocale, "BankStack is not yet localized for "..GetLocale())

BankStack = {}
local core = BankStack
local L = BankStackLocale
core.L = L

--Events:
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:SetScript("OnEvent", function(this, event, ...)
    core[event](...)
end)
local t = 0
frame:SetScript("OnUpdate", function()
	if core.bankrequired and not core.bank_open then
		core.StopStacking(L.at_bank)
	end
	t = t + arg1
	if t > 0.1 then
		t = 0
		core.DoMoves()
	end
end)
frame:Hide() -- stops OnUpdate from running

core.frame = frame

--Inner workings:
function core.announce(level, message, r, g, b)
	if level > core.db.verbosity then return end
	DEFAULT_CHAT_FRAME:AddMessage(message, r, g, b)
end

-- http://wowwiki.com/API_TYPE_bagID
local bank_bags = {BANK_CONTAINER}
for i = NUM_BAG_SLOTS+1, NUM_BAG_SLOTS+NUM_BANKBAGSLOTS do
	table.insert(bank_bags, i)
end
core.bank_bags = bank_bags
local player_bags = {}
for i = 0, NUM_BAG_SLOTS do
	table.insert(player_bags, i)
end
core.player_bags = player_bags
local all_bags = {BANK_CONTAINER}
for i = 0, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
	table.insert(all_bags, i)
end
core.all_bags = all_bags

local function is_valid_bag(bagid)
	return (bagid == BANK_CONTAINER or ((bagid >= 0) and bagid <= NUM_BAG_SLOTS+NUM_BANKBAGSLOTS))
end
core.is_valid_bag = is_valid_bag
local function is_bank_bag(bagid)
	return (bagid == BANK_CONTAINER or (bagid > NUM_BAG_SLOTS and bagid <= NUM_BANKBAGSLOTS))
end
core.is_bank_bag = is_bank_bag

local core_groups = {
	bank = bank_bags,
	bags = player_bags,
	all = all_bags,
}
core.groups = core_groups
function core.get_group(id)
	return core_groups[id] or core.db.groups[id]
end
function core.contains_bank_bag(group)
	for _,bag in ipairs(group) do
		if is_bank_bag(bag) then return true end
	end
end

local function encode_bagslot(bag, slot) return (bag*100) + slot end
local function decode_bagslot(int) return math.floor(int/100), int % 100 end
local function encode_move(source, target) return (source*10000)+target end
local function decode_move(move)
	local s = math.floor(move/10000)
	local t = move%10000
	s = (t>9000) and (s+1) or s
	t = (t>9000) and (t-10000) or t
	return s, t
end
local function link_to_id(link) return link and tonumber(string.match(link, "item:(%d+)")) end -- "item" because we only care about items, duh
local function clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
	t[true] = true
	t[true] = nil
	return t
end
core.encode_bagslot = encode_bagslot
core.decode_bagslot = decode_bagslot
core.encode_move = encode_move
core.decode_move = decode_move
core.link_to_id = link_to_id
core.clear = clear

function core.PLAYER_ENTERING_WORLD()
	local defaults = {
		verbosity=1,
		junk=true,
		soul=true,
		ignore={},
		groups={},
	}
	if not BankStackDB then
		BankStackDB = {}
	end
	for k,v in pairs(defaults) do
		if not BankStackDB[k] then
			BankStackDB[k] = v
		end
	end
	
	core.db = BankStackDB
	frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
end
function core.BANKFRAME_OPENED()
	core.bank_open = true
end
function core.BANKFRAME_CLOSED()
	core.bank_open = false
end

local current_id
local current_target

local moves = {--[[encode_move(encode_bagslot(),encode_bagslot(target)),. ..--]]}
core.moves = moves

local bag_ids = {}
local bag_stacks = {}
local bag_maxstacks = {}
core.bag_ids, core.bag_stacks, core.bag_maxstacks = bag_ids, bag_stacks, bag_maxstacks
local function update_location(from, to)
	-- When I move something from (3,12) to (0,1), the contents of (0,1) are now in (3,12).
	-- Therefore if I find later that I need to move something from (0,1), I actually need to move whatever wound up in (3,12).
	-- This function updates the various cache tables to reflect current locations.
	if (bag_ids[from] == bag_ids[to]) and (bag_stacks[to] < bag_maxstacks[to]) then
		-- If they're the same type we might have to deal with stacking.
		local stack_size = bag_maxstacks[to]
		if (bag_stacks[to] + bag_stacks[from]) > stack_size then
			bag_stacks[from] = bag_stacks[from] - (stack_size - bag_stacks[to])
			bag_stacks[to] = stack_size
		else
			bag_stacks[to] = bag_stacks[to] + bag_stacks[from]
			bag_stacks[from] = nil
			bag_ids[from] = nil
			bag_maxstacks[from] = nil
		end
	else
		bag_ids[from], bag_ids[to] = bag_ids[to], bag_ids[from]
		bag_stacks[from], bag_stacks[to] = bag_stacks[to], bag_stacks[from]
		bag_maxstacks[from], bag_maxstacks[to] = bag_maxstacks[to], bag_maxstacks[from]
	end
end
function core.ScanBags()
	for _, bag in pairs(all_bags) do
		local slots = GetContainerNumSlots(bag)
		for slot=1, slots do
			local bagslot = encode_bagslot(bag, slot)
			local itemid = link_to_id(GetContainerItemLink(bag, slot))
			if itemid then
				bag_ids[bagslot] = itemid
				bag_stacks[bagslot] = select(2, GetContainerItemInfo(bag, slot))
				bag_maxstacks[bagslot] = select(8, GetItemInfo(itemid))
			end
		end
	end
end
function core.AddMove(source, destination)
	update_location(source, destination)
	table.insert(moves, 1, encode_move(source, destination))
end

function core.DoMoves()
	if CursorHasItem() then
		local itemid = link_to_id(select(3, GetCursorInfo()))
		if current_id ~= itemid then
			-- We didn't pick up whatever is on the cursor; things could get really screwed up if we carry on.  Abort!
			return core.StopStacking(L.confused)
		end
	end
	
	if current_target and (link_to_id(GetContainerItemLink(decode_bagslot(current_target))) ~= current_id) then
		return --give processing time to happen
	end
	
	current_id = nil
	current_target = nil
	
	if #moves > 0 then for i=#moves, 1, -1 do
		if CursorHasItem() then return end
		local source, target = decode_move(moves[i])
		local source_bag, source_slot = decode_bagslot(source)
		local target_bag, target_slot = decode_bagslot(target)
		local _, source_count, source_locked = GetContainerItemInfo(source_bag, source_slot)
		local _, target_count, target_locked = GetContainerItemInfo(target_bag, target_slot)
		
		if source_locked or target_locked then return end
		
		table.remove(moves, i)
		local source_link = GetContainerItemLink(source_bag, source_slot)
		local source_itemid = link_to_id(source_link)
		local target_itemid = link_to_id(GetContainerItemLink(target_bag, target_slot))
		if not source_itemid then return end
		local stack_size = select(8, GetItemInfo(source_itemid))
		
		core.announce(2, string.format(L.moving, source_link), 1,1,1)
		
		current_target = target
		current_id = source_itemid
		if (source_itemid == target_itemid) and (target_count ~= stack_size) and ((target_count + source_count) > stack_size) then
			SplitContainerItem(source_bag, source_slot, stack_size - target_count)
		else
			PickupContainerItem(source_bag, source_slot)
		end
		if CursorHasItem() then
			PickupContainerItem(target_bag, target_slot)
		end
	end end
	core.announce(1, L.complete, 1, 1, 1)
	core.StopStacking()
end

function core.StartStacking()
	clear(bag_maxstacks)
	clear(bag_stacks)
	clear(bag_ids)
	
	if #moves > 0 then
		core.running = true
		core.announce(1, string.format(L.to_move, #moves), 1, 1, 1)
		frame:Show()
	else
		core.announce(1, L.perfect, 1, 1, 1)
	end
end

function core.StopStacking(message)
	core.running = false
	core.bankrequired = false
	current_id = nil
	current_target = nil
	clear(moves)
	frame:Hide()
	if message then
		core.announce(1, message, 1, 0, 0)
	end
end

do
	local safe = {
		[BANK_CONTAINER]=true,
		[0]=true,
	}
	function core.IsSpecialtyBag(bagid)
		if safe[bagid] then return false end
		local invslot = ContainerIDToInventoryID(bagid)
		if not invslot then return false end
		local bag = GetInventoryItemLink("player", invslot)
		if not bag then return false end
		local item_type, item_subtype = select(6, GetItemInfo(bag))
		if item_type == L.CONTAINER and item_subtype == L.BAG then
			return false
		end
		return item_subtype
	end
end
