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

local target_items = {--[[link = available_slots--]]}
local target_links = {--[[bag_int = link--]]}
local target_sinks = {--[[bag_int = room_in_slot--]]}
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

function core:BANKFRAME_OPENED(...)
	core.bank_open = true
end
function core:BANKFRAME_CLOSED(...)
	core.bank_open = false
end
local t = 0
frame:SetScript("OnUpdate", function()
	if core.bankrequired and not core.bank_open then
		core.StopStacking("BankStack: The bank is required.")
	end
	t = t + arg1
	if t > 0.3 then
		t = 0
		core.DoMoves()
	end
end)
frame:Hide() -- stops OnUpdate from running

local current_link
local current_target
function core.BankStack(arg)
	if arg=="help" then
		return core.PrintHelp()
	end
	if not core.bank_open then
		DEFAULT_CHAT_FRAME:AddMessage("BankStack: You must be at the bank.", 1, 0, 0)
		return
	end
	core.bankrequired = true
	core.Stack(arg=="reverse" and bank_bags or player_bags, arg=="reverse" and player_bags or bank_bags)
end
function core.Compress(arg)
	if arg=="help" then
		return core.PrintHelp()
	end
	local bags
	if arg=="bank" then
		if not core.bank_open then
			DEFAULT_CHAT_FRAME:AddMessage("BankStack: You must be at the bank to compress your bank bags.", 1, 0, 0)
			return
		else
			bags = bank_bags
			core.bankrequired = true
		end
	else
		bags = player_bags
	end
	core.Stack(bags, bags)
end
function core.PrintHelp()
	DEFAULT_CHAT_FRAME:AddMessage("BankStack: Stacks things.", 1, 1, 1)
	DEFAULT_CHAT_FRAME:AddMessage("/bankstack -- fills stacks in your bank from your bags", 1, 1, 1)
	DEFAULT_CHAT_FRAME:AddMessage("/bankstack reverse -- fills stacks in your bags from your bank", 1, 1, 1)
	DEFAULT_CHAT_FRAME:AddMessage("/compress -- merges stacks in your bags", 1, 1, 1)
	DEFAULT_CHAT_FRAME:AddMessage("/compress bank -- merges stacks in your bank", 1, 1, 1)
end

function core.Stack(source_bags, target_bags)
	-- Fill incomplete stacks in target_bags with items from source_bags
	-- This function just creates a list of slots to move to other slots, and passes it off to a worker function to do the moving.
	if current_link or current_target then
		DEFAULT_CHAT_FRAME:AddMessage("BankStack: A stacker is already running.", 1, 0, 0)
		return
	end
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
					local id = bag_int(bag, slot)
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
			if link and target_items[link] then
				--there's an item in this slot *and* we have room for more of it in the bank somewhere
				local source_slot = bag_int(bag, slot)
				local count = select(2, GetContainerItemInfo(bag, slot))
				for target_slot, target_link in pairs(target_links) do
					if not target_items[link] then break end
					if target_link == link and target_slot ~= source_slot then -- (can't stack to itself)
						-- Schedule moving from this slot to the bank slot.
						table.insert(moves, source_slot .. ":" .. target_slot)
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
	if #moves > 0 then
		--unhide the frame to get the moving started in OnUpdates
		frame:Show()
		DEFAULT_CHAT_FRAME:AddMessage(string.format("BankStack: %d to stack.", #moves), 1, 1, 1)
	else
		DEFAULT_CHAT_FRAME:AddMessage("BankStack: Nothing to stack.", 1, 1, 1)
	end
end
function core.DoMoves()
	if CursorHasItem() then
		local _, _, itemlink = GetCursorInfo()
		local itemlink = link_to_id(itemlink)
		if (not current_target) or (current_link ~= itemlink) then
			-- We didn't pick up whatever is on the cursor; things could get really screwed up if we carry on.  Abort!
			return core.StopStacking("BankStack: Confusion. Stopping.")
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
	DEFAULT_CHAT_FRAME:AddMessage("BankStack: Complete.", 1, 1, 1)
	core.StopStacking()
end

function core.StopStacking(message)
	core.bankrequired = false
	current_target = nil
	current_link = nil
	clear(moves)
	frame:Hide()
	if message then
		DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0, 0)
	end
end

--Slashcommands:
SlashCmdList["BANKSTACK"] = core.BankStack
SLASH_BANKSTACK1 = "/bankstack"
SlashCmdList["COMPRESSBAGS"] = core.Compress
SLASH_COMPRESSBAGS1 = "/compress"
SLASH_COMPRESSBAGS2 = "/compressbags"

--Bindings:
BINDING_HEADER_BANKSTACK = "BankStack"
BINDING_NAME_BANKSTACK = "Stack to bank"
BINDING_NAME_COMPRESS = "Compress bags"
