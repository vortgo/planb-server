StarterKitConfig = StarterKitConfig or {}

-- Кулдаун между выдачами для одного SteamID (в реальных часах)
StarterKitConfig.cooldownHours = 24

-- Спрайт ящика снабжения (ванильный деревянный ящик)
StarterKitConfig.crateSprite = "carpentry_01_16"

-- Спрайт-оверлей (иконка рюкзака над ящиком)
StarterKitConfig.overlaySprite = "Item_SchoolBag"

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
