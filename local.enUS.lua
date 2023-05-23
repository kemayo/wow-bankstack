-- BankStack Locale
-- Please use the Localization App on WoWAce to Update this
-- http://www.wowace.com/projects/bank-stack/localization/

local L = LibStub("AceLocale-3.0"):NewLocale("BankStack", "enUS", true)
if not L then return end

-- Messages:
L['already_running'] = "BankStack: A stacker is already running."
L['at_bank'] = "BankStack: You must be at the bank."
L['complete'] = "BankStack: Complete."
L['confused'] = "BankStack: Confusion. Stopping."
L['retry'] = "BankStack: item data not loaded, waiting to retry."
L['moving'] = "BankStack: Moving %s."
L['opt_set'] = "BankStack: %s set to %s."
L['options'] = "BankStack options:"
L['perfect'] = "BankStack: Perfection already exists."
L['to_move'] = "BankStack: %d moves to make."

-- Item types and subtypes:
L['ARMOR'] = "Armor"
L['CONSUMABLE'] = "Consumable"
L['GEM'] = "Gem"
L['KEY'] = "Key"
L['MISC'] = "Miscellaneous"
L['PROJECTILE'] = "Projectile"
L['REAGENT'] = "Reagent"
L['RECIPE'] = "Recipe"
L['QUEST'] = "Quest"
L['QUIVER'] = "Quiver"
L['TRADEGOODS'] = "Trade Goods"
L['WEAPON'] = "Weapon"

--Bindings:
L['BINDING_HEADER_BANKSTACK_HEAD'] = "BankStack"
L['BINDING_NAME_BANKSTACK'] = "Stack to bank"
L['BINDING_NAME_COMPRESS'] = "Compress bags"
L['BINDING_NAME_BAGSORT'] = "Sorts bags"

-- ldb:
L['ACTION_ABORT'] = "Abort"
L['ACTION_COMPRESSBAGS'] = "Compress stacks in bags"
L['ACTION_COMPRESSBANK'] = "Compress stacks in bank"
L['ACTION_SORTBAGS'] = "Sort Bags"
L['ACTION_SORTBANK'] = "Sort Bank"
L['ACTION_STACKBAGS'] = "Stack from bank to bags"
L['ACTION_STACKBANK'] = "Stack from bags to bank"

L['KEYBIND_CLICK'] = "Click"
L['KEYBIND_CLICK_WHILE_STACKING'] = "Click while stacking"
L['KEYBIND_NONE'] = "None"
L['KEYBIND_PREFIX_ALT'] = "Alt-"
L['KEYBIND_PREFIX_CTRL'] = "Ctrl-"
L['KEYBIND_PREFIX_SHIFT'] = "Shift-"

L['CHAT_MSG_ABORTED'] = "BankStack: Aborted."
L['CHAT_MSG_TO_MOVE_NOPREFIX'] = "%d moves to make."

L['OPTIONS_SHOW_MINIMAP_ICON'] = "Show minimap icon"
L['OPTIONS_SHOW_MINIMAP_ICON_DESCRIPTION'] = "Toggle showing or hiding the minimap icon."
