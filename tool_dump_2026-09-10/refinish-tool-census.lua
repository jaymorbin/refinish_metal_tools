-- refinish-tool-census.lua
-- ==========================================
-- TOOL ITEM CENSUS
-- ==========================================
-- A runnable script, not a module. Type this at the DFHack console:
--
--     refinish-tool-census
--     refinish-tool-census MAKING_FUEL_
--
-- Answers two questions.
--
-- 1. HOW IS item_toolst.subtype STORED?
--
--    Either a plain index into world.raws.itemdefs.tools, or a pointer
--    to the itemdef itself. Which one decides how much save protocol
--    work tool injection needs, and it is the single most important
--    unknown in the tool system.
--
--    This does not need any module content. Every fort is full of jugs
--    and large pots, and a vanilla tool answers the question exactly as
--    well as an injected one.
--
-- 2. HOW MANY ITEMS CARRY AN INJECTED SUBTYPE?
--
--    Only meaningful once a module actually makes tools. Zero is the
--    correct and expected answer before then, which is why question 1
--    is deliberately answered first and separately.
--
--    Above zero means those items must be washed onto a vanilla subtype
--    and recorded in the payload before clear_tools() runs, the same
--    way refinish-save washes materials to a vanilla index.
--
-- Prints to the console rather than the RM log because this is run by
-- hand from a paused game and read immediately, which is the one case
-- where the console is the right place for it.
-- ==========================================

local args = {...}
local PREFIX = args[1]

local TOOL = df.item_type.TOOL
local defs = df.global.world.raws.itemdefs.tools


-- ==========================================
-- QUESTION 1: STORAGE SHAPE
-- ==========================================
-- Finds the first tool item in the world and dissects how its subtype
-- is stored. Stops at the first one: every tool item stores it the same
-- way, so a sample of one is the whole answer.
-- ==========================================

print("")
print("=== TOOL SUBTYPE STORAGE ===")

local sample = nil
for _, item in ipairs(df.global.world.items.all) do
    local ok, itype = pcall(function() return item:getType() end)
    if ok and itype == TOOL then
        sample = item
        break
    end
end

if not sample then
    print("  No tool items in this fort at all.")
    print("  Make a jug or a large pot and run this again.")
else
    -- The accessor first. It normalises to a number whatever the
    -- underlying storage is, so it is the safe way to READ.
    local ok_acc, acc = pcall(function() return sample:getSubtype() end)
    print(string.format("  getSubtype()      %s",
        ok_acc and tostring(acc) or "FAILED"))

    -- The raw field is what tells us the storage shape, and therefore
    -- how a WRITE has to be performed.
    local ok_raw, raw = pcall(function() return sample.subtype end)
    if not ok_raw then
        print("  .subtype          NOT READABLE")
    elseif type(raw) == "number" then
        print(string.format("  .subtype          number  %d", raw))
        print("")
        print("  VERDICT: plain index.")
        print("  Tools are EASIER than materials. No buildings or")
        print("  constructions reference this array, so the ledger's")
        print("  item pass is the whole job. No wash and restore needed.")
    else
        print(string.format("  .subtype          %s", type(raw)))
        local ok_id, id = pcall(function() return raw.id end)
        local ok_sub, sub = pcall(function() return raw.subtype end)
        if ok_id then print(string.format("  .subtype.id       %s", tostring(id))) end
        if ok_sub then print(string.format("  .subtype.subtype  %s", tostring(sub))) end
        print("")
        print("  VERDICT: pointer to the itemdef.")
        print("  Clearing tools before a save leaves every affected item")
        print("  dangling. Items carrying an injected subtype MUST be")
        print("  washed onto a vanilla subtype and recorded in the")
        print("  payload before clear_tools() runs. Do not save a fort")
        print("  you care about until that exists.")
    end
end


-- ==========================================
-- QUESTION 2: OWNED ITEM COUNT
-- ==========================================
-- Skipped entirely when no prefix is given, because counting items of
-- an unspecified owner is meaningless.
-- ==========================================

print("")
print("=== INJECTED TOOLS IN THE ARRAY ===")

-- Which array positions belong to the prefix, if one was given.
local owned = {}
local owned_count = 0

for i, td in ipairs(defs) do
    local ok, id = pcall(function() return td.id end)
    if ok and type(id) == "string" then
        if PREFIX and string.sub(id, 1, #PREFIX) == PREFIX then
            owned[i] = id
            owned_count = owned_count + 1
            print(string.format("  [%3d] %s", i, id))
        end
    end
end

print(string.format("  %d tools in the array, %d owned by %s.",
    #defs, owned_count, PREFIX or "(no prefix given)"))

if not PREFIX then
    print("")
    print("  Pass a prefix to count items, e.g. MAKING_FUEL_")
    return
end

if owned_count == 0 then
    print("")
    print("  Nothing injected. If you expected tools here, the tools")
    print("  JSON is not being loaded or inject_tools never ran.")
    return
end


-- ---- COUNT ITEMS ----
-- Read through the accessor, which works regardless of storage shape.

print("")
print("=== ITEMS CARRYING AN INJECTED SUBTYPE ===")

local total = 0
local by_tool = {}

for _, item in ipairs(df.global.world.items.all) do
    local ok_t, itype = pcall(function() return item:getType() end)
    if ok_t and itype == TOOL then
        local ok_s, sub = pcall(function() return item:getSubtype() end)
        local id = ok_s and owned[sub]
        if id then
            total = total + 1
            by_tool[id] = (by_tool[id] or 0) + 1
        end
    end
end

if total == 0 then
    print("  None. Clearing tools is safe with no payload work.")
else
    for id, n in pairs(by_tool) do
        print(string.format("  %-34s %d", id, n))
    end
    print("")
    print(string.format("  %d items total. These must be in the payload", total))
    print("  before clear_tools() runs.")
end
