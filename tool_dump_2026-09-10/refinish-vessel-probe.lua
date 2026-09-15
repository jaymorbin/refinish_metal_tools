-- refinish-vessel-probe.lua
-- ==========================================
-- VESSEL SIZING PROBE
-- ==========================================
-- One job: work out how to size a VAT so it behaves like a barrel,
-- using numbers read out of the running game rather than off a wiki.
--
-- WHY THE WIKI CANNOT BE USED HERE
--
-- The wiki's SIZE figures are inflated against what DF actually holds
-- internally, reportedly by around tenfold. Every number in this
-- report is read from `df.global.world.raws.itemdefs.tools` or off a
-- live item. Nothing is copied from documentation and nothing is
-- converted. If a number here disagrees with the wiki, this one is
-- the one the game is using.
--
-- WHAT MAKES THE VAT NECESSARY
--
-- A reagent declares ONE item type. A slot asking for a TOOL carrying
-- LIQUID_CONTAINER can never also take a BARREL, and DF has no OR. So
-- bulk liquid storage has to arrive as a TOOL that drops into the slot
-- the module already uses, which is what VAT is for. The collector
-- accepts it today with no change: count_free_vessels tests exactly
-- `getType() == TOOL` plus LIQUID_CONTAINER tool use.
--
-- WHAT THIS MEASURES
--
--   1 DECLARED, per subtype. SIZE, MATERIAL_SIZE and
--     CONTAINER_CAPACITY straight off the itemdef, for every liquid
--     container in the game and in the module, side by side. This is
--     the table that says whether the module's existing vessels are
--     sized sensibly or were guessed at years ago.
--
--   2 LIVE, per subtype. What getVolume actually returns on a real
--     item of that subtype, so the relationship between the declared
--     numbers and the runtime one is visible instead of assumed.
--
--   3 THE BARREL, which has no itemdef at all and therefore no
--     declared anything. It can only be measured, so it is: how much
--     is in the fullest one, in dimension, in units of 150, and in
--     the volume its contents actually occupy.
--
--   4 THE ANSWER, or an honest statement that the fort cannot give
--     one yet and what to do about it.
--
-- AMOUNT IS STACK TIMES DIMENSION. Not dimension alone. Register R17
-- established this on a fat glob and the first version of this probe
-- got it wrong anyway, reading a booze barrel at stack 5 dimension
-- 150 as holding one unit when it holds five.
--
-- USAGE
--   refinish-vessel-probe          the sizing report
--   refinish-vessel-probe full     plus every container item
-- ==========================================

local args = {...}
local MODE = (args[1] or ''):lower()

local UNIT = 150   -- one liquid package, T.LIQUID_UNIT

local function d(v, fmt)
    if v == nil then return '-' end
    if type(v) == 'boolean' then return v and 'yes' or 'no' end
    if fmt then return string.format(fmt, v) end
    return tostring(v)
end

-- ==========================================
-- 1: THE ITEMDEFS
-- ==========================================
-- Every tool itemdef that declares LIQUID_CONTAINER, vanilla and
-- module alike, read from the raws vector. Also picks up FOOD_STORAGE
-- because the large pot is the closest vanilla analogue to a barrel
-- and is worth having on the page for scale.
-- ==========================================

local function read_itemdefs()
    local out = {}
    local ok = pcall(function()
        for i, td in ipairs(df.global.world.raws.itemdefs.tools) do
            local e = { idx = i }
            pcall(function() e.id = tostring(td.id) end)
            pcall(function() e.name = tostring(td.name) end)
            pcall(function() e.size = td.size end)
            pcall(function() e.matsize = td.material_size end)
            pcall(function() e.cap = td.container_capacity end)
            e.uses = {}
            pcall(function()
                for _, u in ipairs(td.tool_use) do
                    table.insert(e.uses, tostring(df.tool_uses[u]))
                end
            end)
            local liquid, food = false, false
            for _, u in ipairs(e.uses) do
                if u == 'LIQUID_CONTAINER' then liquid = true end
                if u == 'FOOD_STORAGE' then food = true end
            end
            if liquid or food then
                e.liquid = liquid
                table.insert(out, e)
            end
        end
    end)
    if not ok then
        dfhack.printerr('Could not read raws.itemdefs.tools.')
    end
    return out
end

-- ==========================================
-- 2 AND 3: THE LIVE ITEMS
-- ==========================================

local KINDS = {
    [df.item_type.BARREL] = 'BARREL',
    [df.item_type.TOOL]   = 'TOOL',
    [df.item_type.BUCKET] = 'BUCKET',
}

local function inspect(it, kind)
    local r = { kind = kind, contents = {} }
    pcall(function() r.id = it.id end)
    pcall(function() r.desc = dfhack.items.getDescription(it, 0) end)
    pcall(function() r.vol = it:getVolume() end)
    pcall(function() r.subtype_id = tostring(it.subtype.id) end)
    pcall(function() r.subtype_cap = it.subtype.container_capacity end)
    pcall(function() r.subtype_size = it.subtype.size end)

    -- Contents. Each one's own volume is read as well as its stack and
    -- dimension, because volume is the currency a container's capacity
    -- is spent in and dimension is not.
    local dim_total, vol_total, n_dim = 0, 0, 0
    pcall(function()
        for _, c in ipairs(dfhack.items.getContainedItems(it) or {}) do
            local e = {}
            pcall(function() e.id = c.id end)
            pcall(function()
                e.token = tostring(dfhack.matinfo.decode(c):getToken())
            end)
            pcall(function() e.stack = c.stack_size end)
            pcall(function() e.dim = c.dimension end)
            pcall(function() e.vol = c:getVolume() end)
            if e.dim and e.dim > 0 then
                -- STACK TIMES DIMENSION. See the header.
                e.amount = (e.stack or 1) * e.dim
                dim_total = dim_total + e.amount
                n_dim = n_dim + 1
            end
            vol_total = vol_total + (e.vol or 0)
            table.insert(r.contents, e)
        end
    end)
    r.dim_total = dim_total
    r.vol_total = vol_total
    r.n_dim     = n_dim
    r.holds     = #r.contents
    r.units     = dim_total / UNIT
    return r
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
            local kind = KINDS[tonumber(it:getType())]
            if kind then table.insert(out, inspect(it, kind)) end
        end)
    end
    return out
end

-- ==========================================
-- REPORT
-- ==========================================

-- Declared at file scope, not inside main, because the sanity section
-- at the bottom reads what the measurement section works out. A local
-- inside a nested block would resolve to a global there, read nil, and
-- silently drop the column. That trap has bitten this project before.
--
-- nil until the relationship is PROVEN. Never defaulted.
local package_cost = nil

local function main()
    print('')
    print('VESSEL SIZING PROBE')
    print('Every number below is read from the running game. None of it')
    print('comes from the wiki, whose SIZE figures do not match these.')
    print('')

    local defs = read_itemdefs()
    local rows = collect()

    -- Live volume and population, keyed by subtype id, so the declared
    -- table can carry a measured column beside it.
    local live, pop = {}, {}
    for _, r in ipairs(rows) do
        local k = r.subtype_id or r.kind
        pop[k] = (pop[k] or 0) + 1
        if live[k] == nil and r.vol then live[k] = r.vol end
    end

    -- ---- 1 AND 2 ----
    print('DECLARED, off the itemdef, with the live volume beside it')
    print('  NO units column here. An earlier version divided CAPACITY')
    print('  by 150 and called the result units, which is wrong:')
    print('  capacity is a VOLUME and 150 is a DIMENSION. The conversion')
    print('  between them is measured further down instead of assumed.')
    print('')
    print('  Note also that DF divides raws values by ten on load. The')
    print('  jug reads SIZE 300 in item_tool.txt and 30 here. These are')
    print('  the internal numbers.')
    print('')
    print(string.format('  %-24s %-8s %-8s %-10s %-8s %s',
          'itemdef', 'SIZE', 'MATSIZE', 'CAPACITY', 'getVol',
          'in fort'))
    local mod_defs, van_defs = {}, {}
    for _, e in ipairs(defs) do
        if e.id and e.id:find('MAKING_FUEL', 1, true) then
            table.insert(mod_defs, e)
        else
            table.insert(van_defs, e)
        end
    end
    local function show(list, label)
        if #list == 0 then return end
        print('  -- ' .. label)
        for _, e in ipairs(list) do
            print(string.format('  %-24s %-8s %-8s %-10s %-8s %s',
                  d(e.id), d(e.size), d(e.matsize), d(e.cap),
                  d(live[e.id]), d(pop[e.id] or 0)))
        end
    end
    show(van_defs, 'vanilla')
    show(mod_defs, 'module')
    print('')

    -- ---- 3: THE BARREL ----
    print('THE BARREL, which declares nothing and can only be measured')
    local barrels, fullest = 0, nil
    for _, r in ipairs(rows) do
        if r.kind == 'BARREL' then
            barrels = barrels + 1
            if not fullest or r.dim_total > fullest.dim_total then
                fullest = r
            end
        end
    end
    if barrels == 0 then
        print('  No barrels in the fort. Nothing to replicate. Spawn one')
        print('  and fill it before trusting anything below.')
    else
        print(string.format('  %d barrel(s). A barrel has no itemdef, so'
              .. ' SIZE and CONTAINER_CAPACITY do', barrels))
        print('  not exist for it and its live getVolume is the only')
        print('  declared-ish number it has.')
        local anyvol = nil
        for _, r in ipairs(rows) do
            if r.kind == 'BARREL' and r.vol and not anyvol then
                anyvol = r.vol
            end
        end
        print(string.format('  getVolume on a barrel: %s', d(anyvol)))
        if fullest and fullest.dim_total > 0 then
            print(string.format(
                '  fullest holds %d dimension, %.2f unit(s) of %d,'
                .. ' occupying %d volume, item #%s',
                fullest.dim_total, fullest.units, UNIT,
                fullest.vol_total, tostring(fullest.id)))
        else
            print('  NOTHING IN ANY BARREL carries a dimension, so how')
            print('  much a barrel holds is still unmeasured. Brew into')
            print('  one and re-run.')
        end
    end
    print('')

    -- ---- WHAT IS IN THINGS ----
    print('WHAT CONTAINERS ARE ACTUALLY HOLDING')
    print('  amount = stack x dim. vol is what the contents occupy,')
    print('  which is the currency CONTAINER_CAPACITY is spent in.')
    print('')
    local filled = {}
    for _, r in ipairs(rows) do
        if r.n_dim > 0 then table.insert(filled, r) end
    end
    if #filled == 0 then
        print('  Nothing is holding a dimensioned content. Food does not')
        print('  count and is not listed. Brew or press something.')
    else
        print(string.format('  %-7s %-8s %-30s %-6s %-6s %-8s %s',
              'holder', 'kind', 'contents', 'stack', 'dim', 'amount',
              'vol'))
        local n = 0
        for _, r in ipairs(filled) do
            n = n + 1
            if n <= 15 or MODE == 'full' then
                for i, c in ipairs(r.contents) do
                    if c.dim or MODE == 'full' then
                        print(string.format(
                            '  %-7s %-8s %-30s %-6s %-6s %-8s %s',
                            (i == 1) and d(r.id) or '',
                            (i == 1) and r.kind or '',
                            d(c.token), d(c.stack), d(c.dim),
                            d(c.amount), d(c.vol)))
                    end
                end
            end
        end
        if n > 15 and MODE ~= 'full' then
            print(string.format('  ... and %d more, run with full', n - 15))
        end
    end
    print('')

    -- ---- DOES getVolume INCLUDE THE CONTENTS? ----
    -- Jay's theory: an item's volume is its MATERIAL bulk and does not
    -- include the hollow it carries. If that holds, getVolume on a
    -- container says nothing about capacity and every reading of it as
    -- one has been wrong.
    --
    -- One confirmation is already in hand: a jug's itemdef size is 30
    -- and a live jug's getVolume is 30, while its container_capacity
    -- is 1000, a separate and far larger number.
    --
    -- This is the decisive one, and it needs no arithmetic at all. If
    -- volume excludes contents then a FULL container and an EMPTY one
    -- of the same kind read the SAME number. Nothing to derive, no
    -- ratio to trust, just two readings that either match or do not.
    print('DOES getVolume INCLUDE CONTENTS?')
    print('  Same kind, one holding something and one holding nothing.')
    print('')
    local pair, porder = {}, {}
    for _, r in ipairs(rows) do
        local k = r.subtype_id or r.kind
        if not pair[k] then
            pair[k] = { kind = r.kind }
            table.insert(porder, k)
        end
        local p = pair[k]
        if (r.holds or 0) > 0 then
            if not p.full then p.full = r end
        else
            if not p.empty then p.empty = r end
        end
    end
    table.sort(porder)
    print(string.format('  %-26s %-10s %-10s %s',
          'kind or subtype', 'empty vol', 'full vol', 'verdict'))
    local matched, differed, comparable = 0, 0, 0
    for _, k in ipairs(porder) do
        local p = pair[k]
        if p.full and p.empty then
            comparable = comparable + 1
            local same = (p.full.vol == p.empty.vol)
            if same then matched = matched + 1 else differed = differed + 1 end
            print(string.format('  %-26s %-10s %-10s %s', k,
                  d(p.empty.vol), d(p.full.vol),
                  same and 'SAME' or 'DIFFERENT'))
        end
    end
    print('')
    if comparable == 0 then
        print('  INCONCLUSIVE. No kind here has both a full and an empty')
        print('  example, so nothing can be compared. Empty one container')
        print('  of a kind you also have full, and re-run.')
    elseif differed == 0 then
        print(string.format(
            '  VOLUME EXCLUDES CONTENTS, %d of %d kind(s) read identical.',
            matched, comparable))
        print('  So getVolume is the material bulk and says NOTHING about')
        print('  how much a container holds. Capacity is a separate')
        print('  number and for a TOOL it is subtype.container_capacity.')
    elseif matched == 0 then
        print(string.format(
            '  VOLUME INCLUDES CONTENTS, %d of %d kind(s) differ.',
            differed, comparable))
        print('  The theory is wrong and a full container can be read')
        print('  directly for how much is in it.')
    else
        print(string.format(
            '  MIXED: %d same, %d different. That is the interesting',
            matched, differed))
        print('  answer and the one to chase, because it means the rule')
        print('  is not uniform across item types.')
    end
    print('')

    -- ---- WHAT DOES VOLUME ACTUALLY TRACK? ----
    -- The previous version of this section reported "CONSTANT at 60.00
    -- across 2 materials" off twelve samples that were all stack 5 and
    -- dimension 150. That is ONE observation repeated twelve times, and
    -- two booze materials are not two data points.
    --
    -- With every sample at the same stack and the same dimension,
    -- three different rules all fit the number 300:
    --     vol = 60 x stack
    --     vol =  2 x dim
    --     vol = 0.4 x stack x dim
    -- and they predict wildly different things for a jug holding one
    -- package. So the question is not "what is the constant", it is
    -- "which quantity does volume follow", and answering that needs
    -- samples that DIFFER.
    --
    -- Every dimensioned item in the world is swept, loose ones as well
    -- as contained, because a loose tar jug's worth of liquid is a
    -- second data point and a barrel of booze is not.
    print('WHAT DOES VOLUME TRACK?')
    print('  Every dimensioned item in the world, grouped by its stack')
    print('  and dimension. Three candidate rules, one column each. The')
    print('  one that stays constant DOWN a column is the real one.')
    print('')

    local sig, sorder = {}, {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            pcall(function()
                local dim = it.dimension
                if not dim or dim <= 0 then return end
                local st = it.stack_size or 1
                local vol = it:getVolume()
                if not vol or vol <= 0 then return end
                -- ---- KEYED BY ITEM TYPE TOO, AND THIS MATTERS ----
                -- A thread's dimension scale is not a drink's. 15000
                -- is ONE thread and 150 is ONE drink, so a rate taken
                -- across both is comparing rulers. Lumping them is why
                -- the first run of this section reported that no rule
                -- was constant: threads sat at 0.002 and drinks at 0.4
                -- and neither was wrong, they were different questions.
                local ty = 'type?'
                pcall(function() ty = tostring(df.item_type[it:getType()]) end)
                local key = ty .. '  ' .. st .. 'x' .. dim
                if not sig[key] then
                    sig[key] = { n = 0, stack = st, dim = dim, vol = vol,
                                 ty = ty }
                    table.insert(sorder, key)
                end
                local g = sig[key]
                g.n = g.n + 1
                -- A volume that varies WITHIN one signature would mean
                -- something else is in play entirely, so it is worth
                -- catching rather than averaging away.
                if vol ~= g.vol then g.inconsistent = true end
                local mi = nil
                pcall(function()
                    mi = tostring(dfhack.matinfo.decode(it):getToken())
                end)
                if mi and #(g.eg or '') == 0 then g.eg = mi end
            end)
        end
    end)
    table.sort(sorder)

    if #sorder == 0 then
        print('  NO DIMENSIONED ITEMS IN THE WORLD AT ALL. Nothing to')
        print('  measure. Brew, press or run a retort and try again.')
    else
        print(string.format('  %-22s %-5s %-6s %-7s %-8s %-9s %-9s %s',
              'item type, stack x dim', 'n', 'stack', 'dim', 'volume',
              'vol/stack', 'vol/dim', 'vol/amount'))
        for _, k in ipairs(sorder) do
            local g = sig[k]
            local amount = g.stack * g.dim
            print(string.format(
                '  %-22s %-5d %-6d %-7d %-8d %-9.2f %-9.4f %.4f%s',
                k, g.n, g.stack, g.dim, g.vol,
                g.vol / g.stack, g.vol / g.dim, g.vol / amount,
                g.inconsistent and '  INCONSISTENT WITHIN GROUP' or ''))
        end
        print('')
        for _, k in ipairs(sorder) do
            if sig[k].eg then
                print(string.format('    %-22s e.g. %s', k, sig[k].eg))
            end
        end
        print('')

        -- ---- THE VERDICT ----
        -- N4. A single signature cannot separate the three rules, and
        -- saying so is the whole point of this rewrite.
        -- ---- ONE VERDICT PER ITEM TYPE ----
        -- Our products are LIQUID_MISC, so that is the family whose
        -- answer we actually need. The others are reported because a
        -- rule confirmed on threads is still evidence about how DF
        -- treats dimension in general.
        local bytype, torder = {}, {}
        for _, k in ipairs(sorder) do
            local g = sig[k]
            if not bytype[g.ty] then
                bytype[g.ty] = {}
                table.insert(torder, g.ty)
            end
            table.insert(bytype[g.ty], g)
        end
        table.sort(torder)

        for _, ty in ipairs(torder) do
            local gs = bytype[ty]
            print('  ---- ' .. ty .. ' ----')
            if #gs < 2 then
                local g = gs[1]
                print(string.format(
                    '  NOT DISCRIMINATING. Only one signature here,'
                    .. ' stack %d dim %d.', g.stack, g.dim))
                if g.stack == 1 then
                    -- At stack 1 the two rules are the SAME equation.
                    -- Printing them as competing predictions and then
                    -- showing identical numbers, which an earlier
                    -- version did, is worse than saying nothing.
                    print('  Every sample of this type is stack 1, which')
                    print('  makes "C x dim" and "C x stack x dim" the')
                    print('  same equation. They cannot disagree here and')
                    print('  no amount of this type will separate them.')
                    print(string.format(
                        '  The rate is %.4f volume per dimension either'
                        .. ' way.', g.vol / g.dim))
                    print('  A STACKED sample of this type is the only')
                    print('  thing that would tell them apart.')
                else
                    print('  Two rules both fit a single point and')
                    print('  predict different things:')
                    print(string.format(
                        '    vol = C x dim         -> a stack 1 item at'
                        .. ' dim %d would read %d', g.dim, g.vol))
                    print(string.format(
                        '    vol = C x stack x dim -> the same item'
                        .. ' would read %d', g.vol / g.stack))
                    print('  A sample at a DIFFERENT STACK separates')
                    print('  them. Brewing stack size varies by reaction,')
                    print('  so a different plant brewed is enough.')
                end
            else
                local function spread(f)
                    local lo, hi
                    for _, g in ipairs(gs) do
                        local v = f(g)
                        lo = (lo == nil or v < lo) and v or lo
                        hi = (hi == nil or v > hi) and v or hi
                    end
                    return lo, hi, (hi - lo)
                end
                local cands = {
                    { 'vol = C x stack',
                      function(g) return g.vol / g.stack end,
                      function(c) return c end },
                    { 'vol = C x dim',
                      function(g) return g.vol / g.dim end,
                      function(c) return 150 * c end },
                    { 'vol = C x stack x dim',
                      function(g) return g.vol / (g.stack * g.dim) end,
                      function(c) return 150 * c end },
                }
                local flats = {}
                print(string.format('  %-24s %-10s %-10s %-12s %s',
                      'rule', 'low', 'high', 'per 150 dim', 'verdict'))
                for _, c in ipairs(cands) do
                    local lo, hi, sp = spread(c[2])
                    local flat = (math.abs(sp) < 0.000001)
                    local per = flat and c[3](lo) or nil
                    if flat then
                        table.insert(flats,
                            { name = c[1], C = lo, per = per })
                    end
                    print(string.format(
                        '  %-24s %-10.4f %-10.4f %-12s %s',
                        c[1], lo, hi,
                        per and string.format('%.2f', per) or '-',
                        flat and 'CONSTANT' or 'varies'))
                end
                print('')
                if #flats == 0 then
                    print('  NONE CONSTANT for this type. Volume depends')
                    print('  on something beyond stack and dimension.')
                elseif #flats == 1 then
                    print(string.format('  FOLLOWS %s, C = %.6f',
                          flats[1].name, flats[1].C))
                    if ty == 'LIQUID_MISC' and flats[1].per then
                        package_cost = flats[1].per
                    end
                else
                    local names = {}
                    for _, w in ipairs(flats) do
                        table.insert(names, w.name)
                    end
                    print('  AMBIGUOUS, more than one rule fits:')
                    print('    ' .. table.concat(names, '   and   '))
                    local per, agree = nil, true
                    for _, w in ipairs(flats) do
                        if w.per then
                            if per == nil then per = w.per
                            elseif math.abs(per - w.per) > 0.0001 then
                                agree = false
                            end
                        end
                    end
                    if per and agree then
                        print(string.format(
                            '  They agree on %.2f volume per 150 of'
                            .. ' dimension.', per))
                        if ty == 'LIQUID_MISC' then package_cost = per end
                    else
                        print('  They disagree. Unresolved.')
                    end
                end
            end
            print('')
        end

        -- ---- TYPES THAT SHARE A RATE ----
        -- Reported separately, and NOT folded into the per type tests
        -- above, because a shared rate is evidence while a merged
        -- sample set is the ruler-mixing error this section was
        -- rewritten to stop making.
        local rate, rorder = {}, {}
        for _, k in ipairs(sorder) do
            local g = sig[k]
            local r = string.format('%.6f', g.vol / g.dim)
            if not rate[r] then rate[r] = {} table.insert(rorder, r) end
            local seen = false
            for _, t in ipairs(rate[r]) do if t == g.ty then seen = true end end
            if not seen then table.insert(rate[r], g.ty) end
        end
        table.sort(rorder)
        local shared = false
        for _, r in ipairs(rorder) do
            if #rate[r] > 1 then shared = true end
        end
        if shared then
            print('  ---- TYPES SHARING A VOLUME PER DIMENSION RATE ----')
            for _, r in ipairs(rorder) do
                if #rate[r] > 1 then
                    print(string.format('    %s  <- %s', r,
                          table.concat(rate[r], ', ')))
                end
            end
            print('  Suggestive, not proof: these types agree, so the')
            print('  rate may be general rather than per type. It still')
            print('  says nothing about whether stack multiplies.')
            print('')
        end

        if not package_cost then
            print('  NOTHING PROVEN FOR LIQUID_MISC, which is the family')
            print('  our own products belong to. Two ways to settle it,')
            print('  either is enough:')
            print('')
            print('    1 Run a retort. That mints LIQUID_MISC at stack 1')
            print('      dim 150, the exact family, next to the drinks at')
            print('      stack 5.')
            print('    2 Brew a DIFFERENT plant. Brewing stack size')
            print('      varies by reaction, so a second drink signature')
            print('      at another stack separates the two rules for the')
            print('      liquipowder family.')
            print('')
        end
    end
    print('')

    -- ---- 4: THE ANSWER, OR WHY THERE IS NOT ONE ----
    -- N4: a column that separates nothing must say so. Same rule for a
    -- conclusion drawn from one.
    print('SIZING VERDICT')
    local vat = nil
    for _, e in ipairs(defs) do
        if e.id and e.id:find('VAT', 1, true) then vat = e end
    end
    local have_barrel_fill = fullest and fullest.dim_total > 0
    local have_vol = fullest and fullest.vol_total > 0

    if not have_barrel_fill then
        print('  CANNOT ANSWER YET. A barrel has no declared capacity, so')
        print('  the only way to learn what one holds is to watch a full')
        print('  one. Nothing in this fort has dimensioned contents in a')
        print('  barrel.')
        print('')
        print('  Do this: brew a few barrels of booze, then re-run. Booze')
        print('  is dimensioned and lands as one item at stack N, which')
        print('  is exactly the shape we need to copy.')
    else
        print(string.format(
            '  A barrel is holding %.2f unit(s), occupying %d volume.',
            fullest.units, fullest.vol_total))
        if vat then
            print(string.format(
                '  VAT declares CONTAINER_CAPACITY %s, which is %.1f'
                .. ' unit(s).', d(vat.cap),
                (vat.cap or 0) / UNIT))
        end
        print('')
        print('  STILL NOT PROVEN, and do not let the table above imply')
        print('  otherwise: a full barrel tells us what DF PUT IN one,')
        print('  not what one will ACCEPT. Brewing makes five at a time,')
        print('  so five in a barrel may be the recipe rather than the')
        print('  ceiling. The number that matters is the refusal point')
        print('  and no observation of a full container can give it.')
        print('')
        print('  That needs one throwaway reaction writing a deliberately')
        print('  large count into a vat, and reading back what survives.')
        print('  It answers the ceiling AND whether count above 1 lives')
        print('  through runtime injection, which is the other open one.')
    end
    print('')

    -- ---- SANITY PASS ON THE MODULE'S OWN VESSELS ----
    print('MODULE VESSEL SANITY, worth a look while we are here')
    if #mod_defs == 0 then
        print('  No module tools declare LIQUID_CONTAINER.')
    else
        local jugcap, jugsize = nil, nil
        for _, e in ipairs(van_defs) do
            if e.id == 'ITEM_TOOL_JUG' then
                jugcap, jugsize = e.cap, e.size
            end
        end

        -- Packages, using the cost MEASURED above rather than 150.
        -- If nothing dimensioned was in a container this run there is
        -- no cost to divide by, and the column is left out rather than
        -- filled with an assumption.
        -- Only set when the section above actually PROVED which
        -- quantity volume follows. An unproven cost is left nil and
        -- the packages column is omitted, rather than printed off a
        -- number nobody has established.
        local cost = package_cost

        if cost then
            print(string.format(
                '  one package costs %.2f volume, measured this run.',
                cost))
            print(string.format(
                '  vanilla jug: SIZE %s, CAPACITY %s, so %.1f package(s).',
                d(jugsize), d(jugcap), (jugcap or 0) / cost))
        else
            print('  NO PACKAGE COST MEASURED this run, so the package')
            print('  columns are omitted rather than guessed. Get a')
            print('  liquid into a container and re-run.')
            print(string.format('  vanilla jug: SIZE %s, CAPACITY %s',
                  d(jugsize), d(jugcap)))
        end
        print('')
        print(string.format('  %-24s %-8s %-10s %-10s %s',
              'module vessel', 'SIZE', 'CAPACITY', 'packages',
              'vs jug'))
        for _, e in ipairs(mod_defs) do
            if e.liquid then
                local ratio = (jugcap and jugcap > 0 and e.cap)
                    and string.format('%.2fx', e.cap / jugcap) or '-'
                print(string.format('  %-24s %-8s %-10s %-10s %s',
                      d(e.id), d(e.size), d(e.cap),
                      (cost and e.cap and e.cap > 0)
                        and string.format('%.1f', e.cap / cost) or '-',
                      ratio))
            end
        end
        print('')
        print('  Read the vs jug column, not the absolute numbers. A')
        print('  small bottle holding more than a jug is the tell.')
    end
    print('')
end

main()