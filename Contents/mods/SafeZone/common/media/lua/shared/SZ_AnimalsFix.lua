-- Animals do not attack buildings (thump walls)
local function SZ_AnimalsFix()
    if not AnimalDefinitions or not AnimalDefinitions.animals then return end
    for k, v in pairs(AnimalDefinitions.animals) do
        v.canThump = false
    end
end

SZ_AnimalsFix()
