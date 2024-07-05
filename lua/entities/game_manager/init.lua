AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

--[[
    Game logic
]]--

local DefaultTeamsTypes = {
    [NoTeam] = Color(255, 255, 255, 255),
    ["Red"] = Color(255, 63, 0, 255),
    ["Blue"] = Color(0, 127, 255, 255)
}

local GameTeamsTypes = {}

function AddTeam(name, color)
    GameTeamsTypes[name] = color
end

function SetDefaultTeams()
    GameTeamsTypes = table.Copy(DefaultTeamsTypes)
end

SetDefaultTeams()

--[[
    Players
]]--

local PlayersInLobby = {}

function RemovePlayerFromLobby(arg_ply)
    PlayersInLobby[arg_ply:SteamID64()] = nil
end

function LobbyHasPlayer(arg_ply)
    return PlayersInLobby[arg_ply:SteamID64()] != nil
end

local PlayersInTeams = {}

--[[
    Chat
]]--

local ChatCommandsPrefix = "/"
local ChatCommandsPrefixLen = string.len(ChatCommandsPrefix)
local ChatCommands = {
    join = function (sender, args)
        --[[
        if (LobbyHasPlayer(sender)) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) уже добавлены в игру.", sender:Name()))
            return
        end
        ]]--

        if (args[1] == nil) then
            sender:PrintMessage(HUD_PRINTTALK, "Вы будете распределены случайным образом.")
        else
            if (args[1] == NoTeam or GameTeamsTypes[args[1]] == nil) then
                sender:PrintMessage(HUD_PRINTTALK, "Такой команды нет: '%s'. Вы будете распределены случайным образом.", args[1])
            else
                sender:PrintMessage(HUD_PRINTTALK, string.format("Вы хотите в команду %s.", args[1]))
            end
        end

        PlayersInLobby[sender:SteamID64()] = { ply = sender, wish_team = args[1] }
        sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) добавили себя в игру.", sender:Name()))
    end,

    exit = function (sender, args)
        if (not LobbyHasPlayer(sender)) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) уже вышли из игры.", sender:Name()))
            return
        end

        RemovePlayerFromLobby(sender)
        sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) вышли из игры.", sender:Name()))
    end,

    add_team = function (sender, args)
        if (not sender:IsSuperAdmin()) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) не имеете доступа к этой функции.", sender:Name()))
            return
        end

        AddTeam(args[1], Color(args[2], args[3], args[4], args[5] or 255))
        PrintTable(GameTeamsTypes)
    end,

    start_game = function (sender, args)
        if (not sender:IsSuperAdmin()) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) не имеете доступа к этой функции.", sender:Name()))
            return
        end

        local function randteam()
            local rand = math.random()
            if (rand < 0.3) then
                return "Red"
            elseif (rand < 0.5) then
                return "Blue"
            end
            return nil
        end

        PlayersInLobby = {}
        for k, v in ipairs(player.GetAll()) do
            PlayersInLobby[v:SteamID64()] = { ply = v, wish_team = randteam() }
        end

        local FinalLobby = {}
        for steamid64, ply_info in pairs(PlayersInLobby) do
            FinalLobby[#FinalLobby + 1] = ply_info
        end
        PlayersInLobby = {}

        PlayersInTeams = {}
        for team_name, team_color in pairs(GameTeamsTypes) do
            if team_name != NoTeam then
                PlayersInTeams[team_name] = {}
            end
        end

        print("====================================================")
        print("Итого ждут распределения:")
        PrintTable(FinalLobby)
        local players_count_mean = math.floor(#FinalLobby / (table.Count(GameTeamsTypes) - 1)) -- NoOne не считаем

        --[[
            Распределение по тимам. 
            Те кто не выбирал тиму - остаются в лобби.
            Остальные определяются в выбранную команду.
        ]]--
        local RemoveList = {}
        for k, ply_info in ipairs(FinalLobby) do
            if (ply_info.wish_team != nil) then
                PlayersInTeams[ply_info.wish_team][#PlayersInTeams[ply_info.wish_team] + 1] = ply_info.ply
                RemoveList[#RemoveList + 1] = ply_info
            end
        end

        for k, v in ipairs(RemoveList) do
            table.RemoveByValue(FinalLobby, v)
        end

        print("====================================================")
        print("Измененное лобби:")
        PrintTable(FinalLobby)

        print("====================================================")
        print("Распределили желающих по командам:")
        PrintTable(PlayersInTeams)

        --[[
            Считаем среднее число в команде.
            Та команда, в которой: количество игроков - 1 > среднее => будет пересобрана:
                * мешаем массив
                * убираем лишних в лобби
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
                    FinalLobby[#FinalLobby + 1] = { ply = team_array[#team_array], wish_team = nil }
                    print(team_array[#team_array])
                    team_array[#team_array] = nil
                end
            end
        end

        print("Измененные команды:")
        PrintTable(PlayersInTeams)

        table.Shuffle(FinalLobby)
        print("====================================================")
        print("Перемешанное лобби:")
        PrintTable(FinalLobby)
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
                    team_array[#team_array + 1] = FinalLobby[#FinalLobby].ply
                    FinalLobby[#FinalLobby] = nil
                end
            end
        end

        print("Итоговые команды:")
        PrintTable(PlayersInTeams)

        --[[
            Оставшиеся не играют.
            Можно их случайно распределить, но это надо балансить
        ]]--
        print("====================================================")
        print("Оставшиеся не играют:")
        PrintTable(FinalLobby)
        for steamid64, ply_info in ipairs(FinalLobby) do
            ply_info.ply:PrintMessage(HUD_PRINTTALK, "Вас выгнали из игры, так как с Вами не получилось распределить по-ровну.")
        end

        for team_name, team_array in pairs(PlayersInTeams) do
            for k, ply in pairs(team_array) do
                ply:PrintMessage(HUD_PRINTTALK, string.format("Вы начинаете за команду '%s'!", team_name))
            end
        end
    end
}

--[[
    Entity
]]--

-- Server-side initialization function for the entity
function ENT:Initialize()
    self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" ) -- Sets the model for the entity.
    self:PhysicsInit( SOLID_VPHYSICS ) -- Initializes physics for the entity, making it solid and interactable.
    self:SetMoveType( MOVETYPE_VPHYSICS ) -- Sets how the entity moves, using physics.
    self:SetSolid( SOLID_VPHYSICS ) -- Makes the entity solid, allowing for collisions.
    local phys = self:GetPhysicsObject() -- Retrieves the physics object of the entity.
    if (phys:IsValid()) then -- Checks if the physics object is valid.
        phys:Wake() -- Activates the physics object, making the entity subject to physics (gravity, collisions, etc.).
    end

    hook.Remove("PlayerSay", "chat_commands_listener")
    hook.Add("PlayerSay", "chat_commands_listener", function (sender, text, teamChat)
        if (string.sub(text, 1, ChatCommandsPrefixLen) == ChatCommandsPrefix) then
            local args = string.Explode(" +", text, true)

            local chat_command_name = string.TrimLeft(args[1], ChatCommandsPrefix)
            local chat_command = ChatCommands[chat_command_name]

            table.remove(args, 1)

            if (chat_command == nil) then
                sender:PrintMessage(HUD_PRINTTALK, string.format("Нет такой чат-команды '%s'", text))
            else
                chat_command(sender, args)
                PrintTable(args)
            end
        end
    end)
end

function ENT:OnRemove(fullUpdate)
    hook.Remove("PlayerSay", "chat_commands_listener")
end
