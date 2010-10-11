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
	sort_bags = function() core.SortBags("bags") end,
	sort_bank = function() core.SortBags("bank") end,
	sort_both = function() core.SortBags("bank bags") end,
	stack_to_bank = function() core.BankStack("bags bank") end,
	stack_to_bags = function() core.BankStack("bank bags") end,
	compress_bags = function() core.Compress("bags") end,
	compress_bank = function() core.Compress("bank") end,
	compress_both = function() core.Compress("bags bank") end,
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
