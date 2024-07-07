local playersInLobby
local playersInTeams
local noTeam
local defaultTeamsTypes
local gameTeamsTypes

--[[
    Teams
]]--

--[[
    Будем считать что у нас есть тимы на которые можно разделить игроков в игре.
    
    Одной из этих команд не может принадлежать никто. 
    Эта команда нужна чтобы обозначить "ничейность" ключевой точки.
    Такой подход на мой взгляд хорош, потому что можно настроить эту команду так же как и остальные.
]]--

noTeam = "noTeam"


--[[
    Пусть пока структура описывающая тиму будет очень простая:
        * [<TeamName>] = <Color>

    По-умолчанию сделаю 2 команды, но их количество можно менять динамически (в игре).
]]--
defaultTeamsTypes = {
    [noTeam] = Color(255, 255, 255, 255),
    ["Red"] = Color(255, 63, 0, 255),
    ["Blue"] = Color(0, 127, 255, 255)
}


--[[
    Эта таблица описывает какие команды есть на данный момент.
    При запуске этого скрипта в первый раз (а так же наверно сделаю chat команду) будет эквивалентно тимам по-умолчанию
]]--
gameTeamsTypes = {}

function AddTeam(name, color)
    gameTeamsTypes[name] = color
end

function GetTeams()
    return gameTeamsTypes
end

function DeleteTeam(name)
    for k, ply_info in pairs(playersInLobby) do
        if (ply_info.wishTeam == name) then
            playersInLobby[k].wishTeam = nil
        end
    end

    gameTeamsTypes[name] = nil
end

function TeamExists(name)
    return gameTeamsTypes[name] != nil
end

function SetDefaultTeams()
    gameTeamsTypes = table.Copy(defaultTeamsTypes)
end

SetDefaultTeams()

--[[
    Players
]]--

--[[
    Игроки в лобби однозначным образом "сопоставляются" своему уникальному SteamID.
    Это нужно чтобы не требовалось искать по массиву от 1 до N: где же в этом массиве находится элемент с уже присоединившимся пользователем?
    
    Возможно это дублирование информации (всётаки ключ это SteamID который уже идентифицирует игрока), но пусть таблица лобби содержит элементы:
        * ply: Player <=> ентити игрока,
        * wishTeam: string <=> желаемая команда (может быть nil или одна из доступных команд)
]]--

playersInLobby = {}

--[[
    Далее публичные функции для формирования лобби: аля CRUD и прочее.
]]--
function PutPlayerInfoToLobby(argPly, argWishTeam)
    playersInLobby[argPly:SteamID64()] = { ply = argPly, wishTeam = argWishTeam }
end

function GetLobby()
    return playersInLobby
end

function GetPlayerInfoFromLobby(argPly)
    return playersInLobby[argPly:SteamID64()]
end

function ClearLobby()
    playersInLobby = {}
end

function RemovePlayerInfoFromLobby(argPly)
    playersInLobby[argPly:SteamID64()] = nil
end

function LobbyHasPlayerInfo(argPly)
    return playersInLobby[argPly:SteamID64()] != nil
end


--[[
    Перед началом раунда будет происходить распределение игроков по командам.
    Эта таблица будет выглядеть так:

    {
        [<Team1Name>] = <Team1Array>,
        [<Team2Name>] = <Team2Array>,
        ...
    }

    при этом:
        * <TeamName>: string <=> имя команды
        * <TeamArray>: table <=> массив ентити игроков (Player) от 1 до N (N - число игроков в команде)
]]--
playersInTeams = {}


--[[
    Так как изначальный вариант лобби предусматривает "wishTeam", то первоначальное распределение будет именно по этому полю.
    Но ведь игроки могут самостоятельно распределиться так:

    {
        ["Red"] = { ... }, -- 9 игроков
        ["Blue"] = { ... } -- 1 игрок
    }

    что нечестно, ведь не во всех командах число игроков по-ровну.

    Поэтому, предлагаю следующие варианты распределения игроков ПЕРЕД РАУНДОМ:
        * автобаланс по числу игроков в командах <=> 
            1. расчет среднего для всех команд;
            2. для тех команд, где количество игроков > среднего => кикаем в лобби случайных игроков (при этом `wishTeam = nil`), чтобы осталось ровно по среднему.
            3. для тех команд, где количество игроков < среднего => случайным образом распределяем игроков из лобби в эти команды, чтобы стало ровно по среднему.
            4. (ВАЖНО) те кто нарушает равное количество игроков в командах - не играют, например: есть 3 команды и 11 игроков => 2 из них играть не будут.
]]--

function MergePlayersFromLobby()
    -- Делаем массив от 1 до N (удобен для перемешки и обращения к элементам) из полученного лобби
    local lobbyArray = {}
    for k, ply_info in pairs(playersInLobby) do
        lobbyArray[#lobbyArray + 1] = ply_info
    end
    playersInLobby = {}

    -- Начальная инициализация массивов игроков по тимам
    playersInTeams = {}
    for team_name, team_color in pairs(gameTeamsTypes) do
        if team_name != noTeam then
            playersInTeams[team_name] = {}
        end
    end

    print("====================================================")
    print("Итого ждут распределения:")
    PrintTable(lobbyArray)
    -- Считаем среднее число игроков в команде. (ВАЖНО) считается здесь, так как далее из lobbyArray будут удаляться элементы!
    local players_count_mean = math.floor(#lobbyArray / (table.Count(gameTeamsTypes) - 1)) -- NoOne не считаем

    --[[
        Распределение по тимам. 
        Те кто не выбирал тиму - остаются в лобби.
        Остальные определяются в выбранную команду.
    ]]--

    local removeList = {}
    for k, ply_info in ipairs(lobbyArray) do
        if (ply_info.wishTeam != nil) then
            playersInTeams[ply_info.wishTeam][#playersInTeams[ply_info.wishTeam] + 1] = ply_info.ply
            removeList[#removeList + 1] = ply_info
        end
    end

    for k, v in ipairs(removeList) do
        table.RemoveByValue(lobbyArray, v)
    end

    print("====================================================")
    print("Измененное лобби:")
    PrintTable(lobbyArray)

    print("====================================================")
    print("Распределили желающих по командам:")
    PrintTable(playersInTeams)

    --[[
        Та команда, в которой: количество игроков > среднее => будет пересобрана:
            * мешаем массив этой команды;
            * убираем лишних (по количеству) в лобби.
    ]]--
    print("====================================================")
    print("Среднее количество игроков в команде = " .. players_count_mean)
    print("Удаление лишних игроков:")

    for team_name, team_array in pairs(playersInTeams) do
        local move_count = #team_array - players_count_mean
        print(string.format("Количество игроков которое необходимо удалить из команды %s = %d", team_name, move_count))
        if (move_count > 0) then
            table.Shuffle(team_array)
            for i = 1, move_count do
                lobbyArray[#lobbyArray + 1] = { ply = team_array[#team_array], wishTeam = nil }
                print(team_array[#team_array])
                team_array[#team_array] = nil
            end
        end
    end

    print("Измененные команды:")
    PrintTable(playersInTeams)

    table.Shuffle(lobbyArray)
    print("====================================================")
    print("Перемешанное лобби:")
    PrintTable(lobbyArray)
    --[[
        Для всех команд, в которых число игроков меньше среднего, добавим необходимое количество.
        Так как "среднее" может быть дробным - пока что добавим до округленного вниз среднего (чтобы у всех было такое число игроков).
    ]]--
    print("====================================================")
    print("Добавление в команды")
    for team_name, team_array in pairs(playersInTeams) do
        local add_count = players_count_mean - #team_array
        if (add_count > 0) then
            for i = 1, add_count do
                team_array[#team_array + 1] = lobbyArray[#lobbyArray].ply
                lobbyArray[#lobbyArray] = nil
            end
        end
    end

    print("Итоговые команды:")
    PrintTable(playersInTeams)

    --[[
        Оставшиеся не играют.
       
        TODO: 
            * можно их случайно распределить, но это надо балансить
    ]]--
    print("====================================================")
    print("Оставшиеся не играют:")
    PrintTable(lobbyArray)

    return playersInTeams, lobbyArray
end


--[[
    ПРИМЕР ВЫПОЛНЕНИЯ

====================================================
Итого ждут распределения:
[1]:
		["ply"]	=	Player [7][Bot06]
		["wishTeam"]	=	Blue
[2]:
		["ply"]	=	Player [12][Bot11]
		["wishTeam"]	=	Red
[3]:
		["ply"]	=	Player [2][Bot01]
		["wishTeam"]	=	Red
[4]:
		["ply"]	=	Player [5][Bot04]
[5]:
		["ply"]	=	Player [13][Bot12]
[6]:
		["ply"]	=	Player [15][Bot14]
[7]:
		["ply"]	=	Player [8][Bot07]
[8]:
		["ply"]	=	Player [3][Bot02]
[9]:
		["ply"]	=	Player [14][Bot13]
[10]:
		["ply"]	=	Player [11][Bot10]
[11]:
		["ply"]	=	Player [6][Bot05]
[12]:
		["ply"]	=	Player [16][Bot15]
[13]:
		["ply"]	=	Player [9][Bot08]
[14]:
		["ply"]	=	Player [4][Bot03]
[15]:
		["ply"]	=	Player [10][Bot09]
[16]:
		["ply"]	=	Player [1][Pashcal]
		["wishTeam"]	=	Blue
====================================================
Измененное лобби:
[1]:
		["ply"]	=	Player [5][Bot04]
[2]:
		["ply"]	=	Player [13][Bot12]
[3]:
		["ply"]	=	Player [15][Bot14]
[4]:
		["ply"]	=	Player [8][Bot07]
[5]:
		["ply"]	=	Player [3][Bot02]
[6]:
		["ply"]	=	Player [14][Bot13]
[7]:
		["ply"]	=	Player [11][Bot10]
[8]:
		["ply"]	=	Player [6][Bot05]
[9]:
		["ply"]	=	Player [16][Bot15]
[10]:
		["ply"]	=	Player [9][Bot08]
[11]:
		["ply"]	=	Player [4][Bot03]
[12]:
		["ply"]	=	Player [10][Bot09]
====================================================
Распределили желающих по командам:
["Blue"]:
		[1]	=	Player [7][Bot06]
		[2]	=	Player [1][Pashcal]
["Red"]:
		[1]	=	Player [12][Bot11]
		[2]	=	Player [2][Bot01]
====================================================
Среднее количество игроков в команде = 8
Удаление лишних игроков:
Количество игроков которое необходимо удалить из команды Red = -6
Количество игроков которое необходимо удалить из команды Blue = -6
Измененные команды:
["Blue"]:
		[1]	=	Player [7][Bot06]
		[2]	=	Player [1][Pashcal]
["Red"]:
		[1]	=	Player [12][Bot11]
		[2]	=	Player [2][Bot01]
====================================================
Перемешанное лобби:
[1]:
		["ply"]	=	Player [6][Bot05]
[2]:
		["ply"]	=	Player [8][Bot07]
[3]:
		["ply"]	=	Player [14][Bot13]
[4]:
		["ply"]	=	Player [16][Bot15]
[5]:
		["ply"]	=	Player [3][Bot02]
[6]:
		["ply"]	=	Player [11][Bot10]
[7]:
		["ply"]	=	Player [4][Bot03]
[8]:
		["ply"]	=	Player [9][Bot08]
[9]:
		["ply"]	=	Player [10][Bot09]
[10]:
		["ply"]	=	Player [15][Bot14]
[11]:
		["ply"]	=	Player [13][Bot12]
[12]:
		["ply"]	=	Player [5][Bot04]
====================================================
Добавление в команды
Итоговые команды:
["Blue"]:
		[1]	=	Player [7][Bot06]
		[2]	=	Player [1][Pashcal]
		[3]	=	Player [11][Bot10]
		[4]	=	Player [3][Bot02]
		[5]	=	Player [16][Bot15]
		[6]	=	Player [14][Bot13]
		[7]	=	Player [8][Bot07]
		[8]	=	Player [6][Bot05]
["Red"]:
		[1]	=	Player [12][Bot11]
		[2]	=	Player [2][Bot01]
		[3]	=	Player [5][Bot04]
		[4]	=	Player [13][Bot12]
		[5]	=	Player [15][Bot14]
		[6]	=	Player [10][Bot09]
		[7]	=	Player [9][Bot08]
		[8]	=	Player [4][Bot03]
====================================================
Оставшиеся не играют:
Pashcal: /start_game
["Blue"]:
		["a"]	=	255
		["b"]	=	255
		["g"]	=	127
		["r"]	=	0
["Green"]:
		["a"]	=	255
		["b"]	=	0
		["g"]	=	255
		["r"]	=	0
["Red"]:
		["a"]	=	255
		["b"]	=	0
		["g"]	=	63
		["r"]	=	255
["noTeam"]:
		["a"]	=	255
		["b"]	=	255
		["g"]	=	255
		["r"]	=	255

Pashcal: /add_team Green 0 255 0
====================================================
Итого ждут распределения:
[1]:
		["ply"]	=	Player [7][Bot06]
		["wishTeam"]	=	Red
[2]:
		["ply"]	=	Player [12][Bot11]
		["wishTeam"]	=	Blue
[3]:
		["ply"]	=	Player [2][Bot01]
		["wishTeam"]	=	Blue
[4]:
		["ply"]	=	Player [5][Bot04]
[5]:
		["ply"]	=	Player [13][Bot12]
		["wishTeam"]	=	Blue
[6]:
		["ply"]	=	Player [15][Bot14]
[7]:
		["ply"]	=	Player [8][Bot07]
		["wishTeam"]	=	Red
[8]:
		["ply"]	=	Player [3][Bot02]
[9]:
		["ply"]	=	Player [14][Bot13]
[10]:
		["ply"]	=	Player [11][Bot10]
[11]:
		["ply"]	=	Player [6][Bot05]
		["wishTeam"]	=	Blue
[12]:
		["ply"]	=	Player [16][Bot15]
		["wishTeam"]	=	Blue
[13]:
		["ply"]	=	Player [9][Bot08]
[14]:
		["ply"]	=	Player [4][Bot03]
		["wishTeam"]	=	Blue
[15]:
		["ply"]	=	Player [10][Bot09]
[16]:
		["ply"]	=	Player [1][Pashcal]
		["wishTeam"]	=	Blue
====================================================
Измененное лобби:
[1]:
		["ply"]	=	Player [5][Bot04]
[2]:
		["ply"]	=	Player [15][Bot14]
[3]:
		["ply"]	=	Player [3][Bot02]
[4]:
		["ply"]	=	Player [14][Bot13]
[5]:
		["ply"]	=	Player [11][Bot10]
[6]:
		["ply"]	=	Player [9][Bot08]
[7]:
		["ply"]	=	Player [10][Bot09]
====================================================
Распределили желающих по командам:
["Blue"]:
		[1]	=	Player [12][Bot11]
		[2]	=	Player [2][Bot01]
		[3]	=	Player [13][Bot12]
		[4]	=	Player [6][Bot05]
		[5]	=	Player [16][Bot15]
		[6]	=	Player [4][Bot03]
		[7]	=	Player [1][Pashcal]
["Green"]:
["Red"]:
		[1]	=	Player [7][Bot06]
		[2]	=	Player [8][Bot07]
====================================================
Среднее количество игроков в команде = 5
Удаление лишних игроков:
Количество игроков которое необходимо удалить из команды Red = -3
Количество игроков которое необходимо удалить из команды Green = -5
Количество игроков которое необходимо удалить из команды Blue = 2
Player [16][Bot15]
Player [1][Pashcal]
Измененные команды:
["Blue"]:
		[1]	=	Player [2][Bot01]
		[2]	=	Player [4][Bot03]
		[3]	=	Player [12][Bot11]
		[4]	=	Player [13][Bot12]
		[5]	=	Player [6][Bot05]
["Green"]:
["Red"]:
		[1]	=	Player [7][Bot06]
		[2]	=	Player [8][Bot07]
====================================================
Перемешанное лобби:
[1]:
		["ply"]	=	Player [5][Bot04]
[2]:
		["ply"]	=	Player [14][Bot13]
[3]:
		["ply"]	=	Player [1][Pashcal]
[4]:
		["ply"]	=	Player [10][Bot09]
[5]:
		["ply"]	=	Player [15][Bot14]
[6]:
		["ply"]	=	Player [9][Bot08]
[7]:
		["ply"]	=	Player [3][Bot02]
[8]:
		["ply"]	=	Player [16][Bot15]
[9]:
		["ply"]	=	Player [11][Bot10]
====================================================
Добавление в команды
Итоговые команды:
["Blue"]:
		[1]	=	Player [2][Bot01]
		[2]	=	Player [4][Bot03]
		[3]	=	Player [12][Bot11]
		[4]	=	Player [13][Bot12]
		[5]	=	Player [6][Bot05]
["Green"]:
		[1]	=	Player [9][Bot08]
		[2]	=	Player [15][Bot14]
		[3]	=	Player [10][Bot09]
		[4]	=	Player [1][Pashcal]
		[5]	=	Player [14][Bot13]
["Red"]:
		[1]	=	Player [7][Bot06]
		[2]	=	Player [8][Bot07]
		[3]	=	Player [11][Bot10]
		[4]	=	Player [16][Bot15]
		[5]	=	Player [3][Bot02]
====================================================
Оставшиеся не играют:
[1]:
		["ply"]	=	Player [5][Bot04]
Pashcal: /start_game
]]--