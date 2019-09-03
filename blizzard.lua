local core = BankStack

local sortbags = core.CommandDecorator(core.SortBags, 'bags')
local sortbank = core.CommandDecorator(core.SortBags, 'bank')

local makeSortButton = function(frame, callback)
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
		GameTooltip:SetOwner(button, "ANCHOR_LEFT")
		GameTooltip:SetText(BAG_CLEANUP_BAGS, 1, 1, 1)
		GameTooltip:Show()
	end)
	sort:SetScript("OnLeave", GameTooltip_Hide)

	return sort
end

local bags = makeSortButton(ContainerFrame1, sortbags)
bags:SetPoint("TOPRIGHT", -4, -26)

-- TODO: get to bank to test spacing
-- local bank = makeSortButton(BankFrame, sortbank)
