--@ module = true
-- refinish-mod-id.lua
-- ==========================================
-- MOD ID DIAGNOSTIC
-- ==========================================
-- Prints the [ID:...] from every installed mod's info.txt, next to the
-- folder it lives in. That value is what getModSourcePath expects, and
-- what MODULE_ID in a module's .lua file has to match exactly.
--
-- Usage:
--   refinish-mod-id                  list every installed mod
--   refinish-mod-id argmyth.lua      list them, and mark the folders
--                                    containing that file
--
-- The second form is the one that answers "which mod folder am I
-- actually in, and what is its ID".
--
-- NOTE: this finds mods that are INSTALLED. getModSourcePath only
-- resolves mods that are also ACTIVE in the loaded world. If a mod
-- appears here but getModSourcePath still returns nil, the ID is right
-- and the mod is simply not in that save's mod list.
-- ==========================================

local args = {...}
local target_file = args[1]

-- Both places DF keeps mods. Steam Workshop subscriptions land in
-- mods/ under a numeric ID, locally installed ones in
-- data/installed_mods/ under a readable name.
local ROOTS = {
    dfhack.getDFPath() .. "/mods",
    dfhack.getDFPath() .. "/data/installed_mods",
}

-- Pull the ID out of an info.txt. Returns nil if the file is missing
-- or has no ID token.
local function read_mod_id(folder)
    local path = folder .. "/info.txt"
    if not dfhack.filesystem.exists(path) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text:match("%[ID:([^%]]+)%]")
end

-- Does this mod folder contain the named file, at any depth?
local function contains_file(folder, name)
    if not name then return false end
    local ok, entries = pcall(dfhack.filesystem.listdir_recursive, folder, 10, false)
    if not ok or not entries then return false end
    for _, e in ipairs(entries) do
        -- listdir_recursive returns a table of {path=, isdir=} in some
        -- builds and plain strings in others, so handle both.
        local p = type(e) == "table" and e.path or e
        if type(p) == "string" and p:lower():find(name:lower(), 1, true) then
            return true
        end
    end
    return false
end

print("")
print("INSTALLED MODS")
print(string.rep("=", 78))

local found_any = false

for _, root in ipairs(ROOTS) do
    if dfhack.filesystem.isdir(root) then
        print("")
        print(root)
        print(string.rep("-", 78))

        for _, entry in ipairs(dfhack.filesystem.listdir(root)) do
            if entry ~= "." and entry ~= ".." then
                local folder = root .. "/" .. entry
                if dfhack.filesystem.isdir(folder) then
                    local id = read_mod_id(folder)
                    if id then
                        found_any = true
                        local mark = contains_file(folder, target_file) and "  <== CONTAINS " .. target_file or ""
                        print(string.format("  %-38s ID: %s%s", entry, id, mark))
                    end
                end
            end
        end
    end
end

if not found_any then
    print("")
    print("  No info.txt found under either root. Check that DF is installed where")
    print("  dfhack.getDFPath() reports: " .. dfhack.getDFPath())
end

print("")
print("Set MODULE_ID in the module's .lua to the ID shown for the folder")
print("that contains its files. It must match character for character.")
print("")
