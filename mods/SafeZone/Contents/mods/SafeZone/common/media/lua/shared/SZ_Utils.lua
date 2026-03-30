SZ_Utils = {}

function SZ_Utils.IsAdminPlayer()
    if not isClient() then return true end
    if isAdmin() or isDebugEnabled() then return true end
    local player = getPlayer()
    if not player then return false end
    local role = player:getRole()
    if not role then return false end
    if role:hasAdminTool() or role:hasAdminPower() then
        return true
    end
    return false
end
