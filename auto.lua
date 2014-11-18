local core = BankStack
local module = core:NewModule("Auto", "AceEvent-3.0")
local Debug = core.Debug

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
				name = "Auto",
				inline = true,
				get = function(info) return db.profile[info[#info]] end,
				set = function(info, value) db.profile[info[#info]] = value end,
				args = {
					bank_opened = {
						type = "select",
						name = "Bank opened",
						values = {
							none = "Nothing",
							sort_bags = "Sort Bags",
							sort_bank = "Sort Bank",
							sort_both = "Sort Bags and Bank",
							stack_to_bank = "Stack to Bank",
							stack_to_bags = "Stack to Bags",
							compress_bags = "Compress Bags",
							compress_bank = "Compress Bank",
							compress_both = "Compress Bags and Bank",
						},
					},
					afk = {
						type = "select",
						name = "Going AFK",
						values = {
							none = "Nothing",
							sort_bags = "Sort Bags",
							compress_bags = "Compress Bags",
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
	stack_to_bags = core.CommandDecorator(core.StackSummary, 'bank bags'),
	stack_to_bank = core.CommandDecorator(core.StackSummary, 'bags bank'),
	compress_bags = core.CommandDecorator(core.Compress, 'bags'),
	compress_bank = core.CommandDecorator(core.Compress, 'bank'),
	compress_bank = core.CommandDecorator(core.Compress, 'bags bank'),
}

core.RegisterCallback("Auto", "Bank_Open", function(callback)
	if not actions[db.profile.bank_opened] then return end
	actions[db.profile.bank_opened]()
end)

function module:PLAYER_FLAGS_CHANGED(event, unit)
	if unit ~= "player" then return end
	if not UnitIsAFK("player") then return end
	if not actions[db.profile.afk] then return end
	actions[db.profile.afk]()
end
