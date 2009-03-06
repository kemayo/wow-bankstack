--http://forums.playhard.ru/index.php?s=&showtopic=27938&view=findpost&p=535884
if not GetLocale()=='ruRU' then return end
BankStackLocale = {
	-- Messages:
	already_running = "BankStack: A stacker is already running.",
	at_bank = "BankStack: вы должны быть в банке.",
	complete = "BankStack: завершено.",
	confused = "BankStack: Confusion. Stopping.",
	moving = "BankStack: перемещение %s.",
	opt_set = "BankStack: %s установлено в %s.",
	options = "BankStack опции:",
	perfect = "BankStack: Perfection already exists.",
	to_move = "BankStack: %d moves to make.",
	
	-- Item types and subtypes:
	ARMOR = "Доспехи",
	BAG = "Сумка",
	CONSUMABLE = "Потребляемые",
	CONTAINER = "Сумки",
	GEM = "Самоцветы",
	KEY = "Ключ",
	MISC = "Разное",
	PROJECTILE = "Боеприпасы",
	REAGENT = "Реагент",
	RECIPE = "Рецепты",
	QUEST = "Задания",
	QUIVER = "Амуниция",
	TRADEGOODS = "Ремесла",
	WEAPON = "Оружие",
}
--Bindings:
BINDING_HEADER_BANKSTACK = "BankStack"
BINDING_NAME_BANKSTACK = "Stack to bank"
BINDING_NAME_COMPRESS = "Сжать сумки"
BINDING_NAME_BAGSORT = "Отсортировать сумки"