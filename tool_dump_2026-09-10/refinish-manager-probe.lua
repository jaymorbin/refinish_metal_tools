-- refinish-manager-probe.lua
-- ==========================================
-- THE MANAGER, READ OFF THE LIVE STRUCTS
-- ==========================================
-- Two surfaces, two modes.
--
--   CREATE SCREEN (default). game.main_interface.create_work_order
--   holds the candidate lists the New Work Order search offers:
--   jminfo_master is every template, and each building entry
--   carries its own jminfo slice. Four questions answered by one
--   dump: are module reactions offered at all (injection timing),
--   which buildings group them, do MakeCharcoal and MakeAsh still
--   speak here in vanilla's voice, and what the search box holds.
--
--   ORDER BOOK (orders). world.manager_orders, the standing orders
--   themselves. manager_order carries reaction_name as a string,
--   so a module order should survive the shutdown wash and find
--   its reaction again after reinjection; the save-reload leg of
--   the protocol is the measurement of that.
--
-- USAGE:
--   refinish-manager-probe            with the New Work Order
--                                     screen OPEN
--   refinish-manager-probe orders     any time
-- Read-only. Nothing here writes to the game.
-- ==========================================

local args = {...}

local function printf(fmt, ...) print(string.format(fmt, ...)) end

local function jobname(jt)
    return df.job_type[jt] or tostring(jt)
end

-- ==========================================
-- ORDER BOOK
-- ==========================================
if args[1] == 'orders' then
    local orders = df.global.world.manager_orders.all
    printf('')
    printf('== manager orders: %d ==', #orders)
    for i = 0, #orders - 1 do
        local o = orders[i]
        printf('   [%d] id=%d %s mstring=%q %d/%d freq=%s',
            i, o.id, jobname(o.job_type),
            tostring(o.reaction_name),
            o.amount_left, o.amount_total,
            tostring(df.workquota_frequency_type[o.frequency]
                     or o.frequency))
    end
    printf('')
    return
end

-- ==========================================
-- CREATE SCREEN
-- ==========================================
local ok, cwo = pcall(function()
    return df.global.game.main_interface.create_work_order
end)
if not ok or not cwo then
    print('game.main_interface.create_work_order not reachable;'
        .. ' report this line.')
    return
end

printf('')
printf('open=%s   forced_bld_id=%d   job_filter=%q',
    tostring(cwo.open), cwo.forced_bld_id,
    tostring(cwo.job_filter))

-- Templates carry either a hardcoded job type or CustomReaction
-- plus the reaction code. Grouping keeps hundreds readable; module
-- entries are split out by their prefix.
local function summarize(vec, label)
    printf('')
    printf('== %s: %d ==', label, #vec)
    local groups, order = {}, {}
    local function bump(k)
        if not groups[k] then groups[k] = 0 table.insert(order, k) end
        groups[k] = groups[k] + 1
    end
    for i = 0, #vec - 1 do
        local t = vec[i]
        if t.job_type == df.job_type.CustomReaction then
            local code = tostring(t.reaction_name)
            if code:find('MAKING_FUEL_', 1, true) == 1 then
                bump('CustomReaction / MAKING_FUEL')
            elseif code:find('MAKING_CONCRETE_', 1, true) == 1 then
                bump('CustomReaction / MAKING_CONCRETE')
            else
                bump('CustomReaction / other')
            end
        else
            bump(jobname(t.job_type))
        end
    end
    for _, k in ipairs(order) do
        printf('   %4d  %s', groups[k], k)
    end
    -- Verbatim rows for the questions at hand: the two hardcoded
    -- furnace jobs, plus a shape sample of module entries.
    local samples = 0
    for i = 0, #vec - 1 do
        local t = vec[i]
        local jt = jobname(t.job_type)
        local code = tostring(t.reaction_name)
        local hard = jt == 'MakeCharcoal' or jt == 'MakeAsh'
        local sample = code:find('MAKING_FUEL_', 1, true) == 1
                       and samples < 3
        if hard or sample then
            if sample then samples = samples + 1 end
            printf('   [%d] %s mstring=%q itype=%s mat=%d/%d',
                i, jt, code, tostring(t.item_type),
                t.mat_type, t.mat_index)
        end
    end
end

summarize(cwo.jminfo_master, 'jminfo_master (all templates)')

-- The per-building grouping the screen actually shows. custom_id
-- resolves injected workshops; a module building carrying module
-- templates here is the whole "does the manager know our
-- buildings" question answered.
printf('')
printf('== buildings: %d ==', #cwo.building)
for i = 0, #cwo.building - 1 do
    local b = cwo.building[i]
    local ours = 0
    for j = 0, #b.jminfo - 1 do
        local code = tostring(b.jminfo[j].reaction_name)
        if code:find('MAKING_FUEL_', 1, true) == 1 then
            ours = ours + 1
        end
    end
    printf('   [%d] %-28s type=%d sub=%d custom=%d templates=%d'
        .. ' making_fuel=%d',
        i, tostring(b.name), b.type, b.subtype, b.custom_id,
        #b.jminfo, ours)
end
printf('')
