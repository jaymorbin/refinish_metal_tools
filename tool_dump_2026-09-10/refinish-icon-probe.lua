-- refinish-icon-probe.lua
-- Reverse-lookups a texpos against every loaded tile page.
-- A hit names the page and cell. A miss on every page means the
-- value was generated at runtime, not read from any image file.

local targets = {}
for _, a in ipairs({...}) do table.insert(targets, tonumber(a)) end

if #targets == 0 then
    for _, d in ipairs(df.global.world.raws.buildings.all) do
        if d.list_icon_texpos ~= 0 then
            table.insert(targets, d.list_icon_texpos)
            print(string.format("target %d from %s", d.list_icon_texpos, d.code))
        end
    end
end

for _, want in ipairs(targets) do
    local hit = false
    for _, p in ipairs(df.global.texture.page) do
        for i = 0, #p.texpos - 1 do
            if p.texpos[i] == want then
                print(string.format("  %d -> page [%s] cell col %d row %d (page %dx%d)",
                    want, tostring(p.token),
                    i % p.page_dim_x, math.floor(i / p.page_dim_x),
                    p.page_dim_x, p.page_dim_y))
                hit = true
                break
            end
        end
        if hit then break end
    end
    if not hit then
        print(string.format("  %d -> on no loaded page (runtime generated)", want))
    end
end