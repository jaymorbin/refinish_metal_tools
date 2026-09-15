-- refinish-pitch-probe.lua
-- ==========================================
-- BOIL_PITCH NO-PRODUCT PROBE
-- ==========================================
-- Answers one question: why does "boil tar down to pitch" run without
-- consuming tar or producing a boulder.
--
-- BUILD HISTORY
--   B1 watched world.jobs.list for a CustomReaction job carrying the
--   exact reaction code. It saw nothing across a full test, which is
--   itself a measurement: no such job ever existed. B1 was blind to
--   the two places that fact could come from. A manager work order
--   that fails validation never becomes a job at all, and B1 had no
--   eyes on manager orders. And a job carrying an unexpected identity
--   would have been skipped by the exact-match filter.
--
--   B2 keeps layers 1-3 exactly as they were (their output was good)
--   and rebuilds layer 4 to watch all three surfaces at once:
--     a. manager orders, the pre-job stage
--     b. the retort buildings' own job queues
--     c. the global job list, identity-agnostic: any CustomReaction
--        whose name CONTAINS BOIL_PITCH, or ANY job of ANY type held
--        by a retort
--   Nothing in layer 4 assumes the job's name, type, or origin
--   anymore. Whatever runs at a retort gets reported as found.
--
-- LAYERS
--   1. Reaction dump: the injected reaction as it sits in RAM.
--   2. Material dump: reaction_product tables of the three tar
--      materials, read with the .value accessor (a tostring on these
--      vector entries prints a pointer address, not the string).
--   3. Stock scan: every tar liquid on the map, and what holds it.
--   4. Order and job watcher, as described above.
--
-- USAGE
--   refinish-pitch-probe            layers 1-3 now, then arm layer 4
--   refinish-pitch-probe static     layers 1-3 only, no watcher
--   refinish-pitch-probe stop       disarm the watcher
--
-- The watcher stays armed across multiple runs until stopped. Test
-- BOTH queue paths if you can: once from the retort's own task menu,
-- once as a manager order. The two paths validate differently and
-- which one fails is evidence.
-- ==========================================

-- ==========================================
-- BUILD STAMP
-- ==========================================
-- Printed at the top of every run. If this number is not the one you
-- expect, the file on disk is older than the file you just staged.
local PROBE_BUILD = 'B2  manager orders, building queues, agnostic net'
-- ==========================================

local repeatUtil = require('repeat-util')
local utils = require('utils')

local args = {...}
local mode = (args[1] or 'arm'):lower()

local REPEAT_KEY = 'refinish-pitch-probe'

print('')
print('refinish-pitch-probe  build ' .. PROBE_BUILD)

-- ==========================================
-- STOP MODE
-- ==========================================
if mode == 'stop' then
    repeatUtil.cancel(REPEAT_KEY)
    print('watcher disarmed.')
    return
end

-- ==========================================
-- SAFE READERS
-- ==========================================
-- Indexing a DF struct with a field that does not exist throws, so
-- every speculative read goes through pcall. A read that fails is
-- reported as such rather than crashing the layer. This matters
-- doubly in B2: manager orders have no proven access idiom anywhere
-- in this codebase, so every field read there is a candidate probe.
-- ==========================================

-- Read one field, nil if absent.
local function dig(obj, field)
    if obj == nil then return nil end
    local ok, v = pcall(function() return obj[field] end)
    if ok then return v end
    return nil
end

-- Enum value to name, with the raw number kept visible. -1 is the
-- universal wildcard in reaction structs, so it gets its own label.
local function ename(enum, v)
    if v == nil then return 'nil' end
    if v == -1 then return 'ANY(-1)' end
    local ok, n = pcall(function() return enum[v] end)
    if ok and n then return tostring(n) .. '(' .. v .. ')' end
    return '?(' .. tostring(v) .. ')'
end

-- Inorganic index to raw id string.
local function inorg_id(idx)
    if idx == nil or idx < 0 then return 'none(-1)' end
    local ok, m = pcall(function()
        return df.global.world.raws.inorganics.all[idx]
    end)
    if ok and m then return m.id .. '(' .. idx .. ')' end
    return 'OUT_OF_RANGE(' .. idx .. ')'
end

-- Full material token of an item, e.g. INORGANIC:MAKING_FUEL_TAR_WOOD.
local function item_mat(item)
    local ok, mi = pcall(dfhack.matinfo.decode, item)
    if ok and mi then return mi:getToken() end
    return 'UNDECODABLE'
end

-- One-line description of an item: id, type, material, dimension.
-- Tools also get their itemdef code, because layer 3 showed the tar
-- sitting in TOOL(86) items and the subtype says WHICH tool that is.
local function item_line(item)
    local it = item:getType()
    local t = ename(df.item_type, it)
    if it == df.item_type.TOOL then
        local ok, tdef = pcall(function()
            return df.global.world.raws.itemdefs.tools[item:getSubtype()]
        end)
        if ok and tdef then t = t .. ':' .. tdef.id end
    end
    local d = dig(item, 'dimension')
    local dim = d and ('  dim=' .. d) or ''
    return string.format('item #%d  %s  %s%s', item.id, t, item_mat(item), dim)
end

-- ==========================================
-- LIVE STRUCT FINDERS
-- ==========================================
-- Nothing here assumes the injected code or id strings. The reaction
-- and the materials are found by suffix against live RAM, and the
-- exact string that matched is printed, so the report records reality
-- rather than an expectation.
-- ==========================================

local function find_reaction_by_suffix(suffix)
    for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
        if rxn.code:sub(-#suffix) == suffix then return rxn end
    end
    return nil
end

-- Returns index, id for the first inorganic whose id ends in suffix.
local function find_inorganic_by_suffix(suffix)
    for i, m in ipairs(df.global.world.raws.inorganics.all) do
        if m.id:sub(-#suffix) == suffix then return i, m.id end
    end
    return nil, nil
end

-- ==========================================
-- LAYER 1: THE REACTION AS INJECTED
-- ==========================================
-- Confirms RAM matches the blueprint: reagent flags, the
-- has_material_reaction_product gate, the contains linkage, and the
-- product's GET_MATERIAL_PRODUCT wiring. Any field here that
-- disagrees with the JSON is the bug.
-- B1 verdict: RAM matched the blueprint exactly. Kept for the stamp
-- it puts on every future report.
-- ==========================================

local rxn = find_reaction_by_suffix('BOIL_PITCH')

print('')
print('==== LAYER 1: reaction ====')
if not rxn then
    print('NO reaction with code ending BOIL_PITCH exists in RAM.')
    print('The reaction never injected. Check the RM boot log for a')
    print('MODULE REACT line naming it.')
else
    print('code: ' .. rxn.code .. '   name: ' .. rxn.name)

    for i, r in ipairs(rxn.reagents) do
        print(string.format('  reagent[%d] code=%s', i, r.code))
        print(string.format('    item_type=%s subtype=%d  mat=%s/%s',
            ename(df.item_type, r.item_type), r.item_subtype,
            tostring(r.mat_type),
            r.mat_type == 0 and inorg_id(r.mat_index)
                            or tostring(r.mat_index)))
        print(string.format('    quantity=%d  min_dimension=%d',
            r.quantity, r.min_dimension))
        print(string.format(
            '    IN_CONTAINER=%s PRESERVE=%s NO_PROD_AMOUNT=%s',
            tostring(r.flags.IN_CONTAINER),
            tostring(r.flags.PRESERVE_REAGENT),
            tostring(r.flags.DOES_NOT_DETERMINE_PRODUCT_AMOUNT)))
        print(string.format(
            '    has_material_reaction_product=[%s]  reaction_class=[%s]',
            r.has_material_reaction_product, r.reaction_class))
        -- contains holds 0-based positions of the reagents this one
        -- carries. For the vessel this must read the tar slot's index.
        local c = {}
        for _, v in ipairs(r.contains) do c[#c + 1] = tostring(v) end
        print('    contains=[' .. table.concat(c, ',') .. ']')
    end

    for i, p in ipairs(rxn.products) do
        -- Improvement products are a different class with different
        -- fields, so the class is named before fields are read.
        if df.reaction_product_itemst:is_instance(p) then
            print(string.format('  product[%d] (itemst)', i))
            print(string.format('    item_type=%s subtype=%d  mat=%s/%s',
                ename(df.item_type, p.item_type), p.item_subtype,
                tostring(p.mat_type), tostring(p.mat_index)))
            print(string.format(
                '    count=%d probability=%d product_dimension=%d',
                p.count, p.probability, p.product_dimension))
            print(string.format(
                '    GET_MATERIAL_SAME=%s GET_MATERIAL_PRODUCT=%s',
                tostring(p.flags.GET_MATERIAL_SAME),
                tostring(p.flags.GET_MATERIAL_PRODUCT)))
            print(string.format(
                '    get_material: reagent_code=[%s] product_code=[%s]',
                p.get_material.reagent_code,
                p.get_material.product_code))
            print('    product_to_container=[' ..
                p.product_to_container .. ']')
        else
            print(string.format('  product[%d] (%s)', i,
                tostring(p._type)))
        end
    end
end

-- ==========================================
-- LAYER 2: MATERIAL REACTION_PRODUCT TABLES
-- ==========================================
-- Reads the live reaction_product structure of each tar material.
-- The id vector is vector<string*>: the entry itself prints as a
-- pointer address, the string lives in entry.value. If PITCH_MAT is
-- missing from a table here, injection dropped it and both the
-- reagent gate and the product lookup fail for that tar.
-- B1 verdict: all three tables correct. Kept as a regression stamp.
-- ==========================================

print('')
print('==== LAYER 2: tar material product tables ====')

local TAR_SUFFIXES = { 'TAR_WOOD', 'TAR_COAL', 'OIL_CRUDE' }
local tar_indices = {}   -- inorganic index -> id, for layers 3 and 4

for _, suf in ipairs(TAR_SUFFIXES) do
    local idx, id = find_inorganic_by_suffix(suf)
    if not idx then
        print('  no inorganic ending ' .. suf .. ' in RAM.')
    else
        tar_indices[idx] = id
        local rp = df.global.world.raws.inorganics.all[idx]
            .material.reaction_product
        print('  ' .. id .. '  (index ' .. idx .. ')')
        if #rp.id == 0 then
            print('    reaction_product table is EMPTY.')
        end
        for i = 0, #rp.id - 1 do
            print(string.format('    [%s] -> mat_type=%d mat_index=%s',
                rp.id[i].value,
                rp.material.mat_type[i],
                inorg_id(rp.material.mat_index[i])))
        end
    end
end

-- Product targets, resolved once for the layer 4 completion scan.
local PRODUCT_SUFFIXES = { 'PITCH_WOOD', 'PITCH_COAL', 'BITUMEN' }
local product_indices = {}
for _, suf in ipairs(PRODUCT_SUFFIXES) do
    local idx, id = find_inorganic_by_suffix(suf)
    if idx then product_indices[idx] = id end
end

-- ==========================================
-- LAYER 3: TAR STOCK ON THE MAP
-- ==========================================
-- Every LIQUID_MISC item of a tar material, with the container that
-- holds it and the two flags that keep items out of jobs. A tar that
-- is loose, forbidden, or already claimed by another job explains a
-- reagent search coming up empty.
-- ==========================================

print('')
print('==== LAYER 3: tar stock ====')

local liq_vec = dig(df.global.world.items.other, 'LIQUID_MISC')
if not liq_vec then
    print('  items.other has no LIQUID_MISC bucket on this build.')
else
    local found = 0
    for _, item in ipairs(liq_vec) do
        local mt = dig(item, 'mat_type')
        local mi = dig(item, 'mat_index')
        if mt == 0 and tar_indices[mi] then
            found = found + 1
            print('  ' .. item_line(item))
            print(string.format('    forbid=%s in_job=%s',
                tostring(item.flags.forbid),
                tostring(item.flags.in_job)))
            local cont = dfhack.items.getContainer(item)
            if cont then
                print('    held by: ' .. item_line(cont))
            else
                print('    held by: NOTHING (loose liquid)')
            end
        end
    end
    if found == 0 then
        print('  no tar liquids exist on the map.')
    end
end

if mode == 'static' then
    print('')
    print('static run complete. watcher not armed.')
    return
end

-- ==========================================
-- LAYER 4: ORDER AND JOB WATCHER
-- ==========================================
-- Three nets, polled together every 5 frames. Each prints only when
-- its picture CHANGES, so the console stays readable across a long
-- test.
--
-- NET 1: MANAGER ORDERS. The stage before a job exists. An order
--   that sits here with amount_left unchanged and no job appearing
--   is the manager refusing to dispatch: match-time failure, decided
--   before any dwarf moves. This net is why B2 exists.
--
-- NET 2: RETORT BUILDING QUEUES. Every job in every placed retort's
--   own jobs vector, whatever its type or name. A task queued at the
--   building lands here immediately, claimed or not.
--
-- NET 3: GLOBAL JOB LIST. Any CustomReaction whose name CONTAINS
--   BOIL_PITCH (substring, so a cloned or re-coded identity still
--   trips it), plus ANY job of ANY type whose holder is a retort.
--
-- Every job sighted by net 2 or 3 is tracked. On first sight its
-- filters and an item-id watermark are recorded. Attachments are
-- dumped whenever the attached set changes. When a tracked job
-- leaves the world, everything created since the watermark is
-- listed: a pitch or bitumen boulder there is success, an empty
-- list is the no-product bug caught in the act.
-- ==========================================

if not rxn then
    print('')
    print('watcher not armed: no reaction to watch.')
    return
end

local watch_code = rxn.code
local NEEDLE = 'BOIL_PITCH'

-- ---- RETORT DISCOVERY ----
-- Building defs whose code mentions RETORT, then every placed
-- building of one of those custom types. Found once at arm time: a
-- retort BUILT after arming needs a probe re-run to be watched.
local retort_defs = {}   -- def index -> code string
for i, bdef in ipairs(df.global.world.raws.buildings.all) do
    local code = dig(bdef, 'code')
    if code and code:find('RETORT', 1, true) then
        retort_defs[i] = code
    end
end

local retorts = {}       -- list of building refs
local retort_ids = {}    -- building id -> true, for holder checks
for _, b in ipairs(df.global.world.buildings.all) do
    local ok, ct = pcall(function() return b:getCustomType() end)
    if ok and ct and retort_defs[ct] then
        retorts[#retorts + 1] = b
        retort_ids[b.id] = true
    end
end

print('')
print('==== LAYER 4: arming ====')
if next(retort_defs) == nil then
    print('  NO building def code contains RETORT. The building')
    print('  never injected; that alone can be the whole bug.')
else
    for i, code in pairs(retort_defs) do
        print('  retort def: ' .. code .. ' (def index ' .. i .. ')')
    end
end
print('  placed retorts: ' .. #retorts)
for _, b in ipairs(retorts) do
    print(string.format('    building #%d at (%d,%d,%d)',
        b.id, b.centerx, b.centery, b.z))
end

-- ---- MANAGER ORDER ACCESS ----
-- No file in this codebase reads manager orders, so the container
-- shape is probed rather than assumed: on current builds the vector
-- hides behind an .all wrapper, on older ones the field itself is
-- the vector. Whichever resolves is used, and a total miss is
-- reported instead of crashing the poll.
local function manager_order_vec()
    local mo = dig(df.global.world, 'manager_orders')
    if mo == nil then return nil end
    local all = dig(mo, 'all')
    if all ~= nil then return all end
    return mo
end

-- One line per order. Field names probed via dig for the same
-- reason: any nil in the output is a field this build does not
-- carry, which is itself information.
local function order_line(o)
    local st = dig(o, 'status')
    return string.format(
        'order #%s  type=%s  reaction=[%s]  left=%s/%s  status=%s',
        tostring(dig(o, 'id')),
        ename(df.job_type, dig(o, 'job_type')),
        tostring(dig(o, 'reaction_name')),
        tostring(dig(o, 'amount_left')),
        tostring(dig(o, 'amount_total')),
        tostring(st and dig(st, 'whole')))
end

-- ---- SHARED JOB REPORTING ----

-- Prints the filters DF generated from the reagents. job_items moved
-- inside an elements wrapper on newer builds, so both shapes are
-- tried and the one that resolves is used.
local function dump_filters(job)
    local jis = dig(job, 'job_items')
    if jis and dig(jis, 'elements') then jis = jis.elements end
    if not jis then
        print('    (job_items unreadable on this build)')
        return
    end
    for i, ji in ipairs(jis) do
        print(string.format(
            '    filter[%d] item_type=%s mat=%s/%s qty=%d vector=%s',
            i, ename(df.item_type, ji.item_type),
            tostring(ji.mat_type), tostring(ji.mat_index),
            ji.quantity,
            ename(df.job_item_vector_id, ji.vector_id)))
        local hmrp = dig(ji, 'has_material_reaction_product')
        if hmrp and hmrp ~= '' then
            print('      has_material_reaction_product=[' .. hmrp .. ']')
        end
    end
end

-- Prints every item attached to the job right now. Containers get
-- their contents listed one level deep: the crux question is whether
-- the tar appears as its own attachment or only inside the vessel.
local function dump_attachments(job)
    for _, ref in ipairs(job.items) do
        local role = ename(df.job_item_ref.T_role, ref.role)
        print('    attached (' .. role .. '): ' .. item_line(ref.item))
        local ok, contents = pcall(dfhack.items.getContainedItems,
            ref.item)
        if ok and contents then
            for _, c in ipairs(contents) do
                print('      holds: ' .. item_line(c))
            end
        end
    end
end

-- Compact signature of the current attachment set, so the dump only
-- prints when the set changes.
local function attach_sig(job)
    local ids = {}
    for _, ref in ipairs(job.items) do ids[#ids + 1] = ref.item.id end
    table.sort(ids)
    return table.concat(ids, ',')
end

-- One header line for any sighted job, whatever its origin.
local function job_line(job)
    local holder = nil
    pcall(function() holder = dfhack.job.getHolder(job) end)
    return string.format(
        'job #%d  type=%s  reaction=[%s]  suspend=%s  holder=%s',
        job.id,
        ename(df.job_type, job.job_type),
        tostring(dig(job, 'reaction_name')),
        tostring(dig(dig(job, 'flags'), 'suspend')),
        holder and ('building #' .. holder.id) or 'none')
end

-- Scan for items created after the job was first seen. Reports
-- everything, not just expected products: an unexpected item is
-- evidence too.
local function dump_new_items(base_item)
    local n = 0
    for _, item in ipairs(df.global.world.items.all) do
        if item.id >= base_item then
            n = n + 1
            if n <= 15 then
                local mi = dig(item, 'mat_index')
                local tag = (dig(item, 'mat_type') == 0
                    and product_indices[mi])
                    and '  <== EXPECTED PRODUCT' or ''
                print('    new: ' .. item_line(item) .. tag)
            end
        end
    end
    if n == 0 then
        print('    NO items created during the job. This is the')
        print('    no-product bug, caught live.')
    elseif n > 15 then
        print('    ... and ' .. (n - 15) .. ' more.')
    end
end

-- ---- WATCHER STATE ----
-- tracked: per-job, keyed by id. sig is the last printed attachment
-- signature, base_item the item-id watermark at first sight.
-- order_sig / retort_sigs: last printed pictures for nets 1 and 2.
local tracked = {}
local order_sig = nil
local retort_sigs = {}

-- Sight a job (from either net), print on first sight, dump
-- attachments on change. Shared so nets 2 and 3 report identically.
local function sight(job, via)
    local t = tracked[job.id]
    if not t then
        t = { sig = '', base_item = df.global.item_next_id }
        tracked[job.id] = t
        print('')
        print('[pitch-probe] sighted via ' .. via .. ': ' ..
            job_line(job))
        dump_filters(job)
    end
    local sig = attach_sig(job)
    if sig ~= t.sig then
        t.sig = sig
        print('[pitch-probe] job #' .. job.id .. ' attachments now:')
        if sig == '' then
            print('    (none attached yet)')
        else
            dump_attachments(job)
        end
    end
end

local function poll()
    -- ---- NET 1: manager orders ----
    -- The whole matching-order picture as one signature; printed on
    -- change. amount_left never moving while no job appears is the
    -- manager refusing to dispatch.
    local vec = manager_order_vec()
    if vec then
        local lines = {}
        local ok = pcall(function()
            for _, o in ipairs(vec) do
                local rn = dig(o, 'reaction_name')
                if rn and rn:find(NEEDLE, 1, true) then
                    lines[#lines + 1] = order_line(o)
                end
            end
        end)
        if ok then
            local sig = table.concat(lines, '\n')
            if sig ~= order_sig then
                order_sig = sig
                print('')
                if #lines == 0 then
                    print('[pitch-probe] no matching manager orders.')
                else
                    print('[pitch-probe] manager orders now:')
                    for _, l in ipairs(lines) do print('  ' .. l) end
                end
            end
        end
    end

    -- ---- NET 2: retort building queues ----
    for _, b in ipairs(retorts) do
        local ids = {}
        for _, job in ipairs(b.jobs) do ids[#ids + 1] = job.id end
        table.sort(ids)
        local sig = table.concat(ids, ',')
        if sig ~= retort_sigs[b.id] then
            retort_sigs[b.id] = sig
            print('')
            print('[pitch-probe] building #' .. b.id ..
                ' queue now: [' .. sig .. ']')
        end
        for _, job in ipairs(b.jobs) do
            sight(job, 'building #' .. b.id)
        end
    end

    -- ---- NET 3: global list, identity-agnostic ----
    -- seen is built here and only here: every workshop job lives in
    -- this list, so vanishing from it is the end-of-job signal for
    -- everything tracked, including net 2 sightings.
    local seen = {}
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        local rn = dig(job, 'reaction_name')
        local named = rn and rn:find(NEEDLE, 1, true)
        local holder = nil
        pcall(function() holder = dfhack.job.getHolder(job) end)
        local at_retort = holder and retort_ids[holder.id]
        if named or at_retort then
            seen[job.id] = true
            sight(job, named and 'name match' or 'retort holder')
        end
    end

    -- ---- END OF JOB: THE AUDIT ----
    for id, t in pairs(tracked) do
        if not seen[id] then
            print('')
            print('[pitch-probe] job #' .. id ..
                ' left the world. items created since sighting:')
            dump_new_items(t.base_item)
            print('[pitch-probe] watcher stays armed.' ..
                ' run refinish-pitch-probe stop when done.')
            tracked[id] = nil
        end
    end
end

repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
print('')
print('watcher armed. polling every 5 frames.')
print('run the boil BOTH ways if you can: from the retort task menu,')
print('and as a manager order. each path reports here as it goes.')