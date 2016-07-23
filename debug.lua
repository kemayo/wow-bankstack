local myname, ns = ...

local core = BankStack
local Debug = core.Debug

local encode_bagslot = core.encode_bagslot
local bag_ids = core.bag_ids
local bag_stacks = core.bag_stacks
local bag_maxstacks = core.bag_maxstacks

local function createtex(parent, layer, w, h, ...)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetWidth(w) tex:SetHeight(h)
    tex:SetPoint(...)
    return tex
end

local frame
local function getFrame()
    if not frame then
        local name = myname .. 'DebugFrame'
        frame = CreateFrame("Frame", name, UIParent, "UIPanelDialogTemplate")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetWidth(832)
        frame:SetHeight(447)
        frame:SetPoint("TOPLEFT", 0, -104)

        frame:Hide()

        frame.title:SetText(myname)

        local titlebg = _G[name .. 'TitleBG']
        local titlebutton = CreateFrame("Frame", nil, frame)
        titlebutton:SetPoint("TOPLEFT", titlebg)
        titlebutton:SetPoint("BOTTOMRIGHT", titlebg)
        titlebutton:EnableMouse(true)
        titlebutton:RegisterForDrag("LeftButton")
        titlebutton:SetScript("OnDragStart", function(self)
            frame.moving = true
            frame:StartMoving()
        end)
        titlebutton:SetScript("OnDragStop", function(self)
            frame.moving = nil
            frame:StopMovingOrSizing()
        end)

        local scrollframe = CreateFrame("ScrollFrame", name .. "ScrollFrame", frame, "UIPanelScrollFrameTemplate")
        scrollframe:SetWidth(832 - 41)
        scrollframe:SetHeight(447 - 41)
        scrollframe:SetPoint("TOPLEFT", 12, -30)

        local editbox = CreateFrame("EditBox", name .. "Text", scrollframe)
        editbox:SetWidth(scrollframe:GetWidth())
        editbox:SetHeight(scrollframe:GetHeight())
        editbox:SetFontObject(GameFontHighlightSmall)
        editbox:SetMultiLine(true)
        editbox:SetAutoFocus(false)

        editbox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
        editbox:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, self:GetParent()) end)
        editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText(0) end)
        editbox:SetScript("OnEscapePressed", editbox.ClearFocus)

        scrollframe:SetScrollChild(editbox)

        frame.scrollframe = scrollframe
        frame.editbox = editbox
    end
    frame.editbox:SetText("")
    return frame
end

SlashCmdList["BANKSTACKDEBUG"] = core.CommandDecorator(function(bags)
    local frame = getFrame()

    for i, bag, slot in core.IterateBags(bags, nil, "both") do
        local bagslot = encode_bagslot(bag, slot)
        local itemid = bag_ids[bagslot]
        if itemid then
            local name, _, rarity, level, _, _, _, _, equipLoc, _, price, class, subClass = GetItemInfo(itemid)

            frame.editbox:Insert(("%d | %d.%d | %d | %s | %d/%d | %d | %d | %s | %d | %d.%d\n"):format(i, bag, slot, itemid, name, bag_stacks[bagslot], bag_maxstacks[bagslot], rarity, level, equipLoc, price, class, subClass))
        else
            frame.editbox:Insert(("%d | %d.%d | EMPTY\n"):format(i, bag, slot))
        end
        -- if (not core.db.ignore_bags[bag] and not core.db.ignore[bagslot]) then
            
        -- end
    end

    frame:Show()
    frame.scrollframe:SetVerticalScroll(0)
    frame.editbox:HighlightText(0)
    frame.editbox:SetCursorPosition(0)
end, 'bags', 1)
SLASH_BANKSTACKDEBUG1 = "/bankstackdebug"
