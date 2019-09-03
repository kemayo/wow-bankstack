local core = BankStack
local inv = LibStub("AceAddon-3.0"):GetAddon("Inventorian", true)

if inv then
	local sortbags = core.CommandDecorator(core.SortBags, 'bags')
	local sortbank = core.CommandDecorator(core.SortBags, 'bank')
	local original_FrameCreate = inv.Frame.Create
	inv.Frame.Create = function(inventorianFrame, ...)
		local frame = original_FrameCreate(inventorianFrame, ...)

		local sort = CreateFrame("Button", nil, frame) --, "UIPanelButtonTemplate")
		sort:SetSize(25, 23)
		sort:SetPoint("TOPRIGHT", -44, -31)
		sort:RegisterForClicks("anyUp")

		sort:SetNormalAtlas("bags-button-autosort-up")
		sort:SetPushedAtlas("bags-button-autosort-down")
		sort:SetDisabledAtlas("bags-button-autosort-up", true)
		sort:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")

		sort:SetScript("OnClick", function(self, button)
			if button == "LeftButton" then
				PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
				if frame:IsBank() then
					sortbank()
				else
					sortbags()
				end
			end
		end)
		sort:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(sort, "ANCHOR_LEFT")
			GameTooltip:SetText(frame:IsBank() and BAG_CLEANUP_BANK or BAG_CLEANUP_BAGS, 1, 1, 1)
			GameTooltip:Show()
		end)
		sort:SetScript("OnLeave", GameTooltip_Hide)

		return frame
	end
end
