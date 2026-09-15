-- refinish-image-probe.lua
-- ==========================================
-- RUNTIME IMAGE PROBE
-- ==========================================
-- Answers one question: which exact path string does
-- dfhack.textures.loadTileset accept for an image inside a mod
-- folder, and what is the file on disk really called.
--
-- Nothing is written and nothing is changed. Run it, read it, and
-- the sprite config follows from what it says.
--
-- USAGE
--   refinish-image-probe making_fuel images/ash_sprite.png
--   refinish-image-probe making_fuel images/ash_sprite.png 32
--
-- The third argument is the tile size to slice at, default 32.
-- ==========================================

local scriptmanager = require('script-manager')

local args    = {...}
local mod_id  = args[1] or 'making_fuel'
local rel     = args[2] or 'images/ash_sprite.png'
local cell_px = tonumber(args[3]) or 32

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

-- ==========================================
-- THE TWO ROOTS
-- ==========================================
-- getDFPath is the game directory. getModSourcePath is documented as
-- RELATIVE to it, but on a Steam install with user data in AppData it
-- comes back ABSOLUTE, which is what produced the doubled path in the
-- last log. Both are printed raw so there is no guessing which.
-- ==========================================
local df_path, mod_path
pcall(function() df_path  = dfhack.getDFPath() end)
pcall(function() mod_path = scriptmanager.getModSourcePath(mod_id) end)

hr('ROOTS')
p('  getDFPath()          ' .. tostring(df_path))
p('  getModSourcePath()   ' .. tostring(mod_path))
if mod_path then
    local absolute = mod_path:match('^%a:[/\\]') or mod_path:match('^/')
    p('  mod path looks       ' .. (absolute and 'ABSOLUTE' or 'RELATIVE'))
end

-- ==========================================
-- WHAT IS ACTUALLY IN THE FOLDER
-- ==========================================
-- Windows hides known extensions, so a file shown as ash_sprite.png
-- in Explorer can be ash_sprite.png.png on disk. This prints what the
-- filesystem says, byte for byte.
-- ==========================================
if mod_path then
    local dir = mod_path .. rel:gsub('[^/\\]+$', '')
    hr('DIRECTORY LISTING: ' .. dir)
    local names = {}
    pcall(function() names = dfhack.filesystem.listdir(dir) end)
    if not names or #names == 0 then
        p('  nothing listed. Either the folder is empty or the path')
        p('  above is not where the game loaded this mod from.')
    else
        for _, n in ipairs(names) do
            p('  [' .. tostring(n) .. ']')
        end
        p('')
        p('  Square brackets are deliberate: they show trailing spaces')
        p('  and doubled extensions that the name alone hides.')
    end
end

-- ==========================================
-- CANDIDATE PATHS
-- ==========================================
local cands = {}
local function add(label, path)
    if path then table.insert(cands, { label = label, path = path }) end
end
if mod_path then add('mod path as returned', mod_path .. rel) end
if mod_path and df_path then
    local d = df_path
    if d:sub(-1) ~= '/' and d:sub(-1) ~= '\\' then d = d .. '/' end
    add('game dir + mod path', d .. mod_path .. rel)
end
if mod_path then add('backslashes', (mod_path .. rel):gsub('/', '\\')) end

hr('CANDIDATES')
for i, c in ipairs(cands) do
    local exists, isfile = nil, nil
    pcall(function() exists = dfhack.filesystem.exists(c.path) end)
    pcall(function() isfile = dfhack.filesystem.isfile(c.path) end)

    -- The load is the real test. exists() answers from the process
    -- working directory, which is not guaranteed to be the game
    -- directory, so it can disagree with the loader either way.
    local n, err = nil, nil
    local ok, res = pcall(function()
        return dfhack.textures.loadTileset(c.path, cell_px, cell_px)
    end)
    if ok and type(res) == 'table' then
        n = #res
    else
        err = tostring(res)
    end

    p('')
    p('  ' .. i .. '. ' .. c.label)
    p('     ' .. c.path)
    p(string.format('     exists=%s  isfile=%s  loadTileset=%s',
        tostring(exists), tostring(isfile),
        n and (n .. ' tile(s)') or ('FAILED ' .. tostring(err))))
    if n and n > 0 then
        local tp = nil
        pcall(function()
            tp = dfhack.textures.getTexposByHandle(res[1])
        end)
        p('     first tile texpos = ' .. tostring(tp)
          .. (tp and tp > 0 and '   <-- USE THIS PATH FORM' or
              '   (loaded but texpos is 0, which draws nothing)'))
    end
end

hr('READING THIS')
p('  A candidate with loadTileset showing tiles AND a texpos above')
p('  zero is the path form to put in the sprite config.')
p('')
p('  All candidates failing while the listing above shows the file')
p('  means the loader will not take this location at all, and the')
p('  image has to live somewhere it will: try copying it beside')
p('  DFHack art under hack/data/art/ and probing that path.')
p('')
p('  An empty listing means the game is loading the mod from a')
p('  different folder than the one being edited. The path in ROOTS')
p('  is the one the game is using.')
p('')