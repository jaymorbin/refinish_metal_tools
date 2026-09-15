-- refinish-button-probe.lua  (replace prior version)
-- ==========================================
-- Uses the access pattern proven in making-concrete-sand-button:
-- index, _type, fields. No vmethod calls until the safe reads
-- succeed, because filtered_button holds STALE POINTERS when its
-- panel is not live (documented in the sand button code, gate 1).
--
-- RUN WITH THE BUILD MENU OPEN ON THE WORKSHOP LIST, and check
-- that both vectors are populated: stale state is #button == 0.
-- ==========================================

local b = df.global.game.main_interface.building
print(string.format("button: %d   filtered_button: %d", #b.button, #b.filtered_button))

if #b.button == 0 then
    print("MASTER VECTOR EMPTY: these are stale pointers. Not reading them.")
    print("Open the build menu first, then run again.")
    return
end

for i = 0, #b.button - 1 do
    local e = b.button[i]
    local tname, fstr, code = '?', '', ''
    pcall(function() tname = tostring(e._type) end)
    pcall(function() fstr = tostring(e.filter_str) end)
    pcall(function() code = tostring(e.bd.code) end)

    local tile_s = 'n/a'
    pcall(function() tile_s = tostring(e:tile()) end)

    print(string.format("  [%2d] %-55s filter=%-18s bd=%-28s tile=%s",
        i, tname, fstr, code, tile_s))
end