-- refinish-bar-sprite-probe.lua
-- ==========================================
-- BAR SPRITE MAPPING PROBE
-- ==========================================
-- QUESTION: where does [BARS_GRAPHICS:PAGE:x:y:MAT] live at runtime,
-- and is it writable? Vanilla binds bar sprites per material token
-- (COAL:COKE at 0:4, COAL:CHARCOAL at 1:4 on ITEM_CONSTRUCTION), so
-- a material-to-texpos mapping for bars MUST exist in memory. This
-- probe finds it rather than guessing at it.
--
-- MODES:
--   refinish-bar-sprite-probe          read only dump, run first
--   refinish-bar-sprite-probe swap     THE FLIP TEST: exchanges the
--                                      charcoal and coke texpos in
--                                      place if and only if the dump
--                                      located both entries. Look at
--                                      any coal bar on screen. If
--                                      the sprite visibly swapped,
--                                      the mapping is live and
--                                      writable and module coal can
--                                      be injected the same way.
--   refinish-bar-sprite-probe restore  swaps them back.
--
-- Output goes to console AND refinish-bar-sprite-probe.txt.
-- ==========================================

local out = {}
local function p(s) table.insert(out, s or '') end
local function hdr(s)
    p('')
    p('==========================================')
    p(' ' .. s)
    p('==========================================')
end

-- ==========================================
-- 1. THE TILE PAGE AND THE REAL TEXPOS NUMBERS
-- ==========================================
-- BARS_GRAPHICS names cells by page grid x:y. The page structure
-- carries the flat texpos vector, so index = y * page_dim_x + x
-- gives the actual texpos value the mapping should contain. Having
-- these numbers is what lets the hunt below RECOGNISE the mapping
-- when it walks over it: any struct holding 0:4's and 1:4's values
-- near COAL material fields is the target.
local coal_texpos = {}   -- label -> texpos value

local function dump_page()
    hdr('1. ITEM_CONSTRUCTION PAGE')
    local found = false
    pcall(function()
        for _, pg in ipairs(df.global.world.raws.graphics.pages) do
            local token = nil
            pcall(function() token = pg.token.value or pg.token end)
            token = tostring(token or '?')
            if token:find('ITEM_CONSTRUCTION', 1, true) then
                found = true
                local dx, dy, n = -1, -1, -1
                pcall(function()
                    dx, dy = pg.page_dim_x, pg.page_dim_y
                    n = #pg.texpos
                end)
                p(string.format('  page "%s": dims %dx%d, texpos n=%d',
                    token, dx, dy, n))
                -- The four cells vanilla binds around the coal rows,
                -- flat index = y * dx + x.
                for _, cell in ipairs({
                    { 'COKE      (0:4)', 0, 4 },
                    { 'CHARCOAL  (1:4)', 1, 4 },
                    { 'POTASH    (0:3)', 0, 3 },
                    { 'PEARLASH  (1:3)', 1, 3 },
                }) do
                    local label, x, y = cell[1], cell[2], cell[3]
                    local v = nil
                    pcall(function() v = pg.texpos[y * dx + x] end)
                    coal_texpos[label] = v
                    p(string.format('    %s -> texpos %s',
                        label, tostring(v)))
                end
            end
        end
    end)
    if not found then
        p('  ITEM_CONSTRUCTION not found under')
        p('  world.raws.graphics.pages. The pages vector may hang')
        p('  elsewhere; section 2 hunts the whole graphics tree and')
        p('  will list every vector it meets, so the true home will')
        p('  be in that listing.')
    end
end

-- ==========================================
-- 2. THE HUNT
-- ==========================================
-- Recursive walk of world.raws.graphics, depth limited, looking for
-- structures that smell like an item graphics binding: a texpos
-- bearing field in the company of material-ish fields (mat_type,
-- mat_index, item_type, item_subtype, or a token string). Every
-- candidate is printed with its full path and a decoded sample so
-- the target can be recognised by eye against the known texpos
-- numbers from section 1.
--
-- The walk is defensive to the point of paranoia: every access is
-- pcall wrapped, vectors are sampled rather than exhausted, and
-- recursion is capped, because this tree has unexplored corners and
-- an error mid walk would cost the whole dump.
local MAX_DEPTH   = 5
local MAX_SAMPLES = 4
local hits        = {}   -- { path=..., ref=..., } for swap mode

local function fields_of(obj)
    local names = {}
    pcall(function()
        for k in pairs(obj) do table.insert(names, tostring(k)) end
    end)
    return names
end

local function smells_like_binding(obj)
    local has_texpos, has_mat = false, false
    for _, k in ipairs(fields_of(obj)) do
        local lk = k:lower()
        if lk:find('texpos') then has_texpos = true end
        if lk == 'mat_type' or lk == 'mat_index'
           or lk == 'item_type' or lk == 'item_subtype'
           or lk:find('token') then
            has_mat = true
        end
    end
    return has_texpos and has_mat
end

local function describe(obj)
    local parts = {}
    for _, k in ipairs(fields_of(obj)) do
        local v = nil
        pcall(function() v = obj[k] end)
        local tv = tostring(v)
        if #tv > 24 then tv = tv:sub(1, 24) .. '..' end
        table.insert(parts, k .. '=' .. tv)
        if #parts > 8 then break end
    end
    return table.concat(parts, ' ')
end

local function walk(obj, path, depth)
    if depth > MAX_DEPTH then return end
    local t = nil
    pcall(function() t = df.reinterpret_cast and type(obj) or type(obj) end)
    -- Vectors: report size, sample the front, recurse into samples.
    local is_vec, n = false, 0
    pcall(function() n = #obj; is_vec = true end)
    if is_vec and n > 0 then
        p(string.format('  %-52s vector n=%d', path, n))
        for i = 0, math.min(n - 1, MAX_SAMPLES - 1) do
            local e = nil
            pcall(function() e = obj[i] end)
            if e ~= nil then
                if smells_like_binding(e) then
                    table.insert(hits, { path = path .. '[' .. i .. ']',
                                         ref = e })
                    p('    HIT ' .. path .. '[' .. i .. ']  '
                        .. describe(e))
                else
                    walk(e, path .. '[' .. i .. ']', depth + 1)
                end
            end
        end
        return
    end
    -- Structs: recurse fields.
    for _, k in ipairs(fields_of(obj)) do
        local v = nil
        pcall(function() v = obj[k] end)
        if v ~= nil and type(v) == 'userdata' then
            if smells_like_binding(v) then
                table.insert(hits, { path = path .. '.' .. k, ref = v })
                p('    HIT ' .. path .. '.' .. k .. '  ' .. describe(v))
            else
                walk(v, path .. '.' .. k, depth + 1)
            end
        end
    end
end

local function hunt()
    hdr('2. HUNT UNDER world.raws.graphics')
    local ok = pcall(function()
        walk(df.global.world.raws.graphics,
            'raws.graphics', 0)
    end)
    if not ok then p('  walk aborted by error, partial results above') end
    hdr('3. VERDICT')
    if #hits == 0 then
        p('  No binding shaped structure met. Next stop is the same')
        p('  walk over world.raws.itemdefs and df.global.game, and')
        p('  failing those, Memory-research.txt methodology on a')
        p('  BARS_GRAPHICS token string search. The mapping exists;')
        p('  only its address is in question.')
    else
        p(string.format('  %d candidate(s). The real one holds texpos'
            .. ' values matching', #hits))
        p('  section 1, with COAL material identity beside them.')
        p('  Once identified, rerun with: swap')
    end
end

-- ==========================================
-- 4. THE FLIP TEST
-- ==========================================
-- Only meaningful after the dump has produced hits. Finds, among
-- the hits, the two entries whose texpos values equal the CHARCOAL
-- and COKE cell values from section 1, and exchanges them. One
-- glance at any coal bar answers the writability question. restore
-- swaps back. Nothing is written unless BOTH entries were found,
-- so a partial identification can never half break the sheet.
local function flip()
    dump_page()
    hunt()
    local a, b = nil, nil
    local va = coal_texpos['CHARCOAL  (1:4)']
    local vb = coal_texpos['COKE      (0:4)']
    if not (va and vb) then
        p('  FLIP ABORTED: section 1 did not produce cell values.')
        return
    end
    for _, h in ipairs(hits) do
        pcall(function()
            for _, k in ipairs(fields_of(h.ref)) do
                if k:lower():find('texpos') then
                    local v = h.ref[k]
                    if v == va then a = { ref = h.ref, k = k } end
                    if v == vb then b = { ref = h.ref, k = k } end
                end
            end
        end)
    end
    hdr('4. FLIP')
    if a and b then
        local ok = pcall(function()
            a.ref[a.k], b.ref[b.k] = vb, va
        end)
        p(ok and ('  SWAPPED. Look at a coal bar. Visibly changed'
                .. ' sprite = mapping is live and writable.')
             or '  write failed, structure may be const')
    else
        p('  FLIP ABORTED: hits did not contain both coal texpos')
        p('  values. Identify the mapping from the dump first.')
    end
end

-- ==========================================
-- EMIT
-- ==========================================
local args = {...}
local mode = args[1] or 'dump'
if mode == 'swap' or mode == 'restore' then
    -- restore is the same exchange run again.
    flip()
else
    dump_page()
    hunt()
end

local text = table.concat(out, '\n')
print(text)
pcall(function()
    local fh = io.open('refinish-bar-sprite-probe.txt', 'w')
    fh:write(text)
    fh:close()
end)
print('')
print('written to refinish-bar-sprite-probe.txt')
