local myname = ...

local core = BankStack
local module = core:NewModule("Blizzard", "AceEvent-3.0")

function module:OnInitialize()
	self.db = core.db_object:RegisterNamespace("Blizzard", {
		profile = {
			hijack = core.CLASSIC,
		},
	})
	if core.options then
		core.options.args.blizzard.plugins.hijack = {
			hijack = {
				name = core.CLASSIC and "Show on bag and bank" or "Take over Blizzard sort buttons",
				desc = "Click sort buttons in your bags and bank(s)",
				descStyle = "inline", width="full",
				type = "toggle",
				get = function() return self.db.profile.hijack end,
				set = function(info, value)
					self.db.profile.hijack = value
					self:UpdateButtons()
				end,
			},
		}
	end

	self.buttons = {}

	self:SetupButtons()
	self:UpdateButtons()
end

function module:UpdateButtons()
	for _, button in ipairs(self.buttons) do
		if self.db.profile.hijack then
			button:Show()
		else
			button:Hide()
		end
	end
end

function module:SetupButtons()
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		-- Retail, where we just need to take over the built-in buttons
		local sortbags = core.CommandDecorator(core.SortBags, 'bags')
		local bags = self:MakeButton(BagItemAutoSortButton, sortbags, BAG_CLEANUP_BAGS, BAG_CLEANUP_BAGS_DESCRIPTION)
		bags:SetAllPoints(BagItemAutoSortButton)

		local sortbank = core.CommandDecorator(core.SortBags, 'bank')
		-- This is both, so a way to swap in BAG_CLEANUP_ACCOUNT_BANK might be nice
		local bank = self:MakeButton(BankPanel.AutoSortButton, function()
			if IsAltKeyDown() then
				if BankPanel.bankType == Enum.BankType.Character then
					sortbank("bank")
				elseif BankPanel.bankType == Enum.BankType.Account then
					sortbank("account")
				end
				return
			end
			sortbank(tostring(BankPanel:GetSelectedTabID()))
		end, BAG_CLEANUP_BANK, "Click to sort the current tab; alt-click to sort the entire bank")
		bank:SetAllPoints(BankPanel.AutoSortButton)
	else
		-- Classic
		local sortbags = core.CommandDecorator(core.SortBags, 'bags')
		local sortbank = core.CommandDecorator(core.SortBags, 'bank')

		local bags = self:MakeButton(ContainerFrame1, sortbags, BAG_CLEANUP_BAGS, BAG_CLEANUP_BAGS_DESCRIPTION)
		local bank = self:MakeButton(BankFrame, sortbank, BAG_CLEANUP_BANK)

		if core.CLASSICERA then
			bags:SetPoint("TOPRIGHT", -4, -26)
			bank:SetPoint("TOPRIGHT", -60, -44)
		else
			bags:SetPoint("BOTTOMLEFT", 10, 6)
			bank:SetPoint("TOPRIGHT", BankItemSearchBox, "TOPLEFT", -8, 1)
		end
	end
end

function module:MakeButton(parent, callback, label, desc)
	local sort = CreateFrame("Button", nil, parent) --, "UIPanelButtonTemplate")
	sort:SetSize(25, 23)
	sort:RegisterForClicks("anyUp")

	sort:SetNormalAtlas("bags-button-autosort-up")
	sort:SetPushedAtlas("bags-button-autosort-down")
	sort:SetDisabledAtlas("bags-button-autosort-up", true)
	sort:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")

	sort:SetScript("OnClick", function(button, mousebutton)
		if mousebutton == "LeftButton" then
			PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
			callback()
		end
	end)
	sort:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_LEFT")
		GameTooltip_SetTitle(GameTooltip, label, HIGHLIGHT_FONT_COLOR)
		if desc then
			GameTooltip_AddNormalLine(GameTooltip, desc)
		end
		GameTooltip:AddDoubleLine(" ", myname, 1, 1, 1, 1, 0.5, 0.5)
		GameTooltip:Show()
	end)
	sort:SetScript("OnLeave", GameTooltip_Hide)

	table.insert(self.buttons, sort)

	return sort
end
