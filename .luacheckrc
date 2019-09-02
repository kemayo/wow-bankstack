std = "lua51"
max_line_length = false
exclude_files = {
    "lib/",
    ".luacheckrc"
}

ignore = {
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "311", -- Value assigned to a local variable is unused
    "542", -- empty if branch
}

globals = {
    "BankStack",
    "BankStackDB",
    "BINDING_HEADER_BANKSTACK_HEAD",
    "BINDING_NAME_BANKSTACK",
    "BINDING_NAME_COMPRESS",
    "BINDING_NAME_BAGSORT",
    "SLASH_BANKSTACK1",
    "SLASH_BANKSTACKCONFIG1",
    "SLASH_BANKSTACKDEBUG1",
    "SLASH_COMPRESSBAGS1",
    "SLASH_COMPRESSBAGS2",
    "SLASH_FILL1",
    "SLASH_FILL2",
    "SLASH_SHUFFLE1",
    "SLASH_SHUFFLE2",
    "SLASH_SORT1",
    "SLASH_SORT2",
    "SLASH_SQUASH1",
    "SLASH_SQUASH2",

    "SlashCmdList",
    "StaticPopupDialogs",
    "UpdateContainerFrameAnchors",
}

read_globals = {
    "bit",
    "ceil", "floor",
    "mod",
    "strtrim",
    "tinsert",
    "wipe", "copy",
    "string", "tostringall",

    -- our own globals

    -- misc custom, third party libraries
    "LibStub", "tekDebug",

    -- API functions
    "BankButtonIDToInvSlotID",
    "ContainerIDToInventoryID",
    "ReagentBankButtonIDToInvSlotID",
    "GetAuctionItemSubClasses",
    "GetBuildInfo",
    "GetBackpackAutosortDisabled",
    "GetBagSlotFlag",
    "GetBankAutosortDisabled",
    "GetBankBagSlotFlag",
    "GetContainerNumFreeSlots",
    "GetContainerNumSlots",
    "GetContainerItemID",
    "GetContainerItemInfo",
    "GetContainerItemLink",
    "GetCurrentGuildBankTab",
    "GetCursorInfo",
    "GetGuildBankItemInfo",
    "GetGuildBankItemLink",
    "GetGuildBankTabInfo",
    "GetGuildBankNumSlots",
    "GetInventoryItemLink",
    "GetItemClassInfo",
    "GetItemFamily",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetTime",
    "InCombatLockdown",
    "IsAltKeyDown",
    "IsControlKeyDown",
    "IsShiftKeyDown",
    "IsReagentBankUnlocked",
    "PickupContainerItem",
    "PickupGuildBankItem",
    "QueryGuildBankTab",
    "SplitContainerItem",
    "SplitGuildBankItem",
    "UnitIsAFK",
    "UnitName",

    -- FrameXML frames
    "BankFrame",
    "GameTooltip",
    "UIParent",
    "WorldFrame",
    "DEFAULT_CHAT_FRAME",
    "GameFontHighlightSmall",

    -- FrameXML API
    "CreateFrame",
    "InterfaceOptionsFrame_OpenToCategory",
    "ToggleDropDownMenu",
    "UIDropDownMenu_AddButton",
    "UISpecialFrames",
    "ScrollingEdit_OnCursorChanged",
    "ScrollingEdit_OnUpdate",

    -- FrameXML Constants
    "BACKPACK_CONTAINER",
    "BACKPACK_TOOLTIP",
    "BAG_CLEANUP_BAGS",
    "BAG_FILTER_ICONS",
    "BAGSLOT",
    "BANK",
    "BANK_BAG_PURCHASE",
    "BANK_CONTAINER",
    "CONFIRM_BUY_BANK_SLOT",
    "EQUIP_CONTAINER",
    "ITEM_BIND_QUEST",
    "ITEM_BNETACCOUNTBOUND",
    "ITEM_CONJURED",
    "ITEM_SOULBOUND",
    "LE_BAG_FILTER_FLAG_EQUIPMENT",
    "LE_BAG_FILTER_FLAG_IGNORE_CLEANUP",
    "LE_ITEM_CLASS_WEAPON",
    "LE_ITEM_CLASS_ARMOR",
    "LE_ITEM_CLASS_CONTAINER",
    "LE_ITEM_CLASS_GEM",
    "LE_ITEM_CLASS_ITEM_ENHANCEMENT",
    "LE_ITEM_CLASS_CONSUMABLE",
    "LE_ITEM_CLASS_GLYPH",
    "LE_ITEM_CLASS_TRADEGOODS",
    "LE_ITEM_CLASS_RECIPE",
    "LE_ITEM_CLASS_BATTLEPET",
    "LE_ITEM_CLASS_QUESTITEM",
    "LE_ITEM_CLASS_MISCELLANEOUS",
    "LE_ITEM_QUALITY_POOR",
    "MAX_CONTAINER_ITEMS",
    "NEW_ITEM_ATLAS_BY_QUALITY",
    "NO",
    "NUM_BAG_SLOTS",
    "NUM_BANKBAGSLOTS",
    "NUM_CONTAINER_FRAMES",
    "NUM_LE_BAG_FILTER_FLAGS",
    "RAID_CLASS_COLORS",
    "REAGENT_BANK",
    "REAGENTBANK_CONTAINER",
    "REAGENTBANK_DEPOSIT",
    "REMOVE",
    "SOUNDKIT",
    "STATICPOPUP_NUMDIALOGS",
    "TEXTURE_ITEM_QUEST_BANG",
    "TEXTURE_ITEM_QUEST_BORDER",
    "UIDROPDOWNMENU_MENU_VALUE",
    "YES",
}
