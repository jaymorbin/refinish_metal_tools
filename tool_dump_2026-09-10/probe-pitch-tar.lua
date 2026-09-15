-- probe-pitch-tar.lua
-- ==========================================
-- ONE PURPOSE: watch what a first generation tar item's dimension
-- does across a boil. The ghost settles a pitch cycle as burned only
-- when the tar inside the jug DRAINS, seen as a drop in .dimension.
-- The session log shows that settle never firing: every boil reads a
-- fresh zero purse. This measures the single value that decides it,
-- so we stop inferring live state through the project mirror.
--
-- Run it, queue a boil, let it complete, run it again. Compare the
-- dimension line across the two runs.
--   dfhack> lua dofile('probe-pitch-tar.lua')
-- Or aim it at a specific tar id the log named:
--   dfhack> lua dofile('probe-pitch-tar.lua') 1098
-- ==========================================

local target_id = ...
if type(target_id) == 'string' then target_id = tonumber(target_id) end

local function tar_products(mi)
    -- Does this material derive a PITCH_MAT product, i.e. is it a
    -- first generation tar the boil consumes? Read with .value; a
    -- tostring on the reaction_product id entries prints a pointer.
    local hits = {}
    pcall(function()
        local rp = mi.material.reaction_product
        for i = 0, #rp.id - 1 do
            table.insert(hits, tostring(rp.id[i].value))
        end
    end)
    return hits
end

local function describe_tar(it)
    local id   = it.id
    local mt   = it.mat_type
    local mi_i = it.mat_index
    local dim  = '(none)'
    pcall(function() if it.dimension then dim = tostring(it.dimension) end end)
    local stack = 1
    pcall(function() stack = it.stack_size or 1 end)

    -- Container, via the general ref walk. A first gen tar lives inside
    -- a preserved jug, so this should name that jug.
    local held_by = '(loose)'
    pcall(function()
        local c = dfhack.items.getContainer(it)
        if c then
            held_by = string.format('#%d %s', c.id,
                dfhack.items.getDescription(c, 0))
        end
    end)

    -- Material identity and whether it is a pitch precursor.
    local matname = '(unreadable)'
    local pitch = 'no'
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        if mi then
            matname = mi.id or tostring(mi)
            local hits = tar_products(mi)
            for _, h in ipairs(hits) do
                if h == 'PITCH_MAT' then pitch = 'YES' end
            end
            if #hits > 0 then
                matname = matname .. '  products{' ..
                    table.concat(hits, ',') .. '}'
            end
        end
    end)

    print(string.format(
        'tar #%d  mat_type=%s mat_index=%s  %s',
        id, tostring(mt), tostring(mi_i), matname))
    print(string.format(
        '   dimension=%s  stack=%d  pitch_precursor=%s',
        dim, stack, pitch))
    print('   held_by=' .. held_by)
end

-- ---- WHICH ITEMS ----
-- A specific id if given, else every LIQUID_MISC item in the world
-- that derives PITCH_MAT, which is the set the boil feeds on.
print('==== PITCH TAR PROBE ====')
if target_id then
    local it = df.item.find(target_id)
    if not it then
        print('no item with id ' .. target_id)
        return
    end
    describe_tar(it)
else
    local found = 0
    for _, it in ipairs(df.global.world.items.all) do
        if it:getType() == df.item_type.LIQUID_MISC
           and it.mat_type == 0 and it.mat_index >= 0 then
            local is_pitch = false
            pcall(function()
                local mi = dfhack.matinfo.decode(it)
                for _, h in ipairs(tar_products(mi)) do
                    if h == 'PITCH_MAT' then is_pitch = true end
                end
            end)
            if is_pitch then
                describe_tar(it)
                found = found + 1
            end
        end
    end
    if found == 0 then
        print('no first generation tar (PITCH_MAT precursor) in world')
    else
        print('---- ' .. found .. ' pitch precursor tar item(s) ----')
    end
end

-- ---- ANY LIVE BOIL JOB ----
-- Names the tar each boil job has attached, so a completed boil can
-- be matched to the item whose dimension should have dropped.
print('---- live boil/refine jobs ----')
local any = false
for _, job in ipairs(df.global.world.jobs.list) do
    if job.job_type == df.job_type.CustomReaction then
        local rn = tostring(job.reaction_name)
        if rn:find('BOIL_PITCH') or rn:find('BOIL_BITUMEN')
           or rn:find('REFINE_TAR') then
            any = true
            local working = false
            pcall(function() working = job.flags.working end)
            print(string.format('job %d  %s  working=%s  items=%d',
                job.id, rn, tostring(working), #job.items))
            for _, iref in ipairs(job.items) do
                local it = iref.item
                local inside = {}
                pcall(function()
                    for _, cc in ipairs(dfhack.items.getContainedItems(it)) do
                        local d = '?'
                        pcall(function() d = cc.dimension end)
                        table.insert(inside, string.format(
                            '#%d dim=%s', cc.id, tostring(d)))
                    end
                end)
                local desc = '?'
                pcall(function() desc = dfhack.items.getDescription(it, 0) end)
                print(string.format('   item #%d %s  contains: %s',
                    it.id, desc,
                    #inside > 0 and table.concat(inside, ', ') or '(nothing)'))
            end
        end
    end
end
if not any then print('   none queued') end
print('==== END ====')
