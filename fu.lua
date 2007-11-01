if not (Rock and Rock:HasLibrary("LibFuBarPlugin-3.0")) then return end

local core = BankStack

local fu = Rock:NewAddon("coreFu", "LibFuBarPlugin-3.0")
fu:SetFuBarOption('tooltipType', "GameTooltip")
--fu:SetFuBarOption('iconPath', [[Interface\Icons\INV_Misc_Shovel_01]])
function fu:OnFuBarClick(button)
	if #(core.moves) > 0 then 
		return core.StopStacking("BankStack: Aborted.")
	elseif IsShiftKeyDown() then
		if IsAltKeyDown() then
			core.BankStack("reverse")
		else
			core.BankStack()
		end
	elseif IsControlKeyDown() then
		if IsAltKeyDown() then
			core.Compress("bank")
		else
			core.Compress()
		end
	else
		if IsAltKeyDown() then
			core.SortBags("bank")
		else
			core.SortBags()
		end
	end
end
function fu:OnUpdateFuBarText()
	self:SetFuBarText("BankStack")
end
function fu:OnUpdateFuBarTooltip()
	GameTooltip:AddLine("BankStack")
	GameTooltip:AddDoubleLine("Click", "Sort bags", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Alt-Click", "Sort bank", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Ctrl-Click", "Compress bags", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Ctrl-Alt-Click", "Compress bank", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Shift-Click", "Stack to bank", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Shift-Alt-Click", "Stack to bags", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Click while stacking", "Abort", 1, 0, 0, 1, 0, 0)
end
