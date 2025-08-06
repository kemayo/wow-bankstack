local core = BankStack
local module = core:NewModule("LDB")
local icon = LibStub("LibDBIcon-1.0", true)

local click_actions = {
	sortbags = core.CommandDecorator(core.SortBags, 'bags'),
	sortbank = core.CommandDecorator(core.SortBags, 'bank'),
	stackbags = core.CommandDecorator(core.StackSummary, 'bank bags'),
	stackbank = core.CommandDecorator(core.StackSummary, 'bags bank'),
	compressbags = core.CommandDecorator(core.Compress, 'bags'),
	compressbank = core.CommandDecorator(core.Compress, 'bank'),
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
	return keybind and ((string.match(keybind, "ALT-") and core.L["KEYBIND_PREFIX_ALT"] or '') ..
		(string.match(keybind, "CTRL-") and core.L["KEYBIND_PREFIX_CTRL"] or '') ..
		(string.match(keybind, "SHIFT-") and core.L["KEYBIND_PREFIX_SHIFT"] or '') ..
		core.L["KEYBIND_CLICK"]) or core.L['KEYBIND_NONE']
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobject = ldb:GetDataObjectByName("BankStack") or ldb:NewDataObject("BankStack", {
	type = "data source",
	label = "BankStack",
	icon = [[Interface\Icons\INV_Misc_Shovel_01]],
})
dataobject.OnClick = function(frame, button)
	if button == "RightButton" then
		-- open up the config
		return Settings.OpenToCategory("BankStack")
	end
	if #(core.moves) > 0 then
		return core.StopStacking(core.L['CHAT_MSG_ABORTED'])
	end
	--Build the keybind that triggered this.  There might be a better way to do this.
	local keybind = build_current_keybind()
	local action = core.db.fubar_keybinds[keybind]
	if keybind and click_actions[action] then
		click_actions[action]()
	end
end
dataobject.OnTooltipShow = function(tooltip)
	tooltip:AddLine("BankStack")
	for _, action in ipairs(binding_order) do
		tooltip:AddDoubleLine(pretty_keybind(get_binding_for_action(action)), core.L['ACTION_' .. action:upper()], 0, 1, 0, 1, 1, 1)
	end
	tooltip:AddDoubleLine(core.L['KEYBIND_CLICK_WHILE_STACKING'], core.L['ACTION_ABORT'], 1, 0, 0, 1, 0, 0)
end

local db
function module:OnInitialize()
	self.db = core.db_object:RegisterNamespace("LDB", {
		profile = {
			minimap = {},
		},
	})
	db = self.db
	if icon then
		icon:Register("BankStack", dataobject, self.db.profile.minimap)
	end
	if core.options then
		core.options.plugins.ldb = {
			minimap = {
				type = "toggle",
				name = core.L['OPTIONS_SHOW_MINIMAP_ICON'],
				desc = core.L['OPTIONS_SHOW_MINIMAP_ICON_DESCRIPTION'],
				get = function() return not db.profile.minimap.hide end,
				set = function(info, v)
					local hide = not v
					db.profile.minimap.hide = hide
					if hide then
						icon:Hide("BankStack")
					else
						icon:Show("BankStack")
					end
				end,
				order = 30,
				width = "full",
				hidden = function() return not icon or not dataobject or not icon:IsRegistered("BankStack") end,
			},
		}
	end
end

core.RegisterCallback("LDB", "Doing_Moves", function(callback, num_moves)
	dataobject.text = core.L['CHAT_MSG_TO_MOVE_NOPREFIX'].format(num_moves)
end)

core.RegisterCallback("LDB", "Stacking_Stopped", function(callback, message)
	dataobject.text = dataobject.label
end)

core.dataobject = dataobject
