for _, mat in ipairs(df.global.world.raws.inorganics.all) do
    if mat.id == "REFINISHED_STEEL_RED" then
        mat.material.id = ""
        print("Cleared Red Steel material.id to match Vanilla Steel.")
        break
    end
end