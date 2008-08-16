local core = BankStack

local click_actions = {
	sortbags = core.SortBags,
	sortbank = function() core.SortBags('bank') end,
	stackbags = function() core.BankStack('bank bags') end,
	stackbank = core.BankStack,
	compressbags = core.Compress,
	compressbank = function() core.Compress('bank') end,
}
local name_map = {
	sortbags = "Sort Bags",
	sortbank = "Sort Bank",
	stackbags = "Stack from bank to bags",
	stackbank = "Stack from bags to bank",
	compressbags = "Compress stacks in bags",
	compressbank = "Compress stacks in bank",
}
local binding_order = {
	'sortbags', 'sortbank', 'stackbags', 'stackbank', 'compressbags', 'compressbank',
	--'BUTTON1', 'ALT-BUTTON1', 'CTRL-BUTTON1', 'ALT-CTRL-BUTTON1', 'SHIFT-BUTTON1',
	--'ALT-SHIFT-BUTTON1', 'CTRL-SHIFT-BUTTON1', 'ALT-CTRL-SHIFT-BUTTON1',
}

local function get_binding_for_action(action)
	for binding, act in pairs(core.db.fubar_keybinds) do
		if action == act then
			return binding
		end
	end
end

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

LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("BankStack", {
	type = "launcher",
	icon = [[Interface\Icons\INV_Misc_Shovel_01]],
	OnClick = function(frame, button)
		if button == "RightButton" then
			-- open up the config
			return InterfaceOptionsFrame_OpenToFrame(LibStub("AceConfigDialog-3.0").BlizOptions["BankStack"].frame)
		end
		if #(core.moves) > 0 then 
			return core.StopStacking("BankStack: Aborted.")
		end
		--Build the keybind that triggered this.  There might be a better way to do this.
		local keybind = build_current_keybind()
		local action = core.db.fubar_keybinds[keybind]
		if keybind and click_actions[action] then
			click_actions[action]()
		end
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddLine("BankStack")
		for _, action in ipairs(binding_order) do
			tooltip:AddDoubleLine(pretty_keybind(get_binding_for_action(action)), name_map[action], 0, 1, 0, 1, 1, 1)
		end
		tooltip:AddDoubleLine("Click while stacking", "Abort", 1, 0, 0, 1, 0, 0)
	end,
})

