-- refinish-range-probe.lua  (replace prior version)
-- Same-pixels-different-path test. Requires retort_probe.png, a
-- byte copy of retort.png in the same folder. A never-seen path
-- cannot hit the textures module's per-path dedup, so this is the
-- first genuinely fresh mid-process load we have run.
local base = nil
for k in pairs(_G.refinish_texture_cache or {}) do
    if k:find('retort.png', 1, true) then base = k end
end
if not base then print("retort.png not in cache") return end

local probe_path = base:gsub('retort%.png$', 'retort_probe.png')
print('loading never-seen path:', probe_path)

local fresh = dfhack.textures.loadTileset(probe_path, 32, 32, false)
if not fresh or #fresh == 0 then print("load returned nothing") return end

local CELL = 2 * 24 + 1 + 1   -- sheet cell (1,2), center of finished art
local v = dfhack.textures.getTexposByHandle(fresh[CELL])
print(string.format('%d handles; center cell resolves -> %s', #fresh, tostring(v)))

for _, d in ipairs(df.global.world.raws.buildings.all) do
    if d.code == 'MAKING_FUEL_RETORT' and v and v > 0 then
        d.graphics_normal[3][1][2] = v
        print('center tile written. LOOK AT A FINISHED RETORT NOW.')
    end
end