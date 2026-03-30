local function SZ_AnimalsFix()
    if not AnimalDefinitions or not AnimalDefinitions.animals then return end
    for k, v in pairs(AnimalDefinitions.animals) do
        v.canThump = false
    end
    print("[SZ_AnimalsFix] canThump disabled for all animals")
end

Events.OnServerStarted.Add(SZ_AnimalsFix)
