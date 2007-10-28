if not (Rock and Rock:HasLibrary("LibFuBarPlugin-3.0")) then return end

local fu = Rock:NewAddon("BankStackFu", "LibFuBarPlugin-3.0")
fu:SetFuBarOption('tooltipType', "GameTooltip")
--fu:SetFuBarIcon("Interface\\Icons\\INV_Misc_Shovel_01")
function fu:OnFuBarClick()
	BankStack.Stack()
end
function fu:OnUpdateFuBarText()
	self:SetFuBarText("BankStack")
end
--/print Rock:GetAddon("BankStackFu"):IsFuBarIconShown()