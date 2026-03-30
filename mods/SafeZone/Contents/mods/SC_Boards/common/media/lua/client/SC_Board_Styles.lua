-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

if isServer() then return; end

SC_BoardStyles = SC_BoardStyles or {};
if not SandboxVars.SCBoard.EnableDefaultStyles then return; end

table.insert(SC_BoardStyles, { name = "Default", isAnimated = true, numTexture = 10, numDynamicElements = 15 });
table.insert(SC_BoardStyles, { name = "Transparent", isAnimated = false });
table.insert(SC_BoardStyles, { name = "Wood1_Anim", isAnimated = true, numTexture = 10, numDynamicElements = 15 });
table.insert(SC_BoardStyles, { name = "Wood1", isAnimated = false });
table.insert(SC_BoardStyles, { name = "Wood2", isAnimated = false });
table.insert(SC_BoardStyles, { name = "Metallic1", isAnimated = false });
table.insert(SC_BoardStyles, { name = "Metallic2", isAnimated = false });
table.insert(SC_BoardStyles, { name = "Office1", isAnimated = false });
table.insert(SC_BoardStyles, { name = "OldWall", isAnimated = false });

-- EN

-- You can add your own textures for the boards. Uploading your own modifications to Steam.
-- To do this, declare a variable in any file exactly as in this file.
-- EXAMPLE:
-- SC_BoardStyles = SC_BoardStyles or {};
-- table.insert(SC_BoardStyles, { name = "MyCustomName", isAnimated = true, numTexture = 10, numDynamicElements = 15 }); -- CONTINUED AND IN ENGLISH LETTERS ONLY, THE NAME MUST BE UNIQUE.

-- OPTIONS:
-- name - Required parameter, texture name.
-- isAnimated - Required parameter, is responsible for enabling or disabling dynamic textures in the background, as in "Default".
-- numTexture - Required if isAnimated = true, the number of different textures to create a dynamic texture.
-- numDynamicElements - Required if isAnimated = true, determines the number of generated textures. It is recommended to set values ​​up to 15.

-- IMPORTANT. After creating the script in the same modification, place the board texture along the path:
-- /media/ui/boards/{THE NAME YOU SPECIFIED}/SC_Board_Background.png
-- EXAMPLE: /media/ui/boards/MyCustomName/SC_Board_Background.png
-- Texture resolution required: 890x620.
-- I recommend leaving the first and last 30 pixels transparent; they contain the board control panel.
-- For a dynamic texture, create a folder: /media/ui/boards/{NAME AS YOU SPECIFIED}/ads
-- Place textures in it with the following names SC_Board_Dynamic_{ID}.png
-- The numTexture parameter must be equal to the number of textures.
-- If you created SC_Board_Dynamic_1.png SC_Board_Dynamic_2.png SC_Board_Dynamic_3.png then numTexture should be 3

-- RU

-- Вы можете добавить свои текстуры для досок. Заливая собственные модификации в Steam.
-- Для этого в любом файле объявите точно так же как в этом файле переменную.
-- ПРИМЕР: 
-- SC_BoardStyles = SC_BoardStyles or {};
-- table.insert(SC_BoardStyles, { name = "MyCustomName", isAnimated = true, numTexture = 10, numDynamicElements = 15 }); -- СЛИТНО И ТОЛЬКО АНГЛИЙСКИМИ БУКВАМИ, ИМЯ ДОЛЖНО БЫТЬ УНИКАЛЬНЫМ.

-- ПАРАМЕТРЫ:
-- name - Обязательный параметр, название текстуры.
-- isAnimated - Обязательный параметр, отвечает за включение или отключение динамичных текстур на заднем плане, как в "Default".
-- numTexture - Обязательный если isAnimated = true, количество разных текстур для создания динамичной текстуры.
-- numDynamicElements - Обязательный если isAnimated = true, отпределяет количество гененрируемых текстур. Рекомендуется устанавливать значения до 15.

-- ВАЖНО. После создания скрипта в той же модифкации поместите текстуру доски по пути:
-- /media/ui/boards/{ИМЯ КОТОРОЕ ВЫ УКАЗАЛИ}/SC_Board_Background.png
-- ПРИМЕР: /media/ui/boards/MyCustomName/SC_Board_Background.png
-- Разрешение текстуры обязательно: 890х620.
-- Первые и последнии 30 пикселей рекомендую оставить прозрачными, в них панель управления доской.
-- Для динамичной текстуры создайте папку: /media/ui/boards/{ИМЯ КОТОРОЕ ВЫ УКАЗАЛИ}/ads
-- В ней расположите текстурки со следующми именами SC_Board_Dynamic_{ID}.png
-- Параметр numTexture должен быть равен количеству текстур.
-- Если вы создали SC_Board_Dynamic_1.png SC_Board_Dynamic_2.png SC_Board_Dynamic_3.png, то numTexture должен быть равен 3
