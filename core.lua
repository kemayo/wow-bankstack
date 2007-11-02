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
local function link_to_id(link) return link and string.match(link, "item:(%d+)") end -- "item" because we only care about items, duh
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
	if not BankStackDB then
		BankStackDB = {
			verbosity=1,
		}
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
	if #moves > 0 then
		core.announce(1, string.format(L.to_move, #moves), 1, 1, 1)
		frame:Show()
	else
		core.announce(1, L.perfect, 1, 1, 1)
	end
end

function core.StopStacking(message)
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
		return not (item_type == L.CONTAINER or item_subtype == L.BAG)
	end
end

--Bindings:
BINDING_HEADER_BANKSTACK = "BankStack"
BINDING_NAME_BANKSTACK = "Stack to bank"
BINDING_NAME_COMPRESS = "Compress bags"
BINDING_NAME_BAGSORT = "Sorts bags"

