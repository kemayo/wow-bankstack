local core = BankStack
local L = core.L
local module = core:NewModule("Auto", "AceEvent-3.0")
local Debug = core.Debug

local issecretvalue = _G.issecretvalue or function() return false end

local db
function module:OnInitialize()
	self.db = core.db_object:RegisterNamespace("Auto", {
		profile = {
			bank_opened = "none",
			afk = "none",
		},
	})
	db = self.db
	if core.options then
		core.options.plugins.auto = {
			auto = {
				type = "group",
				name = L['OPTIONS_AUTO'],
				inline = true,
				get = function(info) return db.profile[info[#info]] end,
				set = function(info, value) db.profile[info[#info]] = value end,
				args = {
					bank_opened = {
						type = "select",
						name = L['OPTIONS_AUTO_BANK_OPENED'],
						values = {
							none = NONE,
							sort_bags = L['ACTION_SORTBAGS'],
							sort_bank = L['ACTION_SORTBANK'],
							sort_both = L['ACTION_SORTBOTH'],
							stack_to_bank = L['ACTION_STACKBANK'],
							stack_to_bags = L['ACTION_STACKBAGS'],
							compress_bags = L['ACTION_COMPRESSBAGS'],
							compress_bank = L['ACTION_COMPRESSBANK'],
							compress_both = L['ACTION_COMPRESSBOTH'],
						},
					},
					afk = {
						type = "select",
						name = L['OPTIONS_AUTO_AFK'],
						values = {
							none = NONE,
							sort_bags = L['ACTION_SORTBAGS'],
							compress_bags = L['ACTION_COMPRESSBAGS'],
						},
					},
				},
			},
		}
	end

	self:RegisterEvent("PLAYER_FLAGS_CHANGED")
end

local actions = {
	sort_bags = core.CommandDecorator(core.SortBags, 'bags'),
	sort_bank = core.CommandDecorator(core.SortBags, 'bank'),
	sort_both = core.CommandDecorator(core.SortBags, 'bank bags'),
	stack_to_bags = core.CommandDecorator(core.StackSummary, 'bank bags', nil, true),
	stack_to_bank = core.CommandDecorator(core.StackSummary, 'bags bank', nil, true),
	compress_bags = core.CommandDecorator(core.Compress, 'bags'),
	compress_bank = core.CommandDecorator(core.Compress, 'bank'),
	compress_both = core.CommandDecorator(core.Compress, 'bags bank'),
}

core.RegisterCallback("Auto", "Bank_Open", function(callback)
	if not actions[db.profile.bank_opened] then return end
	actions[db.profile.bank_opened]()
end)

function module:PLAYER_FLAGS_CHANGED(event, unit)
	if unit ~= "player" then return end
	if not actions[db.profile.afk] then return end
	local isAFK = UnitIsAFK(unit)
	-- SecretInChatMessagingLockdown:
	if issecretvalue(isAFK) then return end
	if not isAFK then return end
	actions[db.profile.afk]()
end
