-- refinish-menu-icon.lua
-- ==========================================
-- BUILD MENU ICON: SURVEY AND WRITE
-- ==========================================
-- The build menu lives at main_interface.construction: page[N]
-- category tabs, bb_button[M] building buttons, each with a
-- STORED texpos. Found by value-hunting the generic icon texpos.
--
--   refinish-menu-icon              survey + auto-write retort
--   refinish-menu-icon P B          force-write page P button B
--   refinish-menu-icon P B revert   restore the generic icon
--
-- Auto mode matches any string field on a button containing
-- 'retort' (case-insensitive) and writes the retort def's
-- list_icon_texpos into it. Open the build menu after running.
-- ==========================================

local args = {...}
local con = df.global.game.main_interface.construction

-- ---- the value to write: the retort's own icon, read live ----
local new_tex = nil
for _, d in ipairs(df.global.world.raws.buildings.all) do
    if d.code == 'MAKING_FUEL_RETORT' then new_tex = d.list_icon_texpos end
end

-- ---- generic icon for revert ----
local generic = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'BUILDING_ICONS' then generic = p.texpos[0] break end
end

print(string.format("retort icon texpos: %s   generic: %s",
    tostring(new_tex), tostring(generic)))

-- ---- forced write path ----
if args[1] and args[2] then
    local p, b = tonumber(args[1]), tonumber(args[2])
    local btn = con.page[p].bb_button[b]
    local before = btn.texpos
    btn.texpos = (args[3] == 'revert') and generic or new_tex
    print(string.format("page %d button %d: texpos %d -> %d. Open the menu.",
        p, b, before, btn.texpos))
    return
end

-- ---- survey ----
if not con.page or #con.page == 0 then
    print("construction.page is empty. Open the build menu once, then rerun.")
    return
end

-- Field list of the button class, once, from the first button.
local shown_fields = false
local target_p, target_b = nil, nil

for p = 0, #con.page - 1 do
    local pg = con.page[p]
    local n = 0
    pcall(function() n = #pg.bb_button end)
    print(string.format("---- page %d: %d button(s) ----", p, n))

    for b = 0, n - 1 do
        local btn = pg.bb_button[b]

        if not shown_fields then
            print("  button fields:")
            pcall(function()
                for k, v in pairs(btn) do
                    print(string.format("    %-24s %s", tostring(k), type(v)))
                end
            end)
            shown_fields = true
        end

        -- One line per button: texpos plus every string field.
        local tex = -1
        pcall(function() tex = btn.texpos end)
        local strs = {}
        pcall(function()
            for k, v in pairs(btn) do
                if type(v) == 'string' and v ~= '' then
                    table.insert(strs, tostring(k) .. '=' .. v)
                    if v:lower():find('retort') then
                        target_p, target_b = p, b
                    end
                end
            end
        end)
        print(string.format("  [%d][%2d] texpos=%-8d %s",
            p, b, tex, table.concat(strs, '  ')))
    end
end

-- ---- auto write ----
if target_p and new_tex then
    local btn = con.page[target_p].bb_button[target_b]
    local before = btn.texpos
    btn.texpos = new_tex
    print(string.format(
        "WROTE page %d button %d: texpos %d -> %d. OPEN THE BUILD MENU AND LOOK.",
        target_p, target_b, before, btn.texpos))
    print(string.format("revert: refinish-menu-icon %d %d revert", target_p, target_b))
elseif not target_p then
    print("No button labeled retort found. Write by index: refinish-menu-icon P B")
end