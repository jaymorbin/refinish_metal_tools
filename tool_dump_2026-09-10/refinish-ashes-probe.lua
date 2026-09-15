-- refinish-ashes-probe.lua
-- =====================================================================
-- CAN CREMATION PRODUCE A BURYABLE, NAMED OBJECT
-- =====================================================================
-- Three questions, none answerable from outside the game, and the
-- design depends on all three. READ ONLY: nothing is created, written
-- or removed.
--
--   1. WHAT WILL A COFFIN TAKE? If burial only accepts corpse items,
--      then no reaction output can ever be interred and the whole
--      "ashes in a coffin" shape is closed. This reads a real coffin
--      if one is built and the burial code around it either way.
--
--   2. CAN AN ITEM CARRY A NAME OF ITS OWN? A material name is the
--      only naming the module has today, and one material per dead
--      dwarf grows the arrays for the life of the fort. If an item
--      type carries its own text, the name costs nothing.
--      `item_slabst` is the candidate: DF engraves the dead onto
--      slabs, and a slab laid in a tomb settles a ghost.
--
--   3. WHICH ITEM TYPES CAN A REACTION EVEN EMIT? The schema knows 70
--      product types and SLAB is not among them. That is a schema
--      limit, not necessarily a DF one, and the two are different
--      problems with different costs.
--
-- USAGE
--   refinish-ashes-probe            all three
--   refinish-ashes-probe coffin     what a coffin holds
--   refinish-ashes-probe name       which item types carry their own text
--   refinish-ashes-probe product    what a reaction product can be
-- =====================================================================

--@ module = true

local args = {...}
local mode = args[1] or 'all'

local function out(s)
    print(s)
    if _G.refinish_log_event then _G.refinish_log_event('ASHES: ' .. s) end
end
local function head(s) out('') out('---- ' .. s .. ' ----') end

-- Enums walk by index; pairs() on a DFHack TYPE returns its metatable.
local function enum_names(t)
    local n = {}
    pcall(function()
        for i = t._first_item, t._last_item do
            local v = t[i]
            if v then n[#n + 1] = tostring(v) end
        end
    end)
    return n
end

local function wrap(list, indent)
    local line = indent
    for _, v in ipairs(list) do
        if #line + #v + 2 > 68 then out(line) line = indent end
        line = line .. ' ' .. v
    end
    if line:match('%S') then out(line) end
end

-- ---------------------------------------------------------------------
-- 1. WHAT A COFFIN HOLDS
-- ---------------------------------------------------------------------
local function coffin()
    head('1. what a coffin will take')

    local found = 0
    pcall(function()
        for _, b in ipairs(df.global.world.buildings.all) do
            local ok = false
            pcall(function()
                ok = b:getType() == df.building_type.Coffin
            end)
            if ok then
                found = found + 1
                out(('  coffin, building %d'):format(b.id))
                -- Whatever it is holding right now, by ITEM TYPE. This
                -- is the question: is anything in there that is not a
                -- corpse or a body part?
                pcall(function()
                    local n = #b.contained_items
                    out(('    contained_items: %d'):format(n))
                    for _, ci in ipairs(b.contained_items) do
                        local it = ci.item
                        local d = '?'
                        pcall(function()
                            d = dfhack.items.getDescription(it, 0, true)
                        end)
                        out(('      %-32s %s'):format(
                            tostring(d):sub(1, 32),
                            tostring(df.item_type[it:getType()])))
                    end
                end)
                -- The burial settings the player toggles.
                pcall(function()
                    local f = b.burial_mode
                    local set = {}
                    for k, v in pairs(f) do
                        if v == true then set[#set + 1] = tostring(k) end
                    end
                    out(('    burial_mode set: %s'):format(
                        #set > 0 and table.concat(set, ', ') or '(none)'))
                end)
            end
        end
    end)
    if found == 0 then
        out('  no coffin built. Build one, put something in it if you')
        out('  can, and re-run. An empty coffin still answers less than')
        out('  a used one.')
    end

    out('')
    out('  every building_type, looking for an urn or a second')
    out('  container for the dead:')
    local bt = enum_names(df.building_type)
    local hits = {}
    for _, n in ipairs(bt) do
        local l = n:lower()
        if l:find('coffin') or l:find('urn') or l:find('tomb')
           or l:find('grave') or l:find('casket') then
            hits[#hits + 1] = n
        end
    end
    wrap(#hits > 0 and hits or { '(none besides Coffin)' }, '   ')

    out('')
    out('  WHAT TO READ: if contained_items only ever holds CORPSE and')
    out('  CORPSEPIECE, no reaction output can be interred and the')
    out('  ashes cannot go in a coffin at all. That closes the shape')
    out('  rather than making it expensive.')
end

-- ---------------------------------------------------------------------
-- 2. WHICH ITEMS CARRY THEIR OWN TEXT
-- ---------------------------------------------------------------------
-- A material name is the only naming the module has, and one material
-- per cremation grows the arrays for the life of the fort. An item
-- type with its own string field costs nothing per corpse.
local function name_fields()
    head('2. item types that carry their own text')

    local WANT = { 'description', 'name', 'title', 'engraving',
                   'topic', 'subtitle', 'caption' }
    local hits = 0
    pcall(function()
        for k, v in pairs(df) do
            local n = tostring(k)
            if n:match('^item_%a+st$') then
                local fields = {}
                pcall(function()
                    for _, f in ipairs(v._fields) do
                        for _, w in ipairs(WANT) do
                            if f.name == w then fields[#fields + 1] = f.name end
                        end
                    end
                end)
                if #fields > 0 then
                    hits = hits + 1
                    out(('  %-22s %s'):format(n, table.concat(fields, ', ')))
                end
            end
        end
    end)
    if hits == 0 then
        out('  none found. Every item name would have to come from its')
        out('  MATERIAL, which means one injected material per dead')
        out('  dwarf.')
    end

    out('')
    out('  and the slab, in full, since it is the candidate:')
    local ok = false
    pcall(function()
        for _, f in ipairs(df.item_slabst._fields) do
            out('    ' .. f.name)
            ok = true
        end
    end)
    if not ok then out('    df.item_slabst does not exist under that name') end

    out('')
    out('  WHAT TO READ: a free text field on an item type means the')
    out('  name is per ITEM and costs nothing. No field anywhere means')
    out('  the name has to be a material, one per cremation, injected')
    out('  at runtime and carried by the ledger forever.')
end

-- ---------------------------------------------------------------------
-- 3. WHAT A REACTION PRODUCT CAN BE
-- ---------------------------------------------------------------------
local function product()
    head('3. what a reaction product can be')

    out('  df.reaction_product_type:')
    wrap(enum_names(df.reaction_product_type), '   ')

    out('')
    out('  and the fields on a reaction product item:')
    local ok = false
    pcall(function()
        for _, f in ipairs(df.reaction_product_itemst._fields) do
            out('    ' .. f.name)
            ok = true
        end
    end)
    if not ok then out('    could not read reaction_product_itemst') end

    out('')
    out('  WHAT TO READ: the schema knows 70 product types and SLAB is')
    out('  not one of them. If item_type here is a plain item_type')
    out('  field then SLAB is a schema gap and cheap to close. If')
    out('  products are a restricted set, it is a DF limit and is not.')
end

-- ---------------------------------------------------------------------
if mode == 'all' or mode == 'coffin'  then coffin() end
if mode == 'all' or mode == 'name'    then name_fields() end
if mode == 'all' or mode == 'product' then product() end
