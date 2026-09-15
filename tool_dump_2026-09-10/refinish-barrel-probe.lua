-- refinish-barrel-probe.lua
-- ==========================================
-- BARREL PROBE
-- ==========================================
-- Measures what a barrel actually is, before any code is written to
-- put liquid in one. Three questions, and a fourth that fell out of
-- writing it.
--
--   1 HOW MUCH does a container hold, and how do we read that? Jay
--     knows barrels take 10 from the making concrete water barrel and
--     saw a 15 unit field while working on char outputs. Neither is
--     confirmed for this use and neither is guessed at here.
--
--   2 WHAT SHAPE are the contents? This is the one that decides
--     everything. Ten units in a barrel is either ONE item carrying
--     dimension 1500, or TEN items carrying 150 each, and the two
--     need completely different writers. Nothing in the module works
--     until we know which.
--
--   3 WHAT CANNOT THE COLLECTOR SEE? count_free_vessels scans
--     world.items.other.TOOL and requires df.item_type.TOOL carrying
--     LIQUID_CONTAINER tool use. A barrel is df.item_type.BARREL with
--     no tool subtype at all, so it is invisible today. This counts
--     how much capacity that hides.
--
--   4 WOULD THE THRESHOLD BITE? Jay's rule: a barrel is only worth
--     readying if there is real excess behind it, because fifty
--     barrels holding one unit each is worse than jugs. Five is the
--     working figure. The last section runs that rule against the
--     fort as it stands.
--
-- ALREADY ANSWERED, so this does not measure it: vanilla brewing is
-- [PRODUCT:100:5:DRINK...][PRODUCT_TO_CONTAINER:barrel/pot], count
-- five into a barrel. Multi count to a container is native. Whether it
-- survives RUNTIME INJECTION is a live test, not a probe.
--
-- USAGE
--   refinish-barrel-probe          the survey
--   refinish-barrel-probe full     one row per container
-- ==========================================

local args = {...}
local MODE = (args[1] or ''):lower()

local UNIT = 150   -- one liquid package, T.LIQUID_UNIT

-- ==========================================
-- WHAT COUNTS AS A CONTAINER
-- ==========================================
-- Deliberately wider than the collector's own test. The point is to
-- see what the collector is missing, so anything that could plausibly
-- hold a liquid is swept up and classified afterwards.
-- ==========================================

local KINDS = {
    [df.item_type.BARREL] = 'BARREL',
    [df.item_type.TOOL]   = 'TOOL',
    [df.item_type.BOX]    = 'BOX',
    [df.item_type.BUCKET] = 'BUCKET',
}

-- The collector's exact acceptance test, copied so the report can say
-- what count_free_vessels would do rather than what we think it does.
-- If that function changes, re-cut this.
local function collector_accepts(it)
    local ok = false
    pcall(function()
        if it:getType() ~= df.item_type.TOOL then return end
        for _, u in ipairs(it.subtype.tool_use) do
            if u == df.tool_uses.LIQUID_CONTAINER then ok = true end
        end
    end)
    return ok
end

local function collect()
    local vec = nil
    pcall(function() vec = df.global.world.items.all end)
    if not vec then
        dfhack.printerr('Could not read df.global.world.items.all.')
        return {}
    end
    local out = {}
    for _, it in ipairs(vec) do
        pcall(function()
            local ty = tonumber(it:getType())
            local kind = KINDS[ty]
            -- Anything holding something is interesting even if its
            -- type is not on the list, because that is exactly how an
            -- unexpected container would announce itself.
            local holds = #(dfhack.items.getContainedItems(it) or {})
            if kind or holds > 0 then
                table.insert(out, { item = it,
                                    kind = kind or ('type' .. ty) })
            end
        end)
    end
    return out
end

-- ==========================================
-- ONE CONTAINER
-- ==========================================

local function inspect(rec)
    local it = rec.item
    local r = { kind = rec.kind, contents = {} }

    pcall(function() r.id = it.id end)
    pcall(function() r.desc = dfhack.items.getDescription(it, 0) end)
    pcall(function() r.forbid = it.flags.forbid end)
    pcall(function() r.in_job = it.flags.in_job end)
    r.accepted = collector_accepts(it)

    -- ---- CAPACITY, DISCOVERED NOT ASSUMED ----
    -- Every accessor that might carry it is tried and whatever
    -- resolves is reported, including reporting that none did. A
    -- capacity read from the wrong field would be worse than no
    -- capacity at all.
    r.cap = {}
    pcall(function() r.cap.subtype_capacity =
        it.subtype.container_capacity end)
    pcall(function() r.cap.getCapacity = it:getCapacity() end)
    pcall(function() r.cap.getVolume = it:getVolume() end)
    pcall(function() r.cap.getTotalDimension = it:getTotalDimension() end)

    -- ---- CONTENTS, ITEM BY ITEM ----
    -- Question 2. One row per contained item, with its own stack and
    -- dimension, so the shape of a full container is visible rather
    -- than inferred from a total.
    local total_dim, total_stack = 0, 0
    pcall(function()
        for _, c in ipairs(dfhack.items.getContainedItems(it) or {}) do
            local e = {}
            pcall(function() e.id = c.id end)
            pcall(function() e.ty = tostring(df.item_type[c:getType()]) end)
            pcall(function()
                local mi = dfhack.matinfo.decode(c)
                e.token = tostring(mi:getToken())
            end)
            pcall(function() e.stack = c.stack_size end)
            pcall(function() e.dim = c.dimension end)
            total_stack = total_stack + (e.stack or 0)
            total_dim = total_dim + (e.dim or 0)
            table.insert(r.contents, e)
        end
    end)
    r.total_dim   = total_dim
    r.total_stack = total_stack
    r.units       = total_dim / UNIT

    return r
end

-- ==========================================
-- REPORT
-- ==========================================

local function d(v, fmt)
    if v == nil then return '-' end
    if type(v) == 'boolean' then return v and 'yes' or 'no' end
    if fmt then return string.format(fmt, v) end
    return tostring(v)
end

local function short(t)
    if not t then return '-' end
    return (tostring(t):gsub('^INORGANIC:', ''):gsub('^CREATURE_MAT:', ''))
end

local function main()
    print('')
    print('BARREL PROBE')
    print('What a container is, before anything is written to fill one.')
    print('')

    local recs = collect()
    if #recs == 0 then
        print('No containers found at all. That is itself a finding:')
        print('either the fort has none or items.all did not resolve.')
        return
    end

    local rows = {}
    for _, rec in ipairs(recs) do table.insert(rows, inspect(rec)) end

    -- ---- 3: WHAT THE COLLECTOR SEES ----
    print('QUESTION 3, WHAT THE COLLECTOR CAN AND CANNOT SEE')
    local bykind = {}
    local korder = {}
    for _, r in ipairs(rows) do
        if not bykind[r.kind] then
            bykind[r.kind] = { n = 0, seen = 0, empty = 0, free = 0 }
            table.insert(korder, r.kind)
        end
        local g = bykind[r.kind]
        g.n = g.n + 1
        if r.accepted then g.seen = g.seen + 1 end
        if #r.contents == 0 then
            g.empty = g.empty + 1
            if not r.forbid and not r.in_job then g.free = g.free + 1 end
        end
    end
    table.sort(korder)
    print(string.format('  %-10s %-6s %-16s %-8s %s',
          'kind', 'total', 'collector sees', 'empty', 'empty and free'))
    local hidden_free = 0
    for _, k in ipairs(korder) do
        local g = bykind[k]
        print(string.format('  %-10s %-6d %-16d %-8d %d',
              k, g.n, g.seen, g.empty, g.free))
        if g.seen == 0 then hidden_free = hidden_free + g.free end
    end
    print('')
    print(string.format(
        '  %d empty, unforbidden, unclaimed container(s) are invisible to',
        hidden_free))
    print('  count_free_vessels today because they are not TOOL items')
    print('  carrying LIQUID_CONTAINER. That is the capacity at stake.')
    print('')

    -- ---- 2: THE SHAPE OF A FULL CONTAINER ----
    -- The decisive one. Printed before capacity, because if the shape
    -- is wrong nothing else matters.
    print('QUESTION 2, THE SHAPE OF A FULL CONTAINER')
    local filled = {}
    for _, r in ipairs(rows) do
        if #r.contents > 0 then table.insert(filled, r) end
    end
    if #filled == 0 then
        print('  Nothing in the fort is holding anything. Fill a barrel')
        print('  with water or booze and re-run, because this question')
        print('  cannot be answered from empty containers.')
    else
        print(string.format('  %-8s %-9s %-6s %-22s %-6s %-8s %s',
              'holder', 'kind', 'items', 'contents', 'stack', 'dim',
              'units'))
        local shown = 0
        for _, r in ipairs(filled) do
            shown = shown + 1
            if shown <= 20 or MODE == 'full' then
                for i, c in ipairs(r.contents) do
                    print(string.format(
                        '  %-8s %-9s %-6s %-22s %-6s %-8s %s',
                        (i == 1) and d(r.id) or '', (i == 1) and r.kind or '',
                        (i == 1) and tostring(#r.contents) or '',
                        short(c.token), d(c.stack), d(c.dim),
                        (i == 1) and string.format('%.2f', r.units) or ''))
                end
            end
        end
        if shown > 20 and MODE ~= 'full' then
            print(string.format('  ... and %d more, run with full',
                  shown - 20))
        end
        print('')

        -- The verdict, stated. N4: a column that does not separate
        -- anything must say so rather than be read hopefully.
        local one_item_many_units, many_items = 0, 0
        for _, r in ipairs(filled) do
            if #r.contents == 1 and r.units > 1.5 then
                one_item_many_units = one_item_many_units + 1
            elseif #r.contents > 1 then
                many_items = many_items + 1
            end
        end
        print('  SHAPE VERDICT')
        if one_item_many_units == 0 and many_items == 0 then
            print('    INCONCLUSIVE. Every full container holds exactly')
            print('    one item worth about one unit, so this fort cannot')
            print('    tell the two shapes apart. Fill a barrel properly')
            print('    and re-run.')
        elseif one_item_many_units > 0 and many_items == 0 then
            print('    ONE ITEM, MANY UNITS. A full container holds a')
            print('    single item whose dimension is the whole amount.')
            print('    So a writer sets count 1 and product_dimension')
            print('    N x 150, and a consumer taking 150 leaves a clean')
            print('    remainder behind.')
        elseif many_items > 0 and one_item_many_units == 0 then
            print('    MANY ITEMS, ONE UNIT EACH. A full container holds')
            print('    several separate items of 150. So a writer sets')
            print('    count N, exactly like vanilla brewing puts five')
            print('    drinks in a barrel, and each is consumed whole.')
        else
            print('    BOTH SHAPES PRESENT, which is the answer that')
            print('    matters most and the one to be careful about.')
            print(string.format(
                '    %d container(s) hold one multi unit item and %d hold',
                one_item_many_units, many_items))
            print('    several. Find out what distinguishes them before')
            print('    writing anything, because a writer that assumes')
            print('    one shape will silently mis-fill the other.')
        end
    end
    print('')

    -- ---- 1: CAPACITY ----
    print('QUESTION 1, HOW MUCH DOES ONE HOLD')
    print('  Every accessor that might carry capacity, per kind. A dash')
    print('  means it did not resolve, which is a real answer.')
    print('')
    local capshown = {}
    print(string.format('  %-10s %-14s %-12s %-12s %s',
          'kind', 'subtype_cap', 'getCapacity', 'getVolume',
          'getTotalDim'))
    for _, r in ipairs(rows) do
        if not capshown[r.kind] then
            capshown[r.kind] = true
            print(string.format('  %-10s %-14s %-12s %-12s %s',
                  r.kind, d(r.cap.subtype_capacity), d(r.cap.getCapacity),
                  d(r.cap.getVolume), d(r.cap.getTotalDimension)))
        end
    end
    print('')
    print('  MEASURED FLOOR, which beats any accessor:')
    local best = {}
    for _, r in ipairs(rows) do
        if r.units > (best[r.kind] or 0) then best[r.kind] = r.units end
    end
    local anyfill = false
    for _, k in ipairs(korder) do
        if (best[k] or 0) > 0 then
            anyfill = true
            print(string.format(
                '    %-10s fullest seen holds %.2f unit(s) of %d',
                k, best[k], UNIT))
        end
    end
    if not anyfill then
        print('    Nothing is holding anything, so there is no floor to')
        print('    report. This is the number to trust once there is.')
    end
    print('')

    -- ---- 4: THE THRESHOLD ----
    print('QUESTION 4, WOULD THE THRESHOLD BITE')
    print('  Jay\'s rule: only ready a barrel when there is real excess')
    print('  behind it, because fifty barrels holding one unit each is')
    print('  worse than jugs. Below, what a surplus would be packed into')
    print('  at a threshold of 5, given this fort.')
    print('')
    local free_barrels, free_jugs = 0, 0
    for _, r in ipairs(rows) do
        if #r.contents == 0 and not r.forbid and not r.in_job then
            if r.kind == 'BARREL' then free_barrels = free_barrels + 1
            elseif r.accepted then free_jugs = free_jugs + 1 end
        end
    end
    print(string.format('  free barrels %d, free jugs %d',
          free_barrels, free_jugs))
    print('')
    local CAP, THRESH = 10, 5
    print(string.format(
        '  assuming a barrel holds %d and the threshold is %d:', CAP, THRESH))
    print(string.format('  %-10s %-12s %-12s %s',
          'surplus', 'barrels', 'jugs', 'note'))
    for _, want in ipairs({ 1, 3, 5, 9, 12, 36, 46 }) do
        local b, j, note = 0, want, 'under threshold, jugs only'
        if want >= THRESH then
            b = math.floor(want / CAP)
            local rem = want - b * CAP
            if rem >= THRESH and b < free_barrels then
                b = b + 1 rem = 0
            end
            j = rem
            note = 'barrels take the bulk'
            if b > free_barrels then
                note = 'WANTS MORE BARRELS THAN EXIST'
            end
        end
        print(string.format('  %-10d %-12d %-12d %s', want, b, j, note))
    end
    print('')
    print('  The 46 row is the whale. Forty six jugs today, or five')
    print('  barrels and one jug, which is the whole point of this.')
    print('')
end

main()
