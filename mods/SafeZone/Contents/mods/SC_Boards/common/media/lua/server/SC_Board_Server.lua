-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

if not isServer() then return; end

SC_Board = SC_Board or require("SC_Board_Class"):new();

Events.OnInitGlobalModData.Add(function() SC_Board:OnInitGlobalModData(); end)
Events.OnClientCommand.Add(function(module, command, player, args) SC_Board:OnClientCommand(module, command, player, args); end)