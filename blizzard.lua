-- Classic-only
if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return end

local core = BankStack

local sortbags = core.CommandDecorator(core.SortBags, 'bags')
local sortbank = core.CommandDecorator(core.SortBags, 'bank')

local makeSortButton = function(frame, callback, label)
	local sort = CreateFrame("Button", nil, frame) --, "UIPanelButtonTemplate")
	sort:SetSize(25, 23)
	sort:RegisterForClicks("anyUp")

	sort:SetNormalAtlas("bags-button-autosort-up")
	sort:SetPushedAtlas("bags-button-autosort-down")
	sort:SetDisabledAtlas("bags-button-autosort-up", true)
	sort:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")

	sort:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
			callback()
		end
	end)
	sort:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(label, 1, 1, 1)
		GameTooltip:Show()
	end)
	sort:SetScript("OnLeave", GameTooltip_Hide)

	return sort
end

local bags = makeSortButton(ContainerFrame1, sortbags, BAG_CLEANUP_BAGS)
bags:SetPoint("TOPRIGHT", -4, -26)

local bank = makeSortButton(BankFrame, sortbank, BAG_CLEANUP_BANK)
bank:SetPoint("TOPRIGHT", -60, -44)
