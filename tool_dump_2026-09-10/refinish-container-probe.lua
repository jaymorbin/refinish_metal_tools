--@ module = true
-- refinish-container-probe.lua
-- =====================================================================
-- ONE QUESTION: what does DF do to CONTENTS when a reaction consumes
-- a filled container? Everything in the unempty-burn design hangs on
-- this, and the empty flag has hidden the answer from us forever.
--
-- PROTOCOL. Stock exactly one FILLED wooden chest and nothing else
-- the furniture burn can take. Queue make ash from furniture at a
-- wood furnace. Run arm() while the job is queued: it strips the
-- empty gate from that one live job and records every content item
-- id. Let it burn. Run sweep(): each recorded id is hunted in the
-- world and reported alive-with-position or gone. RAM only; the
-- reaction itself is never edited, and a recycle restores the gate.
-- =====================================================================
local utils = require('utils')
local armed = { job = nil, contents = {}, shell = nil }

local function say(s)
    print('CONTAINER PROBE: ' .. s)
    if _G.refinish_log_event then
        pcall(_G.refinish_log_event, 'CONTAINER PROBE: ' .. s)
    end
end

function arm()
    say('=== arm ===')
    local ok, err = pcall(function()
        -- jobs.list is a LINKED LIST; ipairs sees an empty array
        -- and reports no job while one sits right there. listpairs
        -- is the correct walk.
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            local name = tostring(job.reaction_name or '')
            if name:find('ASH_FURNITURE', 1, true) then
                for i = 0, #job.job_items.elements - 1 do
                    local el = job.job_items.elements[i]
                    local cleared = {}
                    -- The empty gate's home differs by flag word;
                    -- clear it wherever it answers, and say which.
                    pcall(function()
                        if el.flags1.empty then
                            el.flags1.empty = false
                            table.insert(cleared, 'flags1')
                        end
                    end)
                    pcall(function()
                        if el.flags2.empty then
                            el.flags2.empty = false
                            table.insert(cleared, 'flags2')
                        end
                    end)
                    say(('job %d filter %d: empty cleared in [%s]')
                        :format(job.id, i, table.concat(cleared, ',')))
                end
                armed.job = job.id
                return
            end
        end
        say('no ASH_FURNITURE job found; queue it first.')
    end)
    if not ok then say('arm errored: ' .. tostring(err)) end
end

-- Call once the chest has been HAULED to the furnace (watch for it),
-- before completion: records the shell and its contents by id.
function mark()
    local ok, err = pcall(function()
        -- jobs.list is a LINKED LIST; ipairs sees an empty array
        -- and reports no job while one sits right there. listpairs
        -- is the correct walk.
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            if job.id == armed.job then
                for _, iref in ipairs(job.items) do
                    local it = iref.item
                    armed.shell = it.id
                    say(('shell item %d: %s'):format(it.id,
                        dfhack.items.getDescription(it, 0)))
                    for _, ref in ipairs(it.general_refs) do
                        pcall(function()
                            if ref:getType()
                               == df.general_ref_type.CONTAINS_ITEM then
                                local cid = ref.item_id
                                armed.contents[cid] = true
                                say(('  contains item %d'):format(cid))
                            end
                        end)
                    end
                end
                return
            end
        end
        say('armed job no longer live; too late to mark.')
    end)
    if not ok then say('mark errored: ' .. tostring(err)) end
end

function sweep()
    say('=== sweep ===')
    local ok, err = pcall(function()
        if not armed.shell then
            say('NEVER ARMED/MARKED THIS SESSION: nothing to sweep, '
                .. 'and consumed-claims from a fresh script are lies. '
                .. 'One already cost us.')
            return
        end
        local n = 0
        for cid in pairs(armed.contents) do
            n = n + 1
            local it = df.item.find(cid)
            if it then
                say(('content %d ALIVE: %s at %d,%d,%d')
                    :format(cid, dfhack.items.getDescription(it, 0),
                            it.pos.x, it.pos.y, it.pos.z))
            else
                say(('content %d GONE.'):format(cid))
            end
        end
        if n == 0 then
            say('no contents were certified before the burn; '
                .. 'GONE/ALIVE cannot be claimed from this run.')
        end
        local sh = df.item.find(armed.shell)
        say('shell ' .. (sh and 'still exists (burn failed?)'
                         or 'consumed.'))
    end)
    if not ok then say('sweep errored: ' .. tostring(err)) end
end