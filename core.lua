BankStack = {}
local core = BankStack

--Events:
local frame = CreateFrame("Frame")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:SetScript("OnEvent", function(this, event, ...)
    core[event](...)
end)

--Inner workings:
-- http://wowwiki.com/API_TYPE_bagID
local bank_bags = {BANK_CONTAINER}
for i = NUM_BAG_SLOTS+1, NUM_BAG_SLOTS+NUM_BANKBAGSLOTS do
	table.insert(bank_bags, i)
end
local player_bags = {}
for i = 0, NUM_BAG_SLOTS do
	table.insert(player_bags, i)
end

local bankitems = {--[[link = true--]]}
local banklinks = {--[[bag_int = link--]]}
local banksinks = {--[[bag_int = room_in_slot--]]}
local moves = {--[[bag_int(source):bag_int(target),. ..--]]}

local function bag_int(bag, slot) return (bag*1000) + slot end
local function int_bag(int) return math.floor(int/1000), int % 1000 end
local function link_to_id(link) return link and string.match(link, "item:(%d+)") end -- "item" because we only care about items, duh
local function clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
	t[true] = true
	t[true] = nil
	return t
end

local bank_open = false
function core:BANKFRAME_OPENED(...)
	bank_open = true
end
function core:BANKFRAME_CLOSED(...)
	bank_open = false
end
local t = 0
frame:SetScript("OnUpdate", function()
	if not bank_open then
		clear(moves)
		frame:Hide()
	end
	t = t + arg1
	if t > 0.3 then
		t = 0
		core.DoMoves()
	end
end)
frame:Hide() -- stops OnUpdate from running

function core.Stack()
	-- This function just creates a list of slots to move to other slots, and passes it off to a worker function to do the moving.
	if not bank_open then return end
	for _,bag in pairs(bank_bags) do
		local slots = GetContainerNumSlots(bag)
		for slot=1, slots do
			local link = link_to_id(GetContainerItemLink(bag, slot))
			if link then
				local stack_size = select(8, GetItemInfo(link))
				local count = select(2, GetContainerItemInfo(bag, slot))
				-- If this stack is full, or there's nothing in the player bags we can put into it we don't care about it
				if (GetItemCount(link) > 0) and (count ~= stack_size) then
					local id = bag_int(bag, slot)
					bankitems[link] = GetItemCount(link, true) - GetItemCount(link) --full count of all this item in bank
					banklinks[id] = link
					banksinks[id] = stack_size - count
				end
			end
		end
	end
	-- Now go through the player's bags...
	for _,bag in pairs(player_bags) do
		local slots = GetContainerNumSlots(bag)
		for slot=1, slots do
			local link = link_to_id(GetContainerItemLink(bag, slot))
			if link and bankitems[link] then
				--there's an item in this slot *and* we have room for more of it in the bank somewhere
				local count = select(2, GetContainerItemInfo(bag, slot))
				for bankslot, banklink in pairs(banklinks) do
					if banklink==link then
						-- Schedule moving from this slot to the bank slot.
						table.insert(moves, bag_int(bag, slot) .. ":" .. bankslot)
						-- Deal with the bank slot:
						local room = banksinks[bankslot]
						if room > count then
							-- This bag slot is emptied, and there's still room in the bank slot for more
							banksinks[bankslot] = room - count
							bankitems[link] = bankitems[link] - count
						else
							-- The bank slot will be filled; remove it from future consideration
							bankitems[link] = (bankitems[link] > room) and (bankitems[link] - room) or nil
							banksinks[bankslot] = nil
							banklinks[bankslot] = nil
							if room == count then
								-- This bag slot is emptied; stop searching the bank
								break
							else
								count = count - room
							end
						end
					end
				end
			end
		end
	end
	-- clean up the various cache tables
	clear(bankitems)
	clear(banklinks)
	clear(banksinks)
	--unhide the frame to get the moving started in OnUpdates
	frame:Show()
end
--function core:Compress(bags)
--end

local current_link
local current_target
function core.DoMoves()
	if CursorHasItem() then
		local _, _, itemlink = GetCursorInfo()
		local itemlink = link_to_id(itemlink)
		if (not current_target) or (current_link ~= itemlink) then
			-- We didn't pick up whatever is on the cursor; things could get really screwed up if we carry on.  Abort!
			clear(moves)
			frame:Hide()
			return
		end
		-- Drop the item into the target slot
		return PickupContainerItem(int_bag(current_target))
	end
	current_link = nil
	current_target = nil
	
	if #moves > 0 then
		local source, target = string.match(table.remove(moves), "^(.+):(.+)$")
		local source_bag, source_slot = int_bag(source)
		--local target_bag, target_slot = int_bag(source)
		local link = link_to_id(GetContainerItemLink(source_bag, source_slot))
		local source_count = select(2, GetContainerItemInfo(source_bag, source_slot))
		local target_count = select(2, GetContainerItemInfo(int_bag(target)))
		local stack_size = select(8, GetItemInfo(link))
		
		current_link = link
		current_target = target
		if (target_count + source_count) > stack_size then
			return SplitContainerItem(source_bag, source_slot, stack_size - target_count)
		else
			return PickupContainerItem(source_bag, source_slot)
		end
	end
	frame:Hide()
end

--Slashcommands:
SlashCmdList["BANKSTACK"] = core.Stack
SLASH_BANKSTACK1 = "/bankstack"
