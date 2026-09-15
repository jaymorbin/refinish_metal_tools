-- refinish-fuel-testbed.lua
-- ==========================================
-- MAKING FUEL: TEST BENCH
-- ==========================================
-- Spawns a sample of every item the char and split reactions accept,
-- so all 122 adaptive reactions can be exercised in one sitting
-- instead of waiting for a fort to produce each input naturally.
--
-- USAGE
--   refinish-fuel-testbed              everything it can make
--   refinish-fuel-testbed furniture    just the furniture family
--   refinish-fuel-testbed craft        crafts, toys, instruments
--   refinish-fuel-testbed tool         vanilla tools and mod fuel tools
--   refinish-fuel-testbed fuel         only the mod's own fuel tools
--   refinish-fuel-testbed list         print what it WOULD make, spawn
--                                      nothing
--
--   refinish-fuel-testbed <group> 4    spawn 4 of each instead of 2
--
-- WHERE THINGS LAND
--   At the selected unit if one is selected, otherwise at the first
--   citizen it finds. Items drop at that unit's feet.
--
-- WHAT IT CANNOT MAKE, and why
--   Corpses, corpse pieces, remains, bones, skulls, hides and totems
--   are creature derived. createItem cannot build a corpse with a
--   sensible race, caste and body part layout, and a half built one
--   would test the valuer against a shape the game never produces.
--   Kill and butcher something instead; those paths are also the ones
--   already confirmed working.
--
--   Meat, fish, cheese, eggs, plants and seeds need a specific
--   creature or plant material rather than wood, so they are spawned
--   only if a suitable material turns up in the fort.
-- ==========================================

local BUILD = 'T1'

local args     = {...}
local mode     = (args[1] or 'all'):lower()
local per_kind = tonumber(args[2]) or 2

print('')
print('refinish-fuel-testbed  build ' .. BUILD)

-- ==========================================
-- WHERE TO PUT THINGS
-- ==========================================
-- createItem needs a unit: the item is created as though that unit
-- made it and lands at their feet.
-- ==========================================
local function find_unit()
    local u = nil
    pcall(function() u = dfhack.gui.getSelectedUnit(true) end)
    if u then return u, 'selected unit' end

    pcall(function()
        for _, unit in ipairs(df.global.world.units.active) do
            if dfhack.units.isCitizen(unit)
               and not unit.flags1.dead then
                u = unit
                return
            end
        end
    end)
    if u then return u, 'first citizen' end
    return nil, nil
end

-- ==========================================
-- MATERIALS
-- ==========================================
-- Three woods spanning the density range where possible, so a single
-- test run shows the density factor doing its job rather than one
-- species repeated. Matched on the material's own id, because a
-- plant's material vector holds STRUCTURAL, LEAF and DRINK too and
-- the wood is not reliably at index 0. Olive keeps its wood at index
-- 3 while every other species uses 1.
-- ==========================================
local function find_woods()
    local found = {}
    local n = 0
    pcall(function() n = #df.global.world.raws.plants.all end)

    for i = 0, n - 1 do
        local p = df.global.world.raws.plants.all[i]
        local nm = 0
        pcall(function() nm = #p.material end)
        for j = 0, nm - 1 do
            local m = nil
            pcall(function() m = p.material[j] end)
            local id = nil
            pcall(function() id = tostring(m.id) end)
            if id == 'WOOD' then
                local d = 0
                pcall(function() d = m.solid_density end)
                table.insert(found, {
                    name  = tostring(p.id),
                    dens  = d,
                    -- Plant materials are addressed as mat_type
                    -- 419 + material index, with mat_index being the
                    -- plant. Resolved through matinfo rather than
                    -- arithmetic so the numbers are DF's, not mine.
                    mi    = dfhack.matinfo.find(
                                'PLANT:' .. tostring(p.id) .. ':WOOD'),
                })
                break
            end
        end
    end

    -- Keep only species whose token actually resolved.
    local ok = {}
    for _, w in ipairs(found) do
        if w.mi then table.insert(ok, w) end
    end
    table.sort(ok, function(a, b) return a.dens < b.dens end)

    if #ok == 0 then return {} end
    if #ok <= 3 then return ok end
    -- Lightest, middle, heaviest. The spread is the point.
    return { ok[1], ok[math.floor(#ok / 2)], ok[#ok] }
end

-- ==========================================
-- SUBTYPE LOOKUP
-- ==========================================
-- Tools, toys, instruments and trap components are all defined by
-- itemdefs rather than by the item type alone. Resolved by scanning
-- for an id containing the given fragment, so nothing here depends on
-- an exact raw token that a mod or a DF version might rename.
--
-- Returns subtype index and the id that matched, or nil.
-- ==========================================
local function find_subtype(list_name, fragment)
    local idx, id = nil, nil
    pcall(function()
        local list = df.global.world.raws.itemdefs[list_name]
        for i = 0, #list - 1 do
            local d = list[i]
            local this = tostring(d.id):upper()
            if this:find(fragment:upper(), 1, true) then
                idx, id = i, this
                return
            end
        end
    end)
    return idx, id
end

-- ==========================================
-- WHAT TO SPAWN
-- ==========================================
-- type      item_type name, as it appears in df.item_type
-- defs      itemdef list to search for a subtype, or nil for none
-- match     fragment of the itemdef id to look for
-- group     which mode switch includes it
--
-- The furniture block covers the single type char reactions, which
-- are the largest untested block: 41 reactions that each gave a flat
-- 1 charcoal before and now scale on volume.
-- ==========================================
local SPEC = {
    -- ---- RAW STOCK ----
    { group = 'furniture', type = 'WOOD' },

    -- ---- FURNITURE, plain types with no subtype ----
    { group = 'furniture', type = 'CHAIR' },
    { group = 'furniture', type = 'TABLE' },
    { group = 'furniture', type = 'BED' },
    { group = 'furniture', type = 'DOOR' },
    { group = 'furniture', type = 'FLOODGATE' },
    { group = 'furniture', type = 'HATCH_COVER' },
    { group = 'furniture', type = 'GRATE' },
    { group = 'furniture', type = 'CABINET' },
    { group = 'furniture', type = 'BOX' },
    { group = 'furniture', type = 'BIN' },
    { group = 'furniture', type = 'ARMORSTAND' },
    { group = 'furniture', type = 'WEAPONRACK' },
    { group = 'furniture', type = 'COFFIN' },
    { group = 'furniture', type = 'BUCKET' },
    { group = 'furniture', type = 'BARREL' },
    { group = 'furniture', type = 'ANIMALTRAP' },
    { group = 'furniture', type = 'CAGE' },
    { group = 'furniture', type = 'BLOCKS' },
    { group = 'furniture', type = 'GOBLET' },
    { group = 'furniture', type = 'TRACTION_BENCH' },
    { group = 'furniture', type = 'SLAB' },
    { group = 'furniture', type = 'STATUE' },

    -- ---- CRAFTS AND FINISHED GOODS ----
    { group = 'craft', type = 'FIGURINE' },
    { group = 'craft', type = 'AMULET' },
    { group = 'craft', type = 'EARRING' },
    { group = 'craft', type = 'RING' },
    { group = 'craft', type = 'BRACELET' },
    { group = 'craft', type = 'CROWN' },
    { group = 'craft', type = 'SCEPTER' },
    { group = 'craft', type = 'CHAIN' },
    { group = 'craft', type = 'CRUTCH' },
    { group = 'craft', type = 'SPLINT' },
    { group = 'craft', type = 'QUIVER' },
    { group = 'craft', type = 'BACKPACK' },
    { group = 'craft', type = 'FLASK' },

    -- ---- TOYS AND INSTRUMENTS, itemdef driven ----
    { group = 'craft', type = 'TOY',        defs = 'toys',        match = '' },
    { group = 'craft', type = 'INSTRUMENT', defs = 'instruments', match = '' },

    -- ---- TRAP COMPONENTS ----
    -- Menacing spike, spiked ball and enormous corkscrew are all
    -- TRAPCOMP subtypes rather than item types of their own.
    { group = 'craft', type = 'TRAPCOMP', defs = 'trapcomps', match = 'SPIKE' },
    { group = 'craft', type = 'TRAPCOMP', defs = 'trapcomps', match = 'CORKSCREW' },
    { group = 'craft', type = 'TRAPCOMP', defs = 'trapcomps', match = 'BALL' },

    -- ---- VANILLA TOOLS ----
    -- The CHAR_HAS_* reactions select on tool_use rather than on
    -- subtype, so any handful of real tools exercises them.
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'JUG' },
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'NEST_BOX' },
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'HIVE' },
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'BOOKCASE' },
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'STEPLADDER' },
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'WHEELBARROW' },
    { group = 'tool', type = 'TOOL', defs = 'tools', match = 'MINECART' },

    -- ---- THE MOD'S OWN FUEL TOOLS ----
    -- These feed CHAR_KINDLING, CHAR_BRANCHES, CHAR_CINDERS and the
    -- rest. Kindling in particular is the one to watch: at
    -- KINDLING_VOLUME 78 four of them should be worth one charcoal.
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_KINDLING' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_BRANCH' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_CINDER' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_DUNG' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_STRAW' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_SAWDUST' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_BARK' },
    { group = 'fuel', type = 'TOOL', defs = 'tools', match = 'MAKING_FUEL_PRESS_CAKE' },
}

-- ==========================================
-- RUN
-- ==========================================
local function wanted(g)
    if mode == 'all' or mode == 'list' then return true end
    return mode == g
end

local unit, how = find_unit()
if not unit and mode ~= 'list' then
    print('  No unit found to spawn against. Select a dwarf and retry.')
    return
end
if unit then
    print('  Spawning at: ' .. tostring(how))
end

local woods = find_woods()
if #woods == 0 and mode ~= 'list' then
    print('  No plant wood materials resolved. Nothing can be made.')
    return
end
print('  Woods in use:')
for _, w in ipairs(woods) do
    print(string.format('    %-18s density %d', w.name, w.dens))
end
print('')

local made, failed, skipped = 0, {}, 0

for _, spec in ipairs(SPEC) do
    if wanted(spec.group) then
        local itype = nil
        pcall(function() itype = df.item_type[spec.type] end)

        if not itype then
            table.insert(failed, spec.type .. '  (no such item type)')
        else
            -- Resolve the subtype first. A missing itemdef is a clean
            -- skip rather than a failure: not every DF version or mod
            -- set has every tool.
            local sub, subid = -1, nil
            local ok_sub = true
            if spec.defs then
                sub, subid = find_subtype(spec.defs, spec.match)
                if not sub then ok_sub = false end
            end

            if not ok_sub then
                skipped = skipped + 1
                table.insert(failed, string.format(
                    '%s  (no itemdef matching "%s" in %s)',
                    spec.type, spec.match, spec.defs))
            elseif mode == 'list' then
                print(string.format('  would make %d x %-16s %s',
                    per_kind, spec.type, subid and ('[' .. subid .. ']') or ''))
                made = made + 1
            else
                local n_ok = 0
                for i = 1, per_kind do
                    -- Rotate the wood so a run shows several densities.
                    local w = woods[((i - 1) % #woods) + 1]
                    local ok_c = pcall(function()
                        local items = dfhack.items.createItem(
                            unit, itype, sub, w.mi.type, w.mi.index)
                        if items and #items > 0 then n_ok = n_ok + 1 end
                    end)
                    if not ok_c then break end
                end
                if n_ok > 0 then
                    made = made + n_ok
                    print(string.format('  made %d x %-16s %s',
                        n_ok, spec.type,
                        subid and ('[' .. subid .. ']') or ''))
                else
                    table.insert(failed, spec.type
                        .. (subid and (' [' .. subid .. ']') or '')
                        .. '  (createItem refused)')
                end
            end
        end
    end
end

print('')
print('==========================================')
print(string.format('  %d item(s) made, %d kind(s) unavailable', made, #failed))
if #failed > 0 then
    print('')
    for _, f in ipairs(failed) do print('    ' .. f) end
    print('')
    print('  Unavailable is usually fine: it means this DF version or')
    print('  mod set has no such itemdef. A createItem refusal on a')
    print('  plain furniture type is worth a look.')
end
print('')
print('  NOT COVERED, spawn these the normal way:')
print('    corpses, corpse pieces, remains, bones, skulls, hides,')
print('    totems, meat, fish, cheese, eggs, plants, seeds.')
print('    Creature and plant derived items need a real source, and')
print('    a hand built corpse would test the valuer against a shape')
print('    the game never produces.')
print('')
print('  Then queue char and split jobs and watch at log level 1:')
print('    :lua refinish_fuel_loglevel = 1')
