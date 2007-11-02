if not GetLocale()=='enUS' then return end
BankStackLocale = {
	-- Messages:
	already_running = "BankStack: A stacker is already running.",
	at_bank = "BankStack: You must be at the bank.",
	complete = "BankStack: Complete.",
	confused = "BankStack: Confusion. Stopping.",
	moving = "BankStack: Moving %s.",
	opt_set = "BankStack: %s set to %s.",
	options = "BankStack options:",
	perfect = "BankStack: Perfection already exists.",
	to_move = "BankStack: %d moves to make.",
	
	-- Item types and subtypes:
	ARMOR = "Armor",
	BAG = "Bag",
	CONSUMABLE = "Consumable",
	CONTAINER = "Container",
	GEM = "Gem",
	KEY = "Key",
	MISC = "Miscellaneous",
	PROJECTILE = "Projectile",
	REAGENT = "Reagent",
	RECIPE = "Recipe",
	QUEST = "Quest",
	QUIVER = "Quiver",
	TRADEGOODS = "Trade Goods",
	WEAPON = "Weapon",
}
--Bindings:
BINDING_HEADER_BANKSTACK = "BankStack"
BINDING_NAME_BANKSTACK = "Stack to bank"
BINDING_NAME_COMPRESS = "Compress bags"
BINDING_NAME_BAGSORT = "Sorts bags"