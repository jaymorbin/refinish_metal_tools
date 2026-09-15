--@ module = true
-- refinish-guard-probe.lua  (v2)
-- ==========================================
-- READ ONLY: VERIFY THE COMPLETION-FRAME CONTRACT
-- ==========================================
-- Before writing a product guard that rewrites a forged item's
-- material, we confirm three facts on the live game, because the
-- guard depends on all three and none should be assumed:
--
--   F1  Does onItemCreated hand us a route from the new item back
--       to the job that made it, so the guard can read the job's
--       material pin? Route A: a job field on the item. Route B:
--       the item's specific_refs. Route C: general_refs, listed
--       for discovery.
--
--   F2  At the instant the product exists, does the job still carry
--       the material the player picked (job.mat_type / mat_index)?
--       If the pin is intact and correct, it is the source of truth
--       the guard writes from.
--
--   F3  What is the created weapon's own material, read directly
--       and cross checked with matinfo.decode, so the guard writes
--       the field DF actually uses.
--
-- OUTPUT ROUTING (v2): every report line goes to the RM log via
-- refinish_log_event, which the log panel shows and which appends
-- to refinish_session.log on disk. Lines are ALSO buffered in RAM;
-- the report command replays the full buffer to the console.
-- print() alone is never used for event time output: an event
-- callback's print lands in the DFHack terminal, which the player
-- is not watching. That mistake is why v1 appeared silent.
--
-- HOW TO USE:
--   1) Load the fort. Have blue or red steel bars in stock.
--   2) refinish-guard-probe start
--   3) Forge a weapon from those bars at a NORMAL (non magma)
--      forge, so the fuel slot is widened.
--   4) refinish-guard-probe report     full dump to the console
--   5) refinish-guard-probe stop
--
-- Changes nothing in the game. It only reads and reports.
-- ==========================================

local eventful = require('plugins.eventful')

local REPEAT_KEY = 'refinish_guard_probe'
local LOG_TAG    = 'GUARD PROBE: '
local raws = df.global.world.raws.inorganics.all

-- ==========================================
-- OUTPUT PLUMBING
-- ==========================================
-- One line, three destinations: RAM buffer for the report command,
-- the RM log panel, and the on disk session log (refinish_log_event
-- appends there itself). Falls back to print only when RM's logger
-- is absent, in which case the console is all there is.
local buffer  = {}
local skipped = {}   -- item type name -> count, for non target items

local function out(msg)
    table.insert(buffer, msg)
    if _G.refinish_log_event then
        _G.refinish_log_event(LOG_TAG .. msg)
    else
        print(LOG_TAG .. msg)
    end
end

-- ==========================================
-- HELPERS
-- ==========================================
local function inorg_id(mat_index)
    if mat_index ~= nil and mat_index >= 0 and mat_index < #raws then
        return raws[mat_index].id
    end
    return "(not an inorganic index)"
end

-- Defensive field read.
local function field(obj, name)
    local ok, v = pcall(function() return obj[name] end)
    if ok then return v end
    return nil
end

-- ==========================================
-- F1: EVERY ROUTE FROM ITEM TO JOB
-- ==========================================
-- Route A: a direct job reference on the item, if this build has
-- one. Usually nil; checked so the report can say so.
local function job_via_item_field(it)
    local j = nil
    pcall(function() j = it.job_ref end)
    return j
end

-- Route B: specific_refs. A product awaiting haul often carries a
-- ref here; if any ref exposes a .job, we take it.
local function job_via_specific_refs(it)
    local found = nil
    pcall(function()
        for _, ref in ipairs(it.specific_refs) do
            out(string.format("    specific_ref type: %s", tostring(ref._type)))
            local j = nil
            pcall(function() j = ref.job end)
            if j then found = j end
        end
    end)
    return found
end

-- Route C: general_refs, DISCOVERY ONLY. These types are listed so
-- we can see what DF attaches; none is expected to carry a job. If
-- one shows up that plainly does, the guard gains a route.
local function job_via_general_refs(it)
    pcall(function()
        for _, ref in ipairs(it.general_refs) do
            out(string.format("    general_ref type: %s", tostring(ref._type)))
        end
    end)
    return nil
end

-- ==========================================
-- F2 / F3: REPORT A CREATED ITEM
-- ==========================================
local report_count = 0

local function report_item(it)
    local itype = it:getType()
    local itype_name = df.item_type[itype] or tostring(itype)

    -- Only BAR and WEAPON get the full report. Everything else is
    -- counted silently and summarised at stop and in the report, so
    -- a busy fort does not flood the log.
    if itype ~= df.item_type.BAR and itype ~= df.item_type.WEAPON then
        skipped[itype_name] = (skipped[itype_name] or 0) + 1
        return
    end

    report_count = report_count + 1
    out("========================================")
    out(string.format("CREATED ITEM #%d: %s (item id %s)",
        report_count, itype_name, tostring(it.id)))

    -- ---- F3: the item's own material ----
    local mt = field(it, "mat_type")
    local mi = field(it, "mat_index")
    out(string.format("  item.mat_type=%s item.mat_index=%s -> %s",
        tostring(mt), tostring(mi),
        (mt == 0) and inorg_id(mi) or "(mat_type not inorganic)"))

    -- Cross check via matinfo, the accessor the coal watcher trusts.
    pcall(function()
        local info = dfhack.matinfo.decode(it)
        if info then
            out(string.format("  matinfo -> type=%s index=%s token=%s",
                tostring(info.type), tostring(info.index),
                tostring(info:getToken())))
        else
            out("  matinfo -> nil")
        end
    end)

    -- ---- F1: find the job that made this item ----
    out("  routes from item to job:")
    local jA = job_via_item_field(it)
    out(string.format("    route A (item field): %s",
        jA and "JOB FOUND" or "none"))
    local jB = job_via_specific_refs(it)
    out(string.format("    route B (specific_refs): %s",
        jB and "JOB FOUND" or "none"))
    job_via_general_refs(it)
    out("    route C (general_refs): listed above, discovery only")

    local job = jA or jB

    -- ---- F2: the job's material pin ----
    if job then
        local jt = field(job, "job_type")
        local jt_name = jt and (df.job_type[jt] or tostring(jt)) or "?"
        local jmt = field(job, "mat_type")
        local jmi = field(job, "mat_index")
        out(string.format("  JOB type=%s job.mat_type=%s job.mat_index=%s -> %s",
            jt_name, tostring(jmt), tostring(jmi),
            (jmt == 0) and inorg_id(jmi) or "(mat_type not inorganic)"))

        -- The verdict this probe exists to produce.
        if jmt ~= nil and jmi ~= nil and mt ~= nil and mi ~= nil then
            if jmt == mt and jmi == mi then
                out("  VERDICT: product MATCHES job pin (no swap here).")
            else
                out("  VERDICT: product DIFFERS from job pin (the swap).")
                out(string.format("    pin says   %s", inorg_id(jmi)))
                out(string.format("    product is %s", inorg_id(mi)))
            end
        end
    else
        out("  JOB: no route reached a job from this item.")
        out("  If this holds for the weapon, the guard watches")
        out("  onJobCompleted and reads produced items instead.")
    end
end

-- ==========================================
-- TRIGGER
-- ==========================================
local function on_created(item_id)
    pcall(function()
        if not dfhack.isMapLoaded() then return end
        local it = df.item.find(item_id)
        if it then report_item(it) end
    end)
end

-- ==========================================
-- PUBLIC API
-- ==========================================
function start()
    buffer, skipped, report_count = {}, {}, 0
    eventful.onItemCreated[REPEAT_KEY] = on_created
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, 0)
    out("armed. Forge a weapon from steel bars at a normal forge.")
    -- Direct console instructions too: start is typed at the
    -- console, so this print is visible where the player is.
    print("GUARD PROBE: armed. Reports go to the RM log panel and")
    print("refinish_session.log as they happen. When the weapon is")
    print("made, run: refinish-guard-probe report")
end

function stop()
    eventful.onItemCreated[REPEAT_KEY] = nil
    out(string.format("disarmed. %d detailed report(s) captured.",
        report_count))
    print("GUARD PROBE: disarmed. Full dump: refinish-guard-probe report")
end

-- Console replay of everything captured, plus the skip summary.
-- Plain print on purpose: report is typed at the console, and the
-- console is exactly where the answer should land.
function report()
    if #buffer == 0 then
        print("GUARD PROBE: nothing captured yet.")
        return
    end
    print("========================================")
    print("GUARD PROBE: FULL CAPTURE (" .. #buffer .. " lines)")
    print("========================================")
    for _, line in ipairs(buffer) do print(line) end
    local any = false
    for name, n in pairs(skipped) do
        if not any then
            any = true
            print("---- other items created while armed ----")
        end
        print(string.format("  %s x%d", name, n))
    end
    print("========================================")
end

if dfhack_flags and dfhack_flags.module then return end
local args = {...}
if args[1] == 'start' then start()
elseif args[1] == 'stop' then stop()
elseif args[1] == 'report' then report()
else print('usage: refinish-guard-probe start | report | stop') end