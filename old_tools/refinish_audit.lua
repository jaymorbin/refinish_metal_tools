local raws = df.global.world.raws.inorganics.all
local steel, red

for _, mat in ipairs(raws) do
    if mat.id == "STEEL" then steel = mat end
    if mat.id == "REFINISHED_STEEL_RED" then red = mat end
end

if not steel or not red then
    print("Error: Make sure both STEEL and REFINISHED_STEEL_RED are loaded in memory.")
    return
end

local function check(prop_name, val_steel, val_red)
    local status = (val_steel == val_red) and "[MATCH]" or "[FAIL ]"
    print(string.format("%s %-30s : Steel = %-10s | Red = %-10s", status, prop_name, tostring(val_steel), tostring(val_red)))
end

print("======= EXHAUSTIVE MEMORY AUDIT: STEEL VS RED STEEL =======")

print("\n--- THERMODYNAMICS ---")
check("SPEC_HEAT", steel.material.heat.spec_heat, red.material.heat.spec_heat)
check("IGNITE_POINT", steel.material.heat.ignite_point, red.material.heat.ignite_point)
check("MELTING_POINT", steel.material.heat.melting_point, red.material.heat.melting_point)
check("BOILING_POINT", steel.material.heat.boiling_point, red.material.heat.boiling_point)
check("HEATDAM_POINT", steel.material.heat.heatdam_point, red.material.heat.heatdam_point)
check("COLDDAM_POINT", steel.material.heat.colddam_point, red.material.heat.colddam_point)
check("MAT_FIXED_TEMP", steel.material.heat.mat_fixed_temp, red.material.heat.mat_fixed_temp)

print("\n--- MASS & DENSITY ---")
check("SOLID_DENSITY", steel.material.solid_density, red.material.solid_density)
check("LIQUID_DENSITY", steel.material.liquid_density, red.material.liquid_density)
check("MOLAR_MASS", steel.material.molar_mass, red.material.molar_mass)

print("\n--- STRUCTURAL YIELD ---")
check("IMPACT_YIELD", steel.material.strength.yield.IMPACT, red.material.strength.yield.IMPACT)
check("COMPRESSIVE_YIELD", steel.material.strength.yield.COMPRESSIVE, red.material.strength.yield.COMPRESSIVE)
check("TENSILE_YIELD", steel.material.strength.yield.TENSILE, red.material.strength.yield.TENSILE)
check("TORSION_YIELD", steel.material.strength.yield.TORSION, red.material.strength.yield.TORSION)
check("SHEAR_YIELD", steel.material.strength.yield.SHEAR, red.material.strength.yield.SHEAR)
check("BENDING_YIELD", steel.material.strength.yield.BENDING, red.material.strength.yield.BENDING)

print("\n--- STRUCTURAL FRACTURE ---")
check("IMPACT_FRACTURE", steel.material.strength.fracture.IMPACT, red.material.strength.fracture.IMPACT)
check("COMPRESSIVE_FRACTURE", steel.material.strength.fracture.COMPRESSIVE, red.material.strength.fracture.COMPRESSIVE)
check("TENSILE_FRACTURE", steel.material.strength.fracture.TENSILE, red.material.strength.fracture.TENSILE)
check("TORSION_FRACTURE", steel.material.strength.fracture.TORSION, red.material.strength.fracture.TORSION)
check("SHEAR_FRACTURE", steel.material.strength.fracture.SHEAR, red.material.strength.fracture.SHEAR)
check("BENDING_FRACTURE", steel.material.strength.fracture.BENDING, red.material.strength.fracture.BENDING)

print("\n--- STRAIN AT YIELD ---")
check("IMPACT_STRAIN_AT_YIELD", steel.material.strength.strain_at_yield.IMPACT, red.material.strength.strain_at_yield.IMPACT)
check("COMPRESSIVE_STRAIN_AT_YIELD", steel.material.strength.strain_at_yield.COMPRESSIVE, red.material.strength.strain_at_yield.COMPRESSIVE)
check("TENSILE_STRAIN_AT_YIELD", steel.material.strength.strain_at_yield.TENSILE, red.material.strength.strain_at_yield.TENSILE)
check("TORSION_STRAIN_AT_YIELD", steel.material.strength.strain_at_yield.TORSION, red.material.strength.strain_at_yield.TORSION)
check("SHEAR_STRAIN_AT_YIELD", steel.material.strength.strain_at_yield.SHEAR, red.material.strength.strain_at_yield.SHEAR)
check("BENDING_STRAIN_AT_YIELD", steel.material.strength.strain_at_yield.BENDING, red.material.strength.strain_at_yield.BENDING)

print("\n--- EDGES & ABSORPTION ---")
check("MAX_EDGE", steel.material.strength.max_edge, red.material.strength.max_edge)
check("ABSORPTION", steel.material.strength.absorption, red.material.strength.absorption)

print("\n--- ECONOMY & CRAFTING FLAGS ---")
check("IS_METAL", steel.material.flags.IS_METAL, red.material.flags.IS_METAL)
check("ITEMS_HARD", steel.material.flags.ITEMS_HARD, red.material.flags.ITEMS_HARD)
check("ITEMS_METAL", steel.material.flags.ITEMS_METAL, red.material.flags.ITEMS_METAL)
check("ITEMS_BARRED", steel.material.flags.ITEMS_BARRED, red.material.flags.ITEMS_BARRED)
check("ITEMS_SCALED", steel.material.flags.ITEMS_SCALED, red.material.flags.ITEMS_SCALED)
check("ITEMS_WEAPON", steel.material.flags.ITEMS_WEAPON, red.material.flags.ITEMS_WEAPON)
check("ITEMS_WEAPON_RANGED", steel.material.flags.ITEMS_WEAPON_RANGED, red.material.flags.ITEMS_WEAPON_RANGED)
check("ITEMS_AMMO", steel.material.flags.ITEMS_AMMO, red.material.flags.ITEMS_AMMO)
check("ITEMS_DIGGER", steel.material.flags.ITEMS_DIGGER, red.material.flags.ITEMS_DIGGER)
check("ITEMS_ARMOR", steel.material.flags.ITEMS_ARMOR, red.material.flags.ITEMS_ARMOR)
check("ITEMS_ANVIL", steel.material.flags.ITEMS_ANVIL, red.material.flags.ITEMS_ANVIL)

print("===========================================================")