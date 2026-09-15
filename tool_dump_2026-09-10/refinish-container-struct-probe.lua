-- refinish-container-struct-probe.lua
-- ==========================================
-- CONTAINER STRUCTURE DUMP
-- ==========================================
-- Enumerates everything DF exposes on a container, rather than
-- computing capacity from a couple of observed numbers.
--
-- WHY
--
-- The last probe reported "jug holds 6.7 units at 150" by dividing
-- CONTAINER_CAPACITY 1000 by 150. That is wrong, and the same probe
-- printed the evidence: a barrel holding 750 of DIMENSION has contents
-- occupying 300 of VOLUME. Capacity is compared against volume, so
-- dividing it by a dimension gives a number that means nothing.
--
-- Deriving the conversion from one observation would be the same
-- mistake wearing a smaller hat. DF knows what a container holds and
-- how much room is left in it. This finds where it keeps that.
--
-- HOW IT WORKS
--
-- No field is read by name from memory. `df.<struct>._fields` is
-- walked, every entry is tried as a field read and as a zero argument
-- call, and whatever answers is printed. Names that answer nothing are
-- listed too, because "this does not exist on this build" is a real
-- result and the alternative is a probe that prints nothing.
--
-- The corpse piece probe found `corpse_flags` this way after two
-- rounds of guessing at names had failed, so this is the pattern that
-- works.
--
-- USAGE
--   refinish-container-struct-probe            one example per kind
--   refinish-container-struct-probe all        every field, no filter
--   refinish-container-struct-probe <item id>  one specific item
-- ==========================================

local args = {...}
local ARG  = args[1]
local WANT_ALL = (ARG == 'all')
local WANT_ID  = tonumber(ARG)

-- ==========================================
-- FORMATTING
-- ==========================================
-- Values come back as numbers, booleans, strings, bitfields, vectors
-- and raw pointers. Anything long is summarised rather than dumped, so
-- one interesting scalar is not buried under a thousand element
-- vector.
-- ==========================================

local function describe(v)
    local t = type(v)
    if v == nil then return nil end
    if t == 'number' or t == 'boolean' or t == 'string' then
        return tostring(v)
    end
    if t == 'function' then return nil end   -- handled as a call below

    -- Vectors and arrays: length plus the first entry. A length of
    -- ZERO is deliberately NOT treated as an answer, because a
    -- bitfield and a named struct both report 0 here and returning
    -- "empty vector" for them would hide their contents. Only a
    -- non-empty length is conclusive.
    local len = nil
    pcall(function() len = #v end)
    if len and len > 0 then
        local first = nil
        pcall(function() first = tostring(v[0]) end)
        if first == nil then pcall(function() first = tostring(v[1]) end) end
        return string.format('<len %d, first %s>', len,
                             tostring(first):sub(1, 28))
    end

    -- Bitfields and named structs. Bits that are set are reported, and
    -- so are the names a struct carries, because for our purposes
    -- knowing that `subtype` holds an `id` is the useful part.
    local bits, keys = {}, {}
    local ok = pcall(function()
        for k, sub in pairs(v) do
            if sub == true then table.insert(bits, tostring(k)) end
            if #keys < 6 then table.insert(keys, tostring(k)) end
        end
    end)
    if ok and #bits > 0 then
        table.sort(bits)
        return '<flags set: ' .. table.concat(bits, ',') .. '>'
    end
    if ok and #keys > 0 then
        table.sort(keys)
        return '<struct: ' .. table.concat(keys, ',') .. '>'
    end
    if ok and len == 0 then return '<empty>' end

    return '<' .. t .. '>'
end

-- Reads one name off an object every way it might answer.
-- Returns the value string and how it was obtained, so a number that
-- came from a method is never mistaken for a stored field.
local function probe_name(obj, name)
    local v, how = nil, nil

    pcall(function()
        local raw = obj[name]
        if type(raw) ~= 'function' then
            local s = describe(raw)
            if s ~= nil then v, how = s, 'field' end
        end
    end)
    if v then return v, how end

    -- Zero argument call. Only for names that look like readers, so
    -- nothing that mutates the world gets invoked by a probe.
    if name:match('^get') or name:match('^is') or name:match('^has')
       or name:match('^can') then
        pcall(function()
            local r = obj[name](obj)
            local s = describe(r)
            if s ~= nil then v, how = s, 'call()' end
        end)
    end
    return v, how
end

-- ==========================================
-- WHAT TO DUMP
-- ==========================================

local KINDS = {
    [df.item_type.BARREL] = { name = 'BARREL', struct = 'item_barrelst' },
    [df.item_type.TOOL]   = { name = 'TOOL',   struct = 'item_toolst' },
    [df.item_type.BUCKET] = { name = 'BUCKET', struct = 'item_bucketst' },
    [df.item_type.BOX]    = { name = 'BOX',    struct = 'item_boxst' },
    [df.item_type.BIN]    = { name = 'BIN',    struct = 'item_binst' },
}

-- Names worth pulling to the top of the report. Everything else is
-- still printed; this only decides ordering, so a name missing from
-- here is not a name being hidden.
local INTERESTING = {
    'container_capacity', 'capacity', 'getCapacity', 'getContainerCapacity',
    'size', 'material_size', 'getVolume', 'getTotalDimension',
    'getDimension', 'getStackSize', 'stack_size', 'dimension',
    'getWeight', 'weight', 'getBaseWeight', 'calculateWeight',
    'getStorageInfo', 'getCorpseSize', 'getMaterialSizeForMelting',
    'isFoodStorage', 'isBuildMat', 'getSubtype',
}

local function dump_object(label, obj, structname)
    print('')
    print('================================================')
    print(label)
    if structname then print('  struct: ' .. structname) end
    print('================================================')

    local names, seen = {}, {}
    local got_fields = false
    if structname then
        pcall(function()
            for n in pairs(df[structname]._fields) do
                if not seen[n] then seen[n] = true names[#names+1] = n end
                got_fields = true
            end
        end)
    end
    if not got_fields then
        -- No struct definition available, so fall back to the
        -- shortlist. Say so, because a short report for that reason
        -- looks identical to a short report for any other.
        print('  NOTE: could not read df.' .. tostring(structname)
              .. '._fields, so only the shortlist below was tried.')
        for _, n in ipairs(INTERESTING) do
            if not seen[n] then seen[n] = true names[#names+1] = n end
        end
    end
    table.sort(names)

    -- Read everything first, then print, so the interesting rows can
    -- go on top without probing twice.
    local vals, hows = {}, {}
    local answered = 0
    for _, n in ipairs(names) do
        local v, how = probe_name(obj, n)
        if v ~= nil then
            vals[n] = v hows[n] = how
            answered = answered + 1
        end
    end

    local function row(n)
        print(string.format('  %-30s %-8s %s',
              n, hows[n] or '-', vals[n] or '-'))
    end

    print('')
    print(string.format('  %-30s %-8s %s', 'name', 'how', 'value'))
    print('  -- likely relevant')
    local shown = {}
    for _, n in ipairs(INTERESTING) do
        if vals[n] ~= nil then row(n) shown[n] = true end
    end
    if next(shown) == nil then print('    none of the shortlist answered') end

    print('  -- everything else that answered')
    local rest = 0
    for _, n in ipairs(names) do
        if vals[n] ~= nil and not shown[n] then
            if WANT_ALL or rest < 60 then row(n) end
            rest = rest + 1
        end
    end
    if not WANT_ALL and rest > 60 then
        print(string.format('    ... and %d more, run with all', rest - 60))
    end

    print('')
    print(string.format('  %d of %d name(s) answered.', answered, #names))
    if not WANT_ALL then
        local silent = {}
        for _, n in ipairs(names) do
            if vals[n] == nil and #silent < 12 then
                table.insert(silent, n)
            end
        end
        if #silent > 0 then
            print('  silent, a sample: ' .. table.concat(silent, ' '))
        end
    end
end

-- ==========================================
-- MAIN
-- ==========================================

local function main()
    print('')
    print('CONTAINER STRUCTURE DUMP')
    print('Reading what DF exposes, rather than computing capacity from')
    print('a couple of observed numbers.')

    local vec = nil
    pcall(function() vec = df.global.world.items.all end)
    if not vec then
        dfhack.printerr('Could not read df.global.world.items.all.')
        return
    end

    -- ---- one specific item, if asked ----
    if WANT_ID then
        local it = nil
        pcall(function() it = df.item.find(WANT_ID) end)
        if not it then
            print('  No item with id ' .. tostring(WANT_ID) .. '.')
            return
        end
        local k = KINDS[tonumber(it:getType())]
        local desc = '?'
        pcall(function() desc = dfhack.items.getDescription(it, 0) end)
        dump_object('ITEM #' .. WANT_ID .. '  ' .. desc, it,
                    k and k.struct or nil)
        return
    end

    -- ---- one example per kind, preferring a FULL one ----
    -- A container with something in it is worth more than an empty
    -- one, because any field that tracks remaining room only differs
    -- from capacity once something is inside.
    local pick, count = {}, {}
    for _, it in ipairs(vec) do
        pcall(function()
            local k = KINDS[tonumber(it:getType())]
            if not k then return end
            count[k.name] = (count[k.name] or 0) + 1
            local holds = #(dfhack.items.getContainedItems(it) or {})
            local cur = pick[k.name]
            if not cur or (holds > 0 and cur.holds == 0) then
                pick[k.name] = { item = it, kind = k, holds = holds }
            end
        end)
    end

    local order = {}
    for name in pairs(pick) do table.insert(order, name) end
    table.sort(order)

    if #order == 0 then
        print('  No containers of any known kind in the fort.')
        return
    end

    print('')
    print('  kinds present: ')
    for _, name in ipairs(order) do
        print(string.format('    %-8s %d in fort, example #%s holding %d',
              name, count[name] or 0,
              tostring(pick[name].item.id), pick[name].holds))
    end

    for _, name in ipairs(order) do
        local p = pick[name]
        local desc = '?'
        pcall(function() desc = dfhack.items.getDescription(p.item, 0) end)
        dump_object(string.format('%s  item #%s  %s  holding %d item(s)',
                    name, tostring(p.item.id), desc, p.holds),
                    p.item, p.kind.struct)
    end

    -- ---- the tool itemdef, which is a different struct entirely ----
    local td = nil
    pcall(function()
        for _, t in ipairs(df.global.world.raws.itemdefs.tools) do
            if tostring(t.id) == 'ITEM_TOOL_JUG' then td = t end
        end
        if not td then td = df.global.world.raws.itemdefs.tools[0] end
    end)
    if td then
        dump_object('ITEMDEF  ' .. tostring(td.id)
                    .. '   (the definition, not an item)',
                    td, 'itemdef_toolst')
    end

    print('')
    print('================================================')
    print('WHAT TO LOOK FOR')
    print('================================================')
    print('  A field that differs between a FULL container and an empty')
    print('  one is the one that tracks remaining room, and that is the')
    print('  number the collector should be reading. Run this twice, once')
    print('  with the example empty and once full, and diff the two.')
    print('')
    print('  Anything answering through call() is computed on demand and')
    print('  may take arguments this probe did not pass, so a plausible')
    print('  looking zero from a call() row is worth less than the same')
    print('  number from a field row.')
    print('')
end

main()
