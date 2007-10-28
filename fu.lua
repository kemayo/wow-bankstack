if not (Rock and Rock:HasLibrary("LibFuBarPlugin-3.0")) then return end

local fu = Rock:NewAddon("BankStackFu", "LibFuBarPlugin-3.0")
fu:SetFuBarOption('tooltipType', "GameTooltip")
--fu:SetFuBarOption('iconPath', [[Interface\Icons\INV_Misc_Shovel_01]])
function fu:OnFuBarClick(button)
	if IsShiftKeyDown() and IsAltKeyDown and IsControlKeyDown() then
		return BankStack.StopStacking("BankStack: Aborted.")
	elseif IsShiftKeyDown() then
		if IsAltKeyDown() then
			BankStack.BankStack("reverse")
		else
			BankStack.BankStack()
		end
	else
		if IsAltKeyDown() then
			BankStack.Compress("bank")
		else
			BankStack.Compress()
		end
	end
end
function fu:OnUpdateFuBarText()
	self:SetFuBarText("BankStack")
end
function fu:OnUpdateFuBarTooltip()
	GameTooltip:AddLine("BankStack")
	GameTooltip:AddDoubleLine("Click", "Compress", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Alt-Click", "Compress bank", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Shift-Click", "Stack to bank", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Alt-Shift-Click", "Stack to bags", 0, 1, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Ctrl-Alt-Shift-Click", "Abort", 0, 1, 0, 1, 0, 0)
end
