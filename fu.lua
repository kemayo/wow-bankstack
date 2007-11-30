if not (Rock and Rock:HasLibrary("LibFuBarPlugin-3.0")) or not (AceLibrary and AceLibrary("FuBarPlugin-2.0")) then return end

local core = BankStack

--FuBarPlugin / Ace inserts crap into this, so make a copy.
local menu = {
	name = "BankStackFu", type = "group",
	args = {},
}
for k,v in pairs(core.aceoptions.args) do
	menu.args[k] = v
end

local fu
if AceLibrary and AceLibrary("FuBarPlugin-2.0") then
	fu = AceLibrary("AceAddon-2.0"):new("FuBarPlugin-2.0", "AceDB-2.0")
	fu.name = "BankStackFu"
	fu.title = "BankStackFu"
	fu.hasIcon = [[Interface\Icons\INV_Misc_Shovel_01]]
	fu.blizzardTooltip = true
	fu.OnMenuRequest = menu
	fu:RegisterDB("BankStackFuDB")
	
	function fu:OnTextUpdate()
		self:SetText("BankStack")
	end
else
	fu = Rock:NewAddon("BankStackFu", "LibFuBarPlugin-3.0")
	fu:SetFuBarOption('tooltipType', "GameTooltip")
	--fu:SetFuBarOption('iconPath', [[Interface\Icons\INV_Misc_Shovel_01]])
	fu:SetConfigTable(core.aceoptions)
	fu.OnMenuRequest = core.aceoptions
	
	function fu:OnUpdateFuBarText()
		self:SetFuBarText("BankStack")
	end
end

--Custom keybindings
local keybindingsOnly = {
	['BUTTON1'] = true, ['ALT-BUTTON1'] = true,
	['CTRL-BUTTON1'] = true, ['ALT-CTRL-BUTTON1'] = true,
	['SHIFT-BUTTON1'] = true, ['ALT-SHIFT-BUTTON1'] = true,
	['CTRL-SHIFT-BUTTON1'] = true, ['ALT-CTRL-SHIFT-BUTTON1'] = true,
}
menu.args.click = {
	name = "Click assignments", desc = "Modified left-clicks only",
	type = "group", pass = true,
	get = function(k)
		for b, a in pairs(core.db.fubar_keybinds) do
			if a == k then
				return b
			end
		end
	end,
	set = function(k, v)
		-- clear current binding
		for b, a in pairs(core.db.fubar_keybinds) do
			if a == k then
				core.db.fubar_keybinds[b] = false
			end
		end
		-- set new binding
		if keybindingsOnly[v] then
			core.db.fubar_keybinds[v] = k
		end
	end,
	args = {
		sortbags = {name = "Sort Bags", desc = "Modified left-clicks only", type = "text", validate = 'keybinding', order = 1,},
		sortbank = {name = "Sort Bank", desc = "Modified left-clicks only", type = "text", validate = 'keybinding', order = 2,},
		stackbank = {name = "Stack to Bank", desc = "Modified left-clicks only", type = "text", validate = 'keybinding', order = 3,},
		stackbags = {name = "Stack to Bags", desc = "Modified left-clicks only", type = "text", validate = 'keybinding', order = 4,},
		compressbags = {name = "Compress Bags", desc = "Modified left-clicks only", type = "text", validate = 'keybinding', order = 5,},
		compressbank = {name = "Compress Bank", desc = "Modified left-clicks only", type = "text", validate = 'keybinding', order = 6,},
	},
}
local click_actions = {
	sortbags = core.SortBags,
	sortbank = function() core.SortBags('bank') end,
	stackbags = function() core.BankStack('bank bags') end,
	stackbank = core.BankStack,
	compressbags = core.Compress,
	compressbank = function() core.Compress('bank') end,
}

local function build_current_keybind()
	-- Note that this does hardcode BUTTON1, because I'm lazy
	return (IsAltKeyDown() and 'ALT-' or '') ..
		(IsControlKeyDown() and 'CTRL-' or '') ..
		(IsShiftKeyDown() and 'SHIFT-' or '') ..
		'BUTTON1'
end
local function pretty_keybind(keybind)
	-- Again, assumes left mouse button
	return keybind and ((string.match(keybind, "ALT-") and "Alt-" or '') ..
		(string.match(keybind, "CTRL-") and "Ctrl-" or '') ..
		(string.match(keybind, "SHIFT-") and "Shift-" or '') ..
		"Click") or 'None'
end

function fu:OnFuBarClick(button)
	if #(core.moves) > 0 then 
		return core.StopStacking("BankStack: Aborted.")
	else
		--Build the keybind that triggered this.  There might be a better way to do this.
		local keybind = build_current_keybind()
		local action = core.db.fubar_keybinds[keybind]
		if keybind and click_actions[action] then
			click_actions[action]()
		end
	end
end
fu.OnClick = fu.OnFuBarClick

local ordered = {}
local order_func = function(a, b)
	return menu.args.click.args[a].order < menu.args.click.args[b].order
end
function fu:OnUpdateFuBarTooltip()
	GameTooltip:AddLine("BankStack")
	for k in pairs(menu.args.click.args) do
		table.insert(ordered, k)
	end
	table.sort(ordered, order_func)
	for _, k in ipairs(ordered) do
		GameTooltip:AddDoubleLine(pretty_keybind(menu.args.click.get(k)), menu.args.click.args[k].name, 0, 1, 0, 1, 1, 1)
	end
	core.clear(ordered)
	GameTooltip:AddDoubleLine("Click while stacking", "Abort", 1, 0, 0, 1, 0, 0)
end
fu.OnTooltipUpdate = fu.OnUpdateFuBarTooltip
