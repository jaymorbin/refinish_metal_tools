-- refinish-render-probe.lua
-- ==========================================
-- Discriminates DEF RESOLUTION vs PIXELS for completed buildings.
-- Writes the soap maker's finished center tile (vanilla WORKSHOPS
-- page, parsed pixels, provably renderable) into stage 3 center of
-- whichever def the FIRST placed retort resolves via custom_type.
-- Then: look at the completed retort.
--   center shows soap maker art -> def and grid path fine,
--       our pixels are dead; texture side confirmed
--   center stays bare -> completed rendering is not reading this
--       def; identity problem, and the survey below shows it
-- ==========================================

-- ---- survey: every def ----
print("---- DEFS ----")
for i, d in ipairs(df.global.world.raws.buildings.all) do
    print(string.format("  pos %d id %d %-28s grid[3][1][2]=%d icon=%d",
        i, d.id, d.code, d.graphics_normal[3][1][2], d.list_icon_texpos))
end

-- ---- survey: every placed custom ----
local ids = {}
for _, d in ipairs(df.global.world.raws.buildings.all) do ids[d.id] = d end
print("---- PLACED ----")
local first = nil
for _, b in ipairs(df.global.world.buildings.all) do
    local ok, ct = pcall(function() return b:getCustomType() end)
    if ok and ct and ct >= 0 then
        local d = ids[ct]
        print(string.format("  building %d custom_type %d -> %s",
            b.id, ct, d and d.code or "*** NO DEF ***"))
        if d and d.code == 'MAKING_FUEL_RETORT' and not first then first = d end
    end
end
if not first then print("no placed retort resolves; survey above is the answer") return end

-- ---- vanilla pixel source ----
local ws = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'WORKSHOPS' then ws = p break end
end
if not ws then print("WORKSHOPS page not found") return end
local v = ws.texpos[62 * ws.page_dim_x + 1]   -- soap maker finished, center tile
print(string.format("writing vanilla texpos %d into %s stage 3 center (was %d)",
    v, first.code, first.graphics_normal[3][1][2]))
first.graphics_normal[3][1][2] = v
print("LOOK AT THE COMPLETED RETORT'S CENTER TILE NOW.")