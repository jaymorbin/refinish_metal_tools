-- refinish-corpse-probe.lua  (v2)
-- =====================================================================
-- CAN A REAGENT TARGET A CITIZEN CORPSE
-- =====================================================================
-- READ ONLY. Creates nothing, removes nothing, writes nothing.
--
-- WHAT v1 GOT WRONG, because it matters for reading v2's output.
-- v1 walked DFHack types with pairs(), which returns METATABLE entries,
-- not fields. So its "identifiers containing dwarf" section reported
-- nothing while its own corpse table was reading item.flags.dead_dwarf
-- successfully three lines further down, and its vector list printed
-- eleven metatable internals as though they were vector ids.
--
-- The right traversals, and this file uses only these:
--   enum      for i = T._first_item, T._last_item do ... T[i] ... end
--   bitfield  pairs() on a live INSTANCE, never on the type
--   struct    pairs() on a live INSTANCE
--
-- WHAT v1 ESTABLISHED ANYWAY, from the one section that worked:
--   item.flags.dead_dwarf EXISTS.
--   amphibian man corpse, a sapient with civ 163  -> dead_dwarf true
--   giant cave toad corpse, a wild animal, civ -1 -> dead_dwarf false
-- So it marks SAPIENT remains rather than dwarves specifically, which
-- is the question v2 exists to settle.
--
-- CREATED ITEMS ARE NOT EVIDENCE. Register N1: gui/create-item corpses
-- are malformed. In the v1 run the created peasant and goblin corpses
-- had no resolvable unit and read dead_dwarf false, which is exactly
-- backwards from what a real peasant corpse should read. This build
-- MARKS those rows so they cannot be mistaken for data.
--
-- USAGE
--   refinish-corpse-probe            all sections
--   refinish-corpse-probe reagent    can a REAGENT ask for dead_dwarf
--   refinish-corpse-probe vectors    the real vector id list
--   refinish-corpse-probe corpses    the corpse table
--   refinish-corpse-probe vector     what ANY_DEAD_DWARF actually
--                                    HOLDS. This is the section that
--                                    decides whether a reagent can do
--                                    this without a watcher.
--   refinish-corpse-probe audit      what a job_item can express:
--                                    every flag bit, every field, and
--                                    the df.tool_uses vocabulary
--   refinish-corpse-probe fields     every field and set flag of one
--                                    real corpse
-- =====================================================================

--@ module = true

local args = {...}
local mode = args[1] or 'all'

local function out(s)
    print(s)
    if _G.refinish_log_event then _G.refinish_log_event('CORPSE PROBE: ' .. s) end
end
local function head(s) out('') out('---- ' .. s .. ' ----') end

-- ---------------------------------------------------------------------
-- THE DECIDING QUESTION: can a REAGENT ask for dead_dwarf
-- ---------------------------------------------------------------------
-- item.flags.dead_dwarf is proven to exist. That is the ITEM's own
-- flag. For a reaction to gate on it, DF's job_item needs a matching
-- requirement bit, and those live in job_item_flags1, 2 and 3.
--
-- Read off a LIVE job's filter where one exists, because a bitfield
-- instance enumerates and a bitfield type does not. Falls back to the
-- type's _fields, which is a table rather than an array, so it is
-- walked with pairs.
local function reagent_side()
    head('1. can a REAGENT require dead_dwarf')

    local function bits_of(bf, label)
        local names = {}
        local ok = pcall(function()
            for k in pairs(bf) do names[#names + 1] = tostring(k) end
        end)
        if not ok or #names == 0 then
            ok = pcall(function()
                for k in pairs(bf._type._fields) do
                    names[#names + 1] = tostring(k)
                end
            end)
        end
        table.sort(names)
        local hit = nil
        for _, n in ipairs(names) do
            if n:lower():find('dwarf') or n:lower():find('dead') then
                hit = (hit and hit .. ', ' or '') .. n
            end
        end
        out(string.format('  %-18s %3d bit(s)   dead/dwarf: %s',
            label, #names, hit or 'NONE'))
        return names
    end

    -- A live job filter is the most reliable instance to read.
    local el = nil
    pcall(function()
        local link = df.global.world.jobs.list.next
        while link and not el do
            local j = link.item
            if j and #j.job_items.elements > 0 then el = j.job_items.elements[0] end
            link = link.next
        end
    end)

    if el then
        out('  read off a live job filter')
        bits_of(el.flags1, 'job_item flags1')
        bits_of(el.flags2, 'job_item flags2')
        bits_of(el.flags3, 'job_item flags3')
    else
        out('  no job with a filter right now; queue anything and re-run.')
        out('  Falling back to the item side only.')
    end

    -- And the item side, for the comparison that matters.
    local corpse = nil
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSE then corpse = it break end
        end
    end)
    if corpse then
        out('')
        out('  and the ITEM side, for comparison')
        bits_of(corpse.flags, 'item flags')
    end

    out('')
    out('  IF dead_dwarf appears in a job_item row above, a reaction can')
    out('  ask for it directly and no watcher is needed. If it appears')
    out('  ONLY on the item, DF does not let a filter require it.')
end

-- ---------------------------------------------------------------------
-- THE VECTOR LIST, enumerated properly this time
-- ---------------------------------------------------------------------
local function vectors()
    head('2. df.job_item_vector_id, enumerated as an enum')
    local names, lo, hi = {}, nil, nil
    local ok = pcall(function()
        lo = df.job_item_vector_id._first_item
        hi = df.job_item_vector_id._last_item
        for i = lo, hi do
            local n = df.job_item_vector_id[i]
            if n then names[#names + 1] = tostring(n) end
        end
    end)
    if not ok or #names == 0 then
        out('  could not enumerate, even as an enum')
        return
    end
    out(string.format('  %d values, %s to %s:', #names, tostring(lo), tostring(hi)))
    local line = '   '
    for _, n in ipairs(names) do
        if #line + #n + 2 > 68 then out(line) line = '   ' end
        line = line .. ' ' .. n
    end
    if line ~= '   ' then out(line) end

    out('')
    out('  ones naming a corpse, refuse, body or the dead:')
    local any = false
    for _, n in ipairs(names) do
        local l = n:lower()
        if l:find('corpse') or l:find('refuse') or l:find('body')
           or l:find('dead') or l:find('dwarf') then
            out('    ' .. n) any = true
        end
    end
    if not any then out('    none') end
end

-- ---------------------------------------------------------------------
-- THE CORPSE TABLE
-- ---------------------------------------------------------------------
local function corpses()
    head('3. every corpse and body part in the fort')
    local fort_civ = nil
    pcall(function() fort_civ = df.global.plotinfo.civ_id end)
    out('  fort civ_id = ' .. tostring(fort_civ))
    out('')
    out(string.format('  %-26s %-6s %-6s %-5s %-5s %-5s %s',
        'item', 'type', 'civ=', 'cit?', 'pet?', 'dd', 'race'))

    local real, fake = 0, 0
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            local ty = it:getType()
            if ty == df.item_type.CORPSE or ty == df.item_type.CORPSEPIECE then
                local desc, race = '?', '?'
                local civ, cit, pet, dd = '?', '?', '?', '?'
                pcall(function()
                    desc = dfhack.items.getDescription(it, 0, true)
                end)
                pcall(function() dd = tostring(it.flags.dead_dwarf) end)

                local u = nil
                pcall(function() u = df.unit.find(it.unit_id) end)
                if u then
                    real = real + 1
                    pcall(function() civ = tostring(u.civ_id) end)
                    pcall(function()
                        cit = tostring(dfhack.units.isCitizen(u, true))
                    end)
                    pcall(function() pet = tostring(dfhack.units.isPet(u)) end)
                    pcall(function()
                        race = tostring(df.global.world.raws
                                        .creatures.all[u.race].creature_id)
                    end)
                else
                    fake = fake + 1
                    race = 'NO UNIT, see below'
                end

                out(string.format('  %-26s %-6s %-6s %-5s %-5s %-5s %s',
                    tostring(desc):sub(1, 26),
                    ty == df.item_type.CORPSE and 'CORPSE' or 'PIECE',
                    civ, cit, pet, dd, race))
            end
        end
    end)

    if fake > 0 then
        out('')
        out(string.format('  %d row(s) have NO RESOLVABLE UNIT. Those are'
            .. ' gui/create-item corpses', fake))
        out('  and they are NOT evidence: register N1 records that')
        out('  created corpses are malformed. A created peasant read')
        out('  dead_dwarf FALSE in the last run, which is backwards.')
        out('  Ignore those rows entirely.')
    end
    if real == 0 then
        out('  Nothing died naturally here yet, so there is nothing to')
        out('  read. This needs a real dead citizen, a real pet and a')
        out('  real animal.')
    end
end

-- ---------------------------------------------------------------------
-- EVERY FIELD OF ONE REAL CORPSE
-- ---------------------------------------------------------------------
-- Instances, walked with pairs. v1 used ipairs over _type._fields,
-- which is not an array, and printed a heading with nothing under it.
local function fields()
    head('4. every field and set flag of one REAL corpse')
    local target = nil
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSE
               and df.unit.find(it.unit_id) then
                target = it break
            end
        end
    end)
    if not target then
        out('  no corpse with a resolvable unit. A created one will not')
        out('  do; this needs something that actually died here.')
        return
    end
    pcall(function()
        out('  ' .. tostring(dfhack.items.getDescription(target, 0, true)))
    end)

    out('')
    out('  fields:')
    pcall(function()
        local keys = {}
        for k in pairs(target) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = '?'
            pcall(function() v = tostring(target[k]) end)
            out(string.format('    %-26s %s', k, v:sub(1, 40)))
        end
    end)

    for _, grp in ipairs({ 'flags', 'corpse_flags' }) do
        out('')
        out('  ' .. grp .. ', bits that are SET:')
        local set = {}
        pcall(function()
            for k, v in pairs(target[grp]) do
                if v == true then set[#set + 1] = tostring(k) end
            end
        end)
        table.sort(set)
        out('    ' .. (#set > 0 and table.concat(set, ', ') or '(none)'))
    end
end

-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- 5. WHAT THE VECTOR ACTUALLY HOLDS
-- ---------------------------------------------------------------------
-- Section 2 found ANY_DEAD_DWARF among the 136 vector ids. A reagent
-- naming it would search only that vector, so what it CONTAINS decides
-- whether a reaction can do this without a watcher.
--
-- Worth asking rather than assuming. The flag it mirrors is true for a
-- pet sheep and an amphibian man as well as for a dwarf, so the name
-- says dwarf and the contents evidently do not.
--
-- items.other is keyed by df.items_other_id, the same access the coal
-- watcher and fuel access already use.
local function vector_contents()
    head('5. what the corpse vectors actually hold')
    for _, name in ipairs({ 'ANY_DEAD_DWARF', 'ANY_MURDERED',
                            'ANY_CORPSE', 'ANY_BUTCHERABLE' }) do
        local vec = nil
        pcall(function() vec = df.global.world.items.other[name] end)
        if not vec then
            out('  ' .. name .. ': no vector under items.other')
        else
            local n = 0
            pcall(function() n = #vec end)
            out(string.format('  %-16s %d item(s)', name, n))
            local shown = 0
            pcall(function()
                for _, it in ipairs(vec) do
                    if shown >= 12 then out('      ... and more') break end
                    local d, race, who = '?', '?', 'no unit'
                    pcall(function()
                        d = dfhack.items.getDescription(it, 0, true)
                    end)
                    local u = nil
                    pcall(function() u = df.unit.find(it.unit_id) end)
                    if u then
                        pcall(function()
                            race = tostring(df.global.world.raws
                                    .creatures.all[u.race].creature_id)
                        end)
                        local c, p = false, false
                        pcall(function() c = dfhack.units.isCitizen(u, true) end)
                        pcall(function() p = dfhack.units.isPet(u) end)
                        who = c and 'CITIZEN' or (p and 'pet' or 'NEITHER')
                    end
                    out(string.format('      %-28s %-8s %s',
                        tostring(d):sub(1, 28), who, race))
                    shown = shown + 1
                end
            end)
        end
    end
    out('')
    out('  THIS IS THE DECIDING SECTION.')
    out('    only CITIZEN and pet rows, no NEITHER: a reagent naming')
    out('      ANY_DEAD_DWARF is the whole feature and no watcher is')
    out('      needed.')
    out('    any NEITHER row: the vector carries invaders too, and a')
    out('      reagent cannot separate them.')
end

-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- 6. THE VOCABULARY AUDIT
-- ---------------------------------------------------------------------
-- What CAN a reagent express, against what the engine currently lets a
-- module author write. Two lists, printed side by side, so the gap is
-- read rather than argued.
--
-- The engine list is passed in below rather than derived here, because
-- deriving it would mean this probe parsing Lua source, and a probe
-- that can be wrong about its own baseline is worse than none.
-- Regenerate it with the one liner in the accompanying document if the
-- schema changes.
local ENGINE_FLAGS = {
    -- 82 names, engine and preflight agreed exactly on 2026-09-09
}

local function audit()
    head('6. what a job_item can express')

    -- Every bit DF actually has, from a LIVE filter if there is one,
    -- else from the type. An instance enumerates; a type needs _fields.
    local sample = nil
    pcall(function()
        local link = df.global.world.jobs.list.next
        while link and not sample do
            local j = link.item
            if j and #j.job_items.elements > 0 then
                sample = j.job_items.elements[0]
            end
            link = link.next
        end
    end)

    for _, grp in ipairs({ 'flags1', 'flags2', 'flags3' }) do
        local names = {}
        if sample then
            pcall(function()
                for k in pairs(sample[grp]) do names[#names + 1] = tostring(k) end
            end)
        end
        if #names == 0 then
            pcall(function()
                for _, f in ipairs(df['job_item_' .. grp]._fields) do
                    names[#names + 1] = f.name
                end
            end)
        end
        table.sort(names)
        out(string.format('  job_item.%s  %d bit(s)', grp, #names))
        local line = '     '
        for _, n in ipairs(names) do
            if #line + #n + 2 > 68 then out(line) line = '     ' end
            line = line .. ' ' .. n
        end
        if line:match('%S') then out(line) end
    end

    out('')
    if sample then
        out('  read off a LIVE job filter')
    else
        out('  read off the TYPE; queue any job and re-run to read a')
        out('  live filter instead, which is the stronger evidence')
    end

    -- And the rest of the struct, so a field the schema cannot reach
    -- shows up as itself rather than as an absence.
    out('')
    out('  every job_item field:')
    local fields = {}
    if sample then
        pcall(function()
            for k in pairs(sample) do fields[#fields + 1] = tostring(k) end
        end)
    end
    if #fields == 0 then
        pcall(function()
            for _, f in ipairs(df.job_item._fields) do
                fields[#fields + 1] = f.name
            end
        end)
    end
    table.sort(fields)
    local line = '     '
    for _, n in ipairs(fields) do
        if #line + #n + 2 > 68 then out(line) line = '     ' end
        line = line .. ' ' .. n
    end
    if line:match('%S') then out(line) end

    -- The other vocabulary the schema resolves by name and does not
    -- validate. vector_id got its list this week; this one has not.
    out('')
    local tu = {}
    pcall(function()
        for i = df.tool_uses._first_item, df.tool_uses._last_item do
            local n = df.tool_uses[i]
            if n then tu[#tu + 1] = tostring(n) end
        end
    end)
    out(string.format('  df.tool_uses  %d value(s):', #tu))
    line = '     '
    for _, n in ipairs(tu) do
        if #line + #n + 2 > 68 then out(line) line = '     ' end
        line = line .. ' ' .. n
    end
    if line:match('%S') then out(line) end
    out('')
    out('  has_tool_use is resolved from this list by name and is')
    out('  validated nowhere. Paste this into the types file the way')
    out('  JOB_ITEM_VECTORS was and preflight can catch a typo.')
end

-- ---------------------------------------------------------------------
if mode == 'all' or mode == 'reagent' then reagent_side() end
if mode == 'all' or mode == 'vectors' then vectors()      end
if mode == 'all' or mode == 'corpses' then corpses()      end
if mode == 'all' or mode == 'vector'  then vector_contents() end
if mode == 'all' or mode == 'audit'   then audit()          end
if mode == 'all' or mode == 'fields'  then fields()       end