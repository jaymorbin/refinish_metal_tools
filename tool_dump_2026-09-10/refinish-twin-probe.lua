-- refinish-twin-probe.lua
-- ==========================================
-- THREE QUESTIONS, ONE FILL, TWO LOOKS
-- Both custom furnace twins get COMPLETE main art (known-good v1
-- config), plus markers:
--   twin2 only: CENTER cell of every stage = soap tile
--   both twins: TOP-LEFT of stage 3 = soap tile
-- Look 1, idle: which retorts show a soap CENTER (= twin2
--   selected)? Static split -> parity selection. Blinking -> the
--   twins are animation frames ticking even when idle.
-- Look 2, run a job at one retort and watch it: TOP-LEFT soap
--   appearing on ignition = stage 3 is the LIT state.
--   refinish-twin-probe          fill + mark
--   refinish-twin-probe revert   zero both twins
-- ==========================================
local args = {...}
_G.refinish_twin_undo = _G.refinish_twin_undo or {}

local vec = df.global.world.raws.buildings.workshop_graphics_info

if args[1] == 'revert' then
    local n = 0
    for _, u in ipairs(_G.refinish_twin_undo) do
        pcall(function() u.node[u.idx] = u.old n = n + 1 end)
    end
    _G.refinish_twin_undo = {}
    print(string.format('reverted %d cell(s).', n))
    return
end

local path = nil
for k in pairs(_G.refinish_texture_cache or {}) do
    if k:find('retort%.png$') then path = k end
end
if not path then print('retort.png not in texture cache') return end
local tex = _G.refinish_texture_cache[path]

local ws = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'WORKSHOPS' then ws = p break end
end
local soap = ws.texpos[62 * ws.page_dim_x + 1]

local twins = {}
for i = 0, #vec - 1 do
    local g = vec[i]
    local isf, sub = false, -1
    pcall(function() isf = g.flags.is_furnace end)
    pcall(function() sub = g.flags.subtype end)
    if isf and sub and sub > 7 then table.insert(twins, g) end
end
if #twins < 2 then print('need two custom furnace entries, found ' .. #twins) return end

local function wr(g, s, x, y, v)
    local ok, old = pcall(function() return g.texpos[s][x][y] end)
    if ok then
        table.insert(_G.refinish_twin_undo, { node = g.texpos[s][x], idx = y, old = old })
        g.texpos[s][x][y] = v
    end
end

for n, g in ipairs(twins) do
    -- zero, then complete main art in every stage
    for s = 0, 3 do for x = 0, 30 do for y = 0, 31 do
        local ok, v = pcall(function() return g.texpos[s][x][y] end)
        if ok and v ~= 0 then wr(g, s, x, y, 0) end
    end end end
    for s = 0, 3 do
        for x = 0, 2 do
            for y = 0, 3 do
                local h = tex.handles[y * 24 + (3 - s) * 3 + x + 1]
                local v = h and dfhack.textures.getTexposByHandle(h)
                if v and v > 0 then wr(g, s, x, y, v) end
            end
        end
    end
    if n == 2 then
        for s = 0, 3 do wr(g, s, 1, 2, soap) end   -- center marker, twin2
    end
    wr(g, 3, 0, 1, soap)                            -- stage-3 top-left, both
    print(string.format('twin %d filled%s', n, n == 2 and ' + center marker' or ''))
end
print('LOOK 1 idle: note WHICH retorts have a soap CENTER, and whether it blinks.')
print('LOOK 2: run a job at one retort, watch its TOP-LEFT tile.')