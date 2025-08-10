BankStack = LibStub("AceAddon-3.0"):NewAddon("BankStack", "AceEvent-3.0")
local core = BankStack
local L = LibStub("AceLocale-3.0"):GetLocale("BankStack")
core.L = L
core.events = LibStub("CallbackHandler-1.0"):New(core)

local BTSI = LibStub("LibBankTabSuitableItems-1.0", true)

local debugf = tekDebug and tekDebug:GetFrame("BankStack")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end
core.Debug = Debug

core.CLASSIC = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE -- rolls forward
core.CLASSICERA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC -- forever vanilla

core.has_new_bank = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_Bank and Enum.BagIndex.Characterbanktab

-- If pre-guild-bank BC servers ever show up again this will need to be fixed:
core.has_guild_bank = QueryGuildBankTab and LE_EXPANSION_LEVEL_CURRENT > LE_EXPANSION_BURNING_CRUSADE

-- TODO: if this ever gets backported to classic for some reason...
core.has_account_bank = LE_EXPANSION_LEVEL_CURRENT >= LE_EXPANSION_WAR_WITHIN

core.has_reagent_bag = (Constants.InventoryConstants.NumReagentBagSlots or 0) > 0
core.has_reagent_bank = not core.has_new_bank and _G.ReagentBankButtonIDToInvSlotID -- TODO: this is mostly in case Warlords Classic brings this back...

-- compat:
local GetContainerItemInfo = _G.GetContainerItemInfo or function(...)
	local info = C_Container.GetContainerItemInfo(...)
	if info then
		return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.isReadable, info.hasLoot, info.hyperlink, info.isFiltered, info.hasNoValue, info.itemID, info.isBound
	end
end

--Bindings locales:
BINDING_HEADER_BANKSTACK_HEAD = L['BINDING_HEADER_BANKSTACK_HEAD']
BINDING_NAME_BANKSTACK = L['BINDING_NAME_BANKSTACK']
BINDING_NAME_COMPRESS = L['BINDING_NAME_COMPRESS']
BINDING_NAME_BAGSORT = L['BINDING_NAME_BAGSORT']

function core:OnInitialize()
	self.db_object = LibStub("AceDB-3.0"):New("BankStackDB", {
		profile = {
			verbosity = 1,
			junk = 2, -- 0: no special treatment, 1: end of sort, 2: back of bags
			conjured = false,
			soulbound = true,
			reverse = false,
			backfill = false,
			ignore = {},
			ignore_bags = {},
			ignore_blizzard = true,
			groups = {},
			fubar_keybinds={
				['BUTTON1'] = 'sortbags',
				['ALT-BUTTON1'] = 'sortbank',
				['CTRL-BUTTON1'] = 'compressbags',
				['ALT-CTRL-BUTTON1'] = 'compressbank',
				['SHIFT-BUTTON1'] = 'stackbank',
				['ALT-SHIFT-BUTTON1'] = 'stackbags',
				['CTRL-SHIFT-BUTTON1'] = false,
				['ALT-CTRL-SHIFT-BUTTON1'] = false,
			},
			conservative_guild = true,
			stutter_duration = 0.05,
			stutter_delay = 0,
			processing_delay = 0.1,
			processing_delay_guild = 0.4,
		},
	}, "Default")
	self.db = self.db_object.profile
	self.db_object.RegisterCallback(self, "OnProfileChanged", function()
		self.db = self.db_object.profile
	end)

	if type(self.db.junk) == "boolean" then
		self.db.junk = self.db.junk and 1 or 0
	end

	if self.setup_config then
		self.setup_config()
	end

	function core.PLAYER_INTERACTION_MANAGER_FRAME_SHOW(_, event, id)
		if id == Enum.PlayerInteractionType.Banker then
			self.bank_open = true
			self.account_bank_open = false
			self.events:Fire("Bank_Open")
		elseif id == Enum.PlayerInteractionType.AccountBanker then
			self.account_bank_open = true
			self.events:Fire("AccountBank_Open")
		elseif id == Enum.PlayerInteractionType.GuildBanker then
			self.guild_bank_open = true
			self.events:Fire("GuildBank_Open")
		end
	end
	function core.PLAYER_INTERACTION_MANAGER_FRAME_HIDE(_, event, id)
		if id == Enum.PlayerInteractionType.Banker then
			self.bank_open = false
			self.events:Fire("Bank_Close")
		elseif id == Enum.PlayerInteractionType.AccountBanker then
			self.account_bank_open = false
			self.events:Fire("AccountBank_Close")
		elseif id == Enum.PlayerInteractionType.GuildBanker then
			self.guild_bank_open = false
			self.events:Fire("GuildBank_Close")
		end
	end
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
end

local hooks = {}
function core:RegisterAddonHook(addon, callback)
    if C_AddOns.IsAddOnLoaded(addon) then
        callback()
    else
        hooks[addon] = callback
    end
end

local frame = CreateFrame("Frame")
local t, WAIT_TIME, MAX_MOVE_TIME = 0, 0.05, 3
frame:SetScript("OnUpdate", function(self, time_since_last)
	if (core.bankrequired and not core.bank_open) or (core.guildbankrequired and not core.guild_bank_open) then
		Debug(core.bankrequired and "bank required" or "guild bank required")
		core.StopStacking(L.at_bank)
	end
	t = t + (time_since_last or 0.01)
	if t > WAIT_TIME then
		t = 0
		core.DoMoves()
	end
end)
frame:Hide() -- stops OnUpdate from running

core.frame = frame

--Inner workings:

--Set up groups:
-- https://warcraft.wiki.gg/wiki/BagID

local bank_bags = core.has_new_bank and {} or {BANK_CONTAINER}
do
	local NUM_BANKBAGSLOTS = core.has_new_bank and Constants.InventoryConstants.NumCharacterBankSlots or _G.NUM_BANKBAGSLOTS
	for i = (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + 1), (ITEM_INVENTORY_BANK_BAG_OFFSET + NUM_BANKBAGSLOTS) do
		table.insert(bank_bags, i)
	end
end
core.bank_bags = bank_bags

local player_bags = {}
if core.has_reagent_bag then
	table.insert(player_bags, Enum.BagIndex.ReagentBag)
end
for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
	table.insert(player_bags, i)
end
core.player_bags = player_bags

local account_bags = {}
if core.has_account_bank then
	-- Accountbanktab itself is a weird 5-slot container that only contains 5x item:208392 "Bank Tab Bag (DNT)"
	account_bags = {Enum.BagIndex.AccountBankTab_1, Enum.BagIndex.AccountBankTab_2, Enum.BagIndex.AccountBankTab_3, Enum.BagIndex.AccountBankTab_4, Enum.BagIndex.AccountBankTab_5}
end
core.account_bags = account_bags

local all_bags = {}
tAppendAll(all_bags, player_bags)
tAppendAll(all_bags, bank_bags)
tAppendAll(all_bags, account_bags)
core.all_bags = all_bags

local guild = {51,52,53,54,55,56,57,58}
core.guild = guild

local all_bags_with_guild = {}
tAppendAll(all_bags_with_guild, all_bags)
tAppendAll(all_bags_with_guild, guild)
core.all_bags_with_guild = all_bags_with_guild


local function is_valid_bag(bagid)
	return tContains(all_bags_with_guild, bagid)
end
core.is_valid_bag = is_valid_bag
local function is_account_bag(bagid)
	return tContains(account_bags, bagid)
end
core.is_account_bag = is_account_bag
local function is_bank_bag(bagid)
	return tContains(bank_bags, bagid) or is_account_bag(bagid)
end
core.is_bank_bag = is_bank_bag
local function is_guild_bank_bag(bagid)
	-- Note that this is an artificial slot id, which we're using internally to trigger usage of guild bank functions.
	-- Guild bank slots are: 51, 52, 53, 54, 55, 56, 57, 58.
	-- I couldn't find a constant for the maximum number of guild bank tabs; it's currently 8.
	return (bagid > 50 and bagid <= 58)
end
core.is_guild_bank_bag = is_guild_bank_bag

local core_groups = {
	bank = bank_bags,
	bags = player_bags,
	all = all_bags,
	guild = guild,
	guild1 = {51,},
	guild2 = {52,},
	guild3 = {53,},
	guild4 = {54,},
	guild5 = {55,},
	guild6 = {56,},
	guild7 = {57,},
	guild8 = {58,},
}
if core.has_reagent_bag then
	core_groups.bags_without_reagents = {select(2, unpack(player_bags))}
end
if core.has_reagent_bank then
	core_groups.reagents = {REAGENTBANK_CONTAINER}
	core_groups.bank_without_reagents = {select(2, unpack(bank_bags))}
end
if core.has_account_bank then
	core_groups.account = account_bags
end
core.groups = core_groups
function core.get_group(id)
	Debug ("get_group", id)
	if id == "bank" and core.guild_bank_open then
		local tab = GetCurrentGuildBankTab()
		if tab then
			return core_groups["guild" .. tab]
		end
	end
	if id == "bank" and AccountBankPanel and AccountBankPanel:IsVisible() then
		local tab = AccountBankPanel:GetSelectedTabID()
		if tab and core.is_account_bag(tab) then
			return {tab}
		end
	end
	if not core.db.groups[id] and string.match(id, "^[-%d,]+$") then
		Debug("Looks like a bag list", id)
		local bags = {}
		for b in string.gmatch(id, "-?%d+") do
			table.insert(bags, tonumber(b))
		end
		Debug("Parsed out", #bags)
		return bags
	end
	return core_groups[id] or core.db.groups[id]
end
function core.contains_bank_bag(group)
	for _,bag in ipairs(group) do
		if is_bank_bag(bag) then return true end
	end
end
function core.contains_guild_bank_bag(group)
	for _,bag in ipairs(group) do
		if is_guild_bank_bag(bag) then return true end
	end
end

function core.check_for_banks(bags)
	--Check {bags} to see if any of them are in the bank / guild bank.  Print a warning if they are.
	if core.contains_bank_bag(bags) then
		if not core.bank_open then
			core.announce(0, L.at_bank, 1, 0, 0)
			return true
		end
		-- TODO: cope with being at a summoned AccountBanker here:
		core.bankrequired = true
	end
	if core.contains_guild_bank_bag(bags) then
		if not core.guild_bank_open then
			core.announce(0, L.at_bank, 1, 0, 0)
			return true
		end
		core.guildbankrequired = true
	end
end

do
	local tooltip
	function core.CheckTooltipFor(bag, slot, text)
		if _G.C_TooltipInfo then
			-- retail
			local info
			if slot and not bag then
				if type(slot) == "string" then
					info = C_TooltipInfo.GetHyperlink(slot)
				else
					info = C_TooltipInfo.GetItemByID(slot)
				end
			elseif is_guild_bank_bag(bag) then
				info = C_TooltipInfo.GetGuildBankItem(bag - 50, slot)
			else
				if bag == BANK_CONTAINER then
					info = C_TooltipInfo.GetInventoryItem("player", BankButtonIDToInvSlotID(slot, nil))
				elseif core.has_reagent_bank and bag == REAGENTBANK_CONTAINER then
					info = C_TooltipInfo.GetInventoryItem("player", ReagentBankButtonIDToInvSlotID(slot))
				else
					info = C_TooltipInfo.GetBagItem(bag, slot)
				end
			end
			if not info then return false end -- got reports of this, but haven't been able to reproduce it
			for _, line in ipairs(info.lines) do
				if line.leftText and string.match(line.leftText, text) then
					return true
				end
			end
			return false
		else
			if not tooltip then
				tooltip = CreateFrame("GameTooltip", "BankStackTooltip", nil, "GameTooltipTemplate")
				tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
			end
			tooltip:ClearLines()
			if slot and not bag then
				-- just showing tooltip for an itemid
				-- uses rather innocent checking so that slot can be a link or an itemid
				local link = tostring(slot) -- so that ":match" is guaranteed to be okay
				if not link:match("item:") then
					link = "item:"..link
				end
				tooltip:SetHyperlink(link)
			elseif is_guild_bank_bag(bag) then
				tooltip:SetGuildBankItem(bag-50, slot)
			else
				-- This is just ridiculous... since 3.3, SetBagItem doesn't work in the base
				-- bank slot or the keyring since they're not real bags.
				if bag == BANK_CONTAINER then
					tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot, nil))
				elseif core.has_reagent_bank and bag == REAGENTBANK_CONTAINER then
					tooltip:SetInventoryItem("player", ReagentBankButtonIDToInvSlotID(slot))
				else
					tooltip:SetBagItem(bag, slot)
				end
			end
			for i=2, tooltip:NumLines() do
				local left = _G["BankStackTooltipTextLeft"..i]
				--local right = _G["BankStackTooltipTextRight"..i]
				if left and left:IsShown() and string.match(left:GetText(), text) then return true end
				--if right and right:IsShown() and string.match(right:GetText(), text) then return true end
			end
			return false
		end
	end
end

local function encode_bagslot(bag, slot) return (bag*100) + slot end
local function decode_bagslot(int) return math.floor(int/100), int % 100 end
local function encode_move(source, target) return (source*10000)+target end
local function decode_move(move)
	local source = math.floor(move/10000)
	local target = move%10000
	source = (target>9000) and (source+1) or source
	target = (target>9000) and (target-10000) or target
	return source, target
end
core.encode_bagslot = encode_bagslot
core.decode_bagslot = decode_bagslot
core.encode_move = encode_move
core.decode_move = decode_move

do
	local bagiter_forwards, bagiter_backwards
	function bagiter_forwards(baglist, role)
		local step = 1
		for _, bag in ipairs(baglist) do
			for slot=1, core.GetNumSlots(bag, role) do
				coroutine.yield(step, bag, slot)
				step = step + 1
			end
		end
	end
	function bagiter_backwards(baglist, role)
		local step = 1
		for i=#baglist, 1, -1 do
			local bag = baglist[i]
			for slot=core.GetNumSlots(bag, role), 1, -1 do
				coroutine.yield(step, bag, slot)
				step = step + 1
			end
		end
	end

	-- Iterate over bags and slots
	-- e.g. for _, bag, slot in core.IterateBags({1,2,3}) do ... end
	function core.IterateBags(baglist, reverse, role)
		return coroutine.wrap(function()
			return (reverse and bagiter_backwards or bagiter_forwards)(baglist, role)
		end)
	end
end

local already_queried = {}
local function QueryGuildBankTabIfNeeded(tab)
	if not already_queried[tab] then
		QueryGuildBankTab(tab)
		already_queried[tab] = true
	end
end

-- Wrapper functions to allow for pretending that the guild bank and bags are the same.
function core.GetNumSlots(bag, role)
	-- role: "withdraw", "deposit", "both"; defaults to "both", as that is the most restrictive
	-- (Whether you intend to put things into or take things out of this bag.  Only affects guild bank slots.)
	-- The main complication here is the guild bank.
	if is_guild_bank_bag(bag) then
		if not role then role = "deposit" end
		local tab = bag - 50
		QueryGuildBankTabIfNeeded(tab)
		local name, icon, canView, canDeposit, numWithdrawals = GetGuildBankTabInfo(tab)
		--(numWithdrawals is negative if you have unlimited withdrawals available.)
		if name and canView and ((role == "withdraw" and numWithdrawals ~= 0) or (role == "deposit" and canDeposit) or (role == "both" and numWithdrawals ~= 0 and canDeposit)) then
			return 98 -- MAX_GUILDBANK_SLOTS_PER_TAB (some bag addons stop Blizzard_GuildBankUI from loading, making the constant unavailable)
		end
	else
		return C_Container.GetContainerNumSlots(bag)
	end
	return 0
end

function core.GetItemInfo(bag, slot)
	if is_guild_bank_bag(bag) then
		local tab = bag - 50
		QueryGuildBankTabIfNeeded(tab)
		return GetGuildBankItemInfo(tab, slot)
	else
		return GetContainerItemInfo(bag, slot)
	end
end

function core.GetItemLink(bag, slot)
	if is_guild_bank_bag(bag) then
		local tab = bag - 50
		QueryGuildBankTabIfNeeded(tab)
		return GetGuildBankItemLink(tab, slot)
	else
		return C_Container.GetContainerItemLink(bag, slot)
	end
end

function core.GetItemID(bag, slot)
	if is_guild_bank_bag(bag) then
		local link = core.GetItemLink(bag, slot)
		return link and tonumber(string.match(link, "item:(%d+)"))
	else
		return C_Container.GetContainerItemID(bag, slot)
	end
end

function core.PickupItem(bag, slot)
	if is_guild_bank_bag(bag) then
		local tab = bag - 50
		return PickupGuildBankItem(tab, slot)
	else
		return C_Container.PickupContainerItem(bag, slot)
	end
end

function core.SplitItem(bag, slot, amount)
	if is_guild_bank_bag(bag) then
		local tab = bag - 50
		return SplitGuildBankItem(tab, slot, amount)
	else
		return C_Container.SplitContainerItem(bag, slot, amount)
	end
end

do
	local known = {
		[BACKPACK_CONTAINER] = false,
	}
	if core.has_reagent_bag then
		known[Enum.BagIndex.ReagentBag] = true
	end
	if core.has_reagent_bank then
		known[REAGENTBANK_CONTAINER] = true
	end
	if not core.has_new_bank then
		known[BANK_CONTAINER] = false
	end
	local always = {}
	function core.IsSpecialtyBag(bagid)
		if known[bagid] ~= nil then return known[bagid] end
		if is_guild_bank_bag(bagid) then return false end
		if core.has_new_bank and is_bank_bag(bagid) then
			if BTSI and core.db.ignore_blizzard then
				local key, numFlags = BTSI:BuildKeyForTab(bagid)
				if numFlags == 0 then
					return "Normal"
				end
				return key
			end
			return false
		end
		local invslot = C_Container.ContainerIDToInventoryID(bagid)
		if not invslot then return false end
		local bag = GetInventoryItemLink("player", invslot)
		if not bag then return false end
		local family = GetItemFamily(bag)
		if family == 0 then return false end
		return family
	end
end

function core.CanItemGoInBag(bag, slot, target_bag)
	local bagslot = encode_bagslot(bag, slot)
	local item = core.bag_ids[bagslot]

	if is_guild_bank_bag(target_bag) then
		-- TODO: respect restrictions on the account tabs set in the blizzard UI
		-- Almost anything can go in a guild bank or the account bank... apart from:
		if
			core.bag_soulbound[bagslot]
			or core.bag_conjured[bagslot]
			or select(14, GetItemInfo(item)) == LE_ITEM_BIND_QUEST
		then
			return false
		end
		return true
	end
	if core.has_new_bank and BTSI and is_bank_bag(target_bag) then
		if core.db.ignore_blizzard and BTSI then
			return BTSI:IsItemLocationSuitableForTab(core.bag_itemlocation[bagslot], target_bag)
		end
		-- This is filtering out the actually-impossible, not just preference-based:
		local bankType = BTSI:GetBankTypeForTab(target_bag)
		return bankType and C_Bank.CanViewBank(bankType) and C_Bank.IsItemAllowedInBankType(bankType, core.bag_itemlocation[bagslot])
	end
	-- This is either a pre-11.2.0 bank-bag or a player-bag
	-- since we now know this isn't a guild bank we can just use the bag id provided
	local item_family = GetItemFamily(item)
	if not item_family then
		Debug("Item without family", item, bag, slot)
		return false
	end
	if item_family > 0 then
		-- if the item is a profession bag, this will actually be the bag_family, and it should be zero
		if select(4, GetItemInfoInstant(item)) == "INVTYPE_BAG" then
			item_family = 0
		end
	end
	if core.has_reagent_bank and target_bag == REAGENTBANK_CONTAINER then
		if not IsReagentBankUnlocked() then
			return false
		end
		-- 7.1.5 finally added an "is crafting reagent" return
		return select(17, GetItemInfo(item))
	end
	if core.has_reagent_bag and target_bag == Enum.BagIndex.ReagentBag then
		return select(17, GetItemInfo(item))
	end

	local bag_family = select(2, C_Container.GetContainerNumFreeSlots(target_bag))
	return bag_family == 0 or bit.band(item_family, bag_family) > 0
end

function core.IsIgnored(bag, slot)
	if core.db.ignore_bags[bag] then
		return true
	end
	if core.db.ignore[encode_bagslot(bag, slot)] then
		return true
	end
	if core.db.ignore_blizzard then
		if (bag == -1) then --bank
			return GetBankAutosortDisabled and GetBankAutosortDisabled() or false
		elseif (bag == 0) then --backpack
			return GetBackpackAutosortDisabled and GetBackpackAutosortDisabled() or false
		elseif (bag == -3) then --reagentbank
			return false
		elseif is_bank_bag(bag) then
			if core.has_new_bank and BTSI then
				local data = BTSI:GetTabData(bag)
				return data and data.depositFlags and FlagsUtil.IsSet(data.depositFlags, Enum.BagSlotFlags.DisableAutoSort)
			end
			return C_Container.GetBagSlotFlag(bag, Enum.BagSlotFlags.DisableAutoSort)
		elseif not is_guild_bank_bag(bag) then
			return C_Container.GetBagSlotFlag(bag, Enum.BagSlotFlags.DisableAutoSort)
		end
	end
end

function core.CommandDecorator(func, groups_defaults, required_count)
	local bag_groups = {}
	local decorated
	local retrying
	decorated = function(groups, retry)
		if retrying and not retry then return end
		local modgroups, target = SecureCmdOptionParse(groups)
		Debug("command wrapper", groups, modgroups, groups_defaults, required_count)
		if core.running then
			Debug("abort", "already running")
			return core.announce(0, L.already_running, 1, 0, 0)
		end
		if not modgroups then
			-- A command with no matched clause was run, and we don't want to
			-- fall back to default arguments in this case
			Debug("abort", "conditional not met")
			return
		end
		groups = modgroups
		wipe(bag_groups)
		if not groups or #groups == 0 then
			groups = groups_defaults
		end
		for bags in (groups or ""):gmatch("[^%s]+") do
			bags = core.get_group(bags)
			if bags then
				if core.check_for_banks(bags) then
					Debug("abort", "bank needed", bags)
					return
				end
				table.insert(bag_groups, bags)
			end
		end
		required_count = required_count or 1
		if #bag_groups < required_count then
			Debug("abort", "less groups than required", #bag_groups, required_count)
			return core.announce(0, L.confused, 1, 0, 0)
		end

		if not core.ScanBags() then
			retrying = (retrying or 0) + 1
			if retrying > 3 then
				Debug("abort", "retries exceeded")
				retrying = false
				return core.announce(0, L.confused, 1, 0, 0)
			end
			Debug("retry", "ScanBags failed")
			C_Timer.After(2, function() decorated(groups, true) end)
			return core.announce(0, L.retry, 1, 1, 0)
		end
		retrying = false
		if func(unpack(bag_groups)) == false then
			return
		end
		wipe(bag_groups)
		core.StartStacking()
	end
	return decorated
end

--Respond to events:
function core:ADDON_LOADED(event, addon)
    if hooks[addon] then
        hooks[addon]()
        hooks[addon] = nil
    end
end

local moves = {--[[encode_move(encode_bagslot(),encode_bagslot(target)),. ..--]]}
core.moves = moves

local bag_ids = {}
local bag_stacks = {}
local bag_maxstacks = {}
local bag_links = {}
core.bag_ids, core.bag_stacks, core.bag_maxstacks, core.bag_links = bag_ids, bag_stacks, bag_maxstacks, bag_links
local function update_location(from, to)
	-- When I move something from (3,12) to (0,1), the contents of (0,1) are now in (3,12).
	-- Therefore if I find later that I need to move something from (0,1), I actually need to move whatever wound up in (3,12).
	-- This function updates the various cache tables to reflect current locations.
	-- Debug("update_location", from, to)
	if (bag_ids[from] == bag_ids[to]) and (bag_stacks[to] < bag_maxstacks[to]) then
		-- If they're the same type we might have to deal with stacking.
		local stack_size = bag_maxstacks[to]
		if (bag_stacks[to] + bag_stacks[from]) > stack_size then
			-- only some of the items have been moved, since the total is greater than the stack size
			bag_stacks[from] = bag_stacks[from] - (stack_size - bag_stacks[to])
			bag_stacks[to] = stack_size
		else
			-- from is empty, since everything in it has been moved
			bag_stacks[to] = bag_stacks[to] + bag_stacks[from]
			bag_stacks[from] = nil
			bag_ids[from] = nil
			bag_maxstacks[from] = nil
			bag_links[from] = nil
		end
	else
		bag_ids[from], bag_ids[to] = bag_ids[to], bag_ids[from]
		bag_stacks[from], bag_stacks[to] = bag_stacks[to], bag_stacks[from]
		bag_maxstacks[from], bag_maxstacks[to] = bag_maxstacks[to], bag_maxstacks[from]
		bag_links[from], bag_links[to] = bag_links[to], bag_links[from]
	end
end
function core.ScanBags()
	local missing_data
	for _, bag, slot in core.IterateBags(core.has_guild_bank and all_bags_with_guild or all_bags) do
		local bagslot = encode_bagslot(bag, slot)
		local itemid = core.GetItemID(bag, slot)
		if itemid then
			bag_ids[bagslot] = itemid
			bag_stacks[bagslot] = select(2, core.GetItemInfo(bag, slot))
			bag_maxstacks[bagslot] = select(8, GetItemInfo(itemid))
			bag_links[bagslot] = core.GetItemLink(bag, slot)
			if bag_maxstacks[bagslot] == nil or bag_links[bagslot] == nil then
				missing_data = true
			end
		end
	end
	return not missing_data
end
function core.AddMove(source, destination)
	update_location(source, destination)
	table.insert(moves, 1, encode_move(source, destination))
end

local moves_underway, last_itemid, last_destination, lock_stop, last_move, move_retries
local move_tracker = {}

local function debugtime(start, ...) Debug("took", GetTime() - start, ...) end
function core.DoMoves()
	Debug("DoMoves", #moves)
	if InCombatLockdown() then
		Debug("Aborted because of combat")
		return core.StopStacking(L.confused)
	end
	wipe(already_queried)
	local cursortype, cursor_itemid = GetCursorInfo()
	if cursortype == "item" and cursor_itemid then
		if last_itemid ~= cursor_itemid then
			-- We didn't pick up whatever is on the cursor; things could get really screwed up if we carry on. Abort!
			Debug("Aborted because", last_itemid or 'nil', '~=', cursor_itemid or 'nil')
			return core.StopStacking(L.confused)
		end
		if move_retries < 10 then
			local target_bag, target_slot = decode_bagslot(last_destination)
			local _, _, target_locked = core.GetItemInfo(target_bag, target_slot)
			if not target_locked then
				Debug("Attempting to repeat move drop", last_itemid, target_bag, target_slot)
				core.PickupItem(target_bag, target_slot)
				WAIT_TIME = core.db.processing_delay
				lock_stop = GetTime()
				move_retries = move_retries + 1
				return
			end
		end
	end

	if lock_stop then
		Debug("Checking whether it's safe to move again")
		for slot, itemid in pairs(move_tracker) do
			local actual_slot_itemid = core.GetItemID(decode_bagslot(slot))
			Debug("checking whether", slot, "contains", itemid, actual_slot_itemid)
			if actual_slot_itemid ~= itemid then
				Debug("Stopping DoMoves because last move hasn't happened yet.", slot, itemid, actual_slot_itemid)
				WAIT_TIME = core.db.processing_delay
				if (GetTime() - lock_stop) > MAX_MOVE_TIME then
					if last_move and move_retries < 4 then
						local success, move_id = core.DoMove(last_move, true)
						Debug("Attempting to repeat entire move", last_move, success, move_id, move_retries)
						WAIT_TIME = core.db.processing_delay
						lock_stop = GetTime()
						move_retries = move_retries + 1
						return -- take a break!
					end
					-- Abandon it, since we've taken far too long on this move
					return core.StopStacking(L.confused)
				end
				return --give processing time to happen
			end
			move_tracker[slot] = nil
		end
	end

	move_retries, last_itemid, last_destination, last_move, lock_stop = 0, nil, nil, nil, nil
	wipe(move_tracker)

	core.events:Fire("Doing_Moves", #moves, moves)

	local start, success, move_id, target_id, move_source, move_target, was_guild
	start = GetTime()
	if #moves > 0 then for i=#moves, 1, -1 do
		success, move_id, move_source, target_id, move_target, was_guild = core.DoMove(moves[i])
		if not success then
			debugtime(start, move_id or 'unspecified') -- repurposing for debugging
			WAIT_TIME = core.db.processing_delay
			lock_stop = GetTime()
			return -- take a break!
		end
		move_tracker[move_source] = target_id
		move_tracker[move_target] = move_id
		last_itemid = move_id
		last_destination = move_target
		last_move = moves[i]
		table.remove(moves, i)
		if moves[i-1] then
			-- Guild bank CursorHasItem/CursorItemInfo isn't working, so slow down for it.
			if was_guild then
				local next_source, next_target = decode_move(moves[i-1])
				if core.db.conservative_guild or move_tracker[next_source] or move_tracker[next_target] then
					Debug("fake-guild-locking is in effect", core.db.conservative_guild and "conservative" or "locking")
					WAIT_TIME = core.db.processing_delay_guild
					lock_stop = GetTime()
					debugtime(start, 'guild bank sucks')
					return
				end
			end
			if (GetTime() - start) > core.db.stutter_duration then
				-- avoiding the lags
				WAIT_TIME = core.db.stutter_delay
				debugtime(start, "stutter-avoider")
				return
			end
		end
	end end
	debugtime(start, 'done')
	core.announce(1, L.complete, 1, 1, 1)
	core.StopStacking()
end

function core.DoMove(move)
	if GetCursorInfo() == "item" then
		return false, 'cursorhasitem'
	end
	local source, target = decode_move(move)
	local source_bag, source_slot = decode_bagslot(source)
	local target_bag, target_slot = decode_bagslot(target)
	local _, source_count, source_locked = core.GetItemInfo(source_bag, source_slot)
	local _, target_count, target_locked = core.GetItemInfo(target_bag, target_slot)

	if source_locked or target_locked then
		return false, 'source/target_locked'
	end

	local source_link = core.GetItemLink(source_bag, source_slot)
	local source_itemid = core.GetItemID(source_bag, source_slot)
	local target_itemid = core.GetItemID(target_bag, target_slot)
	if not source_itemid then
		if move_tracker[source] then
			return false, 'move incomplete'
		else
			Debug("Aborted because not source_itemid", source_bag, source_slot, source_link, source_itemid or 'nil')
			return core.StopStacking(L.confused)
		end
	end
	local stack_size = select(8, GetItemInfo(source_itemid))

	core.announce(2, string.format(L.moving, source_link), 1,1,1)

	if
		(source_itemid == target_itemid)
		and
		(target_count ~= stack_size)
		and
		((target_count + source_count) > stack_size)
	then
		core.SplitItem(source_bag, source_slot, stack_size - target_count)
	else
		core.PickupItem(source_bag, source_slot)
	end
	local source_guildbank = is_guild_bank_bag(source_bag)
	local target_guildbank = is_guild_bank_bag(target_bag)
	if GetCursorInfo() == "item" then
		-- CursorHasItem doesn't work on the guild bank
		core.PickupItem(target_bag, target_slot)
	end

	if source_guildbank then
		QueryGuildBankTabIfNeeded(source_bag - 50)
	end
	if target_guildbank then
		QueryGuildBankTabIfNeeded(target_bag - 50)
	end

	if (source_itemid == target_itemid)
		and
		(target_count ~= stack_size)
		and
		((target_count + source_count) <= stack_size)
	then
		-- we're doing a merge, so we pass back that we're not moving anything from the target slot to the source slot
		target_itemid = nil
	end

	Debug("Moved", source, source_itemid, target, target_itemid, source_guildbank or target_guildbank)
	return true, source_itemid, source, target_itemid, target, source_guildbank or target_guildbank
end

function core.StartStacking()
	wipe(bag_maxstacks)
	wipe(bag_stacks)
	wipe(bag_ids)
	wipe(bag_links)
	wipe(core.bag_soulbound)
	wipe(core.bag_conjured)
	wipe(move_tracker)

	if #moves > 0 then
		core.running = true
		core.announce(1, string.format(L.to_move, #moves), 1, 1, 1)
		frame:Show()
		core.events:Fire("Stacking_Started", #moves)
	else
		core.announce(1, L.perfect, 1, 1, 1)
		core.StopStacking()
	end
end

function core.StopStacking(message, r, g, b)
	core.running = false
	core.bankrequired = false
	core.guildbankrequired = false
	wipe(moves)
	wipe(move_tracker)
	move_retries, last_itemid, lock_stop, last_destination, last_move = 0, nil, nil, nil, nil
	frame:Hide()
	if message then
		core.announce(1, message, r or 1, g or 0, b or 0)
	end
	core.events:Fire("Stacking_Stopped", message)
end

-- These are helpers, which aren't kept up to date with moves like the other bag_ tables are:
core.bag_soulbound = setmetatable({}, {__index = function(self, bagslot)
	local bag, slot = decode_bagslot(bagslot)
	-- can't put soulbound items in a guild bank *and* ItemLocation won't work for it
	if core.is_guild_bank_bag(bag) then return false end
	local item = core.bag_itemlocation[bagslot]
	-- can't use item:IsValid because it's not present in classic (yet), but it's just a helper for this anyway:
	if not C_Item.DoesItemExist(item) then return false end
	local is_soulbound = C_Item.IsBound(item)
	self[bagslot] = is_soulbound
	return is_soulbound
end,})
core.bag_conjured = setmetatable({}, {__index = function(self, bagslot)
	local bag, slot = decode_bagslot(bagslot)
	if core.is_guild_bank_bag(bag) then return false end
	local is_conjured = core.CheckTooltipFor(bag, slot, ITEM_CONJURED)
	self[bagslot] = is_conjured
	return is_conjured
end,})
core.bag_itemlocation = setmetatable({}, {__index = function(self, bagslot)
	local bag, slot = decode_bagslot(bagslot)
	if core.is_guild_bank_bag(bag) then return false end
	local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
	self[bagslot] = itemLocation
	return itemLocation
end,})

function core.announce(level, message, ...)
	if level > core.db.verbosity then return end
	DEFAULT_CHAT_FRAME:AddMessage(message, ...)
end
