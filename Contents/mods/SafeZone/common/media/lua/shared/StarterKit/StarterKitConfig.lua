StarterKitConfig = StarterKitConfig or {}

-- Кулдаун между выдачами для одного SteamID (в реальных часах)
StarterKitConfig.cooldownHours = 24

-- Спрайты ящика снабжения (кастомные, 2 ракурса)
StarterKitConfig.crateSprites = {
    [0] = "safezone_crate_0",
    [1] = "safezone_crate_1",
}

-- Состав стартового набора
-- item = полный ID предмета
-- count = количество
-- container = "bag" — положить внутрь первого рюкзака из набора
StarterKitConfig.kitItems = {
    { item = "Base.Bag_SchoolBagFull", count = 1 },
    { item = "Base.Hammer",           count = 1, container = "bag" },
    { item = "Base.TinnedBeans",      count = 2, container = "bag" },
    { item = "Base.HuntingKnife",     count = 1, container = "bag" },
    { item = "Base.Trousers_CamoGreen",        count = 1 },
    { item = "Base.Tshirt_CamoGreen",          count = 1 },
    { item = "Base.Hat_BaseballCap_CamoGreen", count = 1 },
}
