--[[
    Teams
]]--

--[[
    Будем считать что у нас есть тимы на которые можно разделить игроков в игре.
    
    Одной из этих команд не может принадлежать никто. 
    Эта команда нужна чтобы обозначить "ничейность" ключевой точки.
    Такой подход на мой взгляд хорош, потому что можно настроить эту команду так же как и остальные.
]]--

local NoTeam = "NoTeam"


--[[
    Пусть пока структура описывающая тиму будет очень простая:
        * [<TeamName>] = <Color>

    По-умолчанию сделаю 2 команды, но их количество можно менять динамически (в игре).
]]--
local DefaultTeamsTypes = {
    [NoTeam] = Color(255, 255, 255, 255),
    ["Red"] = Color(255, 63, 0, 255),
    ["Blue"] = Color(0, 127, 255, 255)
}


--[[
    Эта таблица описывает какие команды есть на данный момент.
    При запуске этого скрипта в первый раз (а так же наверно сделаю chat команду) будет эквивалентно тимам по-умолчанию
]]--
local GameTeamsTypes = {}

function AddTeam(name, color)
    GameTeamsTypes[name] = color
end

function GetTeams()
    return GameTeamsTypes
end

function TeamExists(name)
    return GameTeamsTypes[name] != nil
end

function SetDefaultTeams()
    GameTeamsTypes = table.Copy(DefaultTeamsTypes)
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
        * wish_team: string <=> желаемая команда (может быть nil или одна из доступных команд)
]]--
local PlayersInLobby = {}


--[[
    Далее публичные функции для формирования лобби: аля CRUD и прочее.
]]--
function PutPlayerInfoToLobby(arg_ply, arg_wish_team)
    PlayersInLobby[arg_ply:SteamID64()] = { ply = arg_ply, wish_team = arg_wish_team }
end

function GetLobby()
    return PlayersInLobby
end

function GetPlayerInfoFromLobby(arg_ply)
    return PlayersInLobby[arg_ply:SteamID64()]
end

function ClearLobby()
    PlayersInLobby = {}
end

function RemovePlayerInfoFromLobby(arg_ply)
    PlayersInLobby[arg_ply:SteamID64()] = nil
end

function LobbyHasPlayerInfo(arg_ply)
    return PlayersInLobby[arg_ply:SteamID64()] != nil
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
local PlayersInTeams = {}


--[[
    Так как изначальный вариант лобби предусматривает "wish_team", то первоначальное распределение будет именно по этому полю.
    Но ведь игроки могут самостоятельно распределиться так:

    {
        ["Red"] = { ... }, -- 9 игроков
        ["Blue"] = { ... } -- 1 игрок
    }

    что нечестно, ведь не во всех командах число игроков по-ровну.

    Поэтому, предлагаю следующие варианты распределения игроков ПЕРЕД РАУНДОМ:
        * автобаланс по числу игроков в командах <=> 
            1. расчет среднего для всех команд;
            2. для тех команд, где количество игроков > среднего => кикаем в лобби случайных игроков (при этом `wish_team = nil`), чтобы осталось ровно по среднему.
            3. для тех команд, где количество игроков < среднего => случайным образом распределяем игроков из лобби в эти команды, чтобы стало ровно по среднему.
            4. (ВАЖНО) те кто нарушает равное количество игроков в командах - не играют, например: есть 3 команды и 11 игроков => 2 из них играть не будут.
]]--

function MergePlayersFromLobby()
    -- Делаем массив от 1 до N (удобен для перемешки и обращения к элементам) из полученного лобби
    local LobbyArray = {}
    for k, ply_info in pairs(PlayersInLobby) do
        LobbyArray[#LobbyArray + 1] = ply_info
    end
    PlayersInLobby = {}

    -- Начальная инициализация массивов игроков по тимам
    PlayersInTeams = {}
    for team_name, team_color in pairs(GameTeamsTypes) do
        if team_name != NoTeam then
            PlayersInTeams[team_name] = {}
        end
    end

    print("====================================================")
    print("Итого ждут распределения:")
    PrintTable(LobbyArray)
    -- Считаем среднее число игроков в команде. (ВАЖНО) считается здесь, так как далее из LobbyArray будут удаляться элементы!
    local players_count_mean = math.floor(#LobbyArray / (table.Count(GameTeamsTypes) - 1)) -- NoOne не считаем

    --[[
        Распределение по тимам. 
        Те кто не выбирал тиму - остаются в лобби.
        Остальные определяются в выбранную команду.
    ]]--

    local RemoveList = {}
    for k, ply_info in ipairs(LobbyArray) do
        if (ply_info.wish_team != nil) then
            PlayersInTeams[ply_info.wish_team][#PlayersInTeams[ply_info.wish_team] + 1] = ply_info.ply
            RemoveList[#RemoveList + 1] = ply_info
        end
    end

    for k, v in ipairs(RemoveList) do
        table.RemoveByValue(LobbyArray, v)
    end

    print("====================================================")
    print("Измененное лобби:")
    PrintTable(LobbyArray)

    print("====================================================")
    print("Распределили желающих по командам:")
    PrintTable(PlayersInTeams)

    --[[
        Та команда, в которой: количество игроков > среднее => будет пересобрана:
            * мешаем массив этой команды;
            * убираем лишних (по количеству) в лобби.
    ]]--
    print("====================================================")
    print("Среднее количество игроков в команде = " .. players_count_mean)
    print("Удаление лишних игроков:")

    for team_name, team_array in pairs(PlayersInTeams) do
        local move_count = #team_array - players_count_mean
        print(string.format("Количество игроков которое необходимо удалить из команды %s = %d", team_name, move_count))
        if (move_count > 0) then
            table.Shuffle(team_array)
            for i = 1, move_count do
                LobbyArray[#LobbyArray + 1] = { ply = team_array[#team_array], wish_team = nil }
                print(team_array[#team_array])
                team_array[#team_array] = nil
            end
        end
    end

    print("Измененные команды:")
    PrintTable(PlayersInTeams)

    table.Shuffle(LobbyArray)
    print("====================================================")
    print("Перемешанное лобби:")
    PrintTable(LobbyArray)
    --[[
        Для всех команд, в которых число игроков меньше среднего, добавим необходимое количество.
        Так как "среднее" может быть дробным - пока что добавим до округленного вниз среднего (чтобы у всех было такое число игроков).
    ]]--
    print("====================================================")
    print("Добавление в команды")
    for team_name, team_array in pairs(PlayersInTeams) do
        local add_count = players_count_mean - #team_array
        if (add_count > 0) then
            for i = 1, add_count do
                team_array[#team_array + 1] = LobbyArray[#LobbyArray].ply
                LobbyArray[#LobbyArray] = nil
            end
        end
    end

    print("Итоговые команды:")
    PrintTable(PlayersInTeams)

    --[[
        Оставшиеся не играют.
       
        TODO: 
            * можно их случайно распределить, но это надо балансить
    ]]--
    print("====================================================")
    print("Оставшиеся не играют:")
    PrintTable(LobbyArray)

    return PlayersInTeams, LobbyArray
end
