-- refinish-rot-flag-probe.lua
-- =====================================================================
-- REAGENT FLAG DUMP
-- The engine's reagent filters write job item flag bitfields. This
-- prints every named bit in all three groups, straight from the
-- running DF's own enums, so the question "is there a bit that
-- REQUIRES rot" is answered by the binary rather than by a comment.
--
-- Reading the result:
--   * A bit whose name suggests requiring rot (rotten, rot_only, or
--     similar) means CHAR_ROT and RETORT_ROT can be plain reactions:
--     expose the bit in refinish-module-react.lua's flag map and
--     filter on it.
--   * Only 'unrotten' present means the reagent side cannot demand
--     rot, and distinct disposal is the job binding script instead:
--     select items where item.flags.rotten is true and post char
--     jobs with those items attached.
--
-- Also confirms item.flags.rotten itself, for the binding path.
-- No world needs to be loaded.
-- =====================================================================

local function dump_group(label, enum)
    print('== ' .. label .. ' ==')
    local found = 0
    for i = 0, 63 do
        local name = enum[i]
        if name then
            print(('  %2d  %s'):format(i, name))
            found = found + 1
        end
    end
    if found == 0 then print('  (no named bits)') end
    print('')
end

dump_group('job_item_flags1', df.job_item_flags1)
dump_group('job_item_flags2', df.job_item_flags2)
dump_group('job_item_flags3', df.job_item_flags3)

-- The item-side flag the binding path selects on.
local ok = df.item_flags.rotten ~= nil
print('item_flags.rotten exists: ' .. tostring(ok))
print('')
print('Grep the three groups above for anything that reads as a rot')
print('REQUIREMENT. unrotten alone means the binding script is the')
print('mechanism; a requiring bit means one line in the react flag')
print('map and two new reactions.')
