-- refinish-wsgi-dump.lua
-- Full-truth dump of workshop_graphics_info entries.
--   refinish-wsgi-dump              all entries: flags + shape map
--   refinish-wsgi-dump <i>          one entry, every nonzero coord
-- Shape map = per stage: count + x-range + y-range + value range,
-- which settles main/overlay-in-entry vs twin without 500 lines.
local args = {...}
local pick = tonumber(args[1])
local vec = df.global.world.raws.buildings.workshop_graphics_info

for i = 0, #vec - 1 do
    if not pick or pick == i then
        local g = vec[i]
        local w = 0
        pcall(function() w = g.flags.whole end)
        local sub = math.floor(w / 256) % 65536
        print(string.format(
            "entry %d  flags=0x%08x  color=%d subtype=%d furnace=%s depot=%s planned=%s frame2=%s",
            i, w, w % 256, sub,
            tostring(math.floor(w / 2^24) % 2 == 1),
            tostring(math.floor(w / 2^25) % 2 == 1),
            tostring(math.floor(w / 2^26) % 2 == 1),
            tostring(math.floor(w / 2^27) % 2 == 1)))
        for s = 0, 3 do
            local n, xs, ys, vmin, vmax = 0, {}, {}, nil, nil
            for x = 0, 30 do
                for y = 0, 31 do
                    local ok, v = pcall(function() return g.texpos[s][x][y] end)
                    if ok and v and v ~= 0 then
                        n = n + 1
                        xs[x] = true ys[y] = true
                        if not vmin or v < vmin then vmin = v end
                        if not vmax or v > vmax then vmax = v end
                        if pick then
                            print(string.format("    [%d][%d][%d] = %d", s, x, y, v))
                        end
                    end
                end
            end
            if n > 0 then
                local xlo, xhi, ylo, yhi = 99, -1, 99, -1
                for x in pairs(xs) do xlo = math.min(xlo, x) xhi = math.max(xhi, x) end
                for y in pairs(ys) do ylo = math.min(ylo, y) yhi = math.max(yhi, y) end
                print(string.format(
                    "  stage %d: %d cells  x %d..%d  y %d..%d  tex %d..%d",
                    s, n, xlo, xhi, ylo, yhi, vmin, vmax))
            end
        end
    end
end