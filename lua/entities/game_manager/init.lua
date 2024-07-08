AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")


--[[
    Глобальные переменные:
        noTeam
        noTeamId
        KOTFTeamsByName

    Глобальные функции:
        AddTeam(name, color)
        UpdateTeamsIds()
        GetTeams()
        DeleteTeam(name)
        TeamExists(name)
        SetDefaultTeams()

        PutPlayerInfoToLobby(arg_ply, arg_wish_team)
        GetLobby()
        GetPlayerInfoFromLobby(arg_ply)
        ClearLobby()
        RemovePlayerInfoFromLobby(arg_ply)
        LobbyHasPlayerInfo(arg_ply)

        ClearTeams()
        MergePlayersFromLobby()
]]--
include("utils/teams.lua")

--[[
    Game logic
]]--

util.AddNetworkString("KOTFGameStarted")
util.AddNetworkString("KOTFGameFinished")

local lastTickRealTime
local lastSecondRealTime

local criticalPoints
KOTFPlayers = nil
netReceivers = nil
winScoreCountersEnts = nil

local function PushPlayerToGame(argPly, argTeamId, argTeamName)
    KOTFPlayers[#KOTFPlayers + 1] = {
        ply = argPly,
        teamId = argTeamId,
        teamName = argTeamName,
        oldPlyColor = argPly:GetPlayerColor()
    }
end


--[[
    Chat
]]--

local chatCommandsPrefix = "/"
local chatCommandsPrefixLen = string.len(chatCommandsPrefix)
local chatCommands = {
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
            if (args[1] == noTeam or not TeamExists(args[1])) then
                sender:PrintMessage(HUD_PRINTTALK, "Такой команды нет: '%s'. Вы будете распределены случайным образом.", args[1])
                args[1] = nil
            else
                sender:PrintMessage(HUD_PRINTTALK, string.format("Вы хотите в команду %s.", args[1]))
            end
        end

        PutPlayerInfoToLobby(sender, args[1])
        sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) добавили себя в игру.", sender:Name()))
    end,

    exit = function (sender, args)
        if (not LobbyHasPlayer(sender)) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) уже вышли из игры.", sender:Name()))
            return
        end

        RemovePlayerInfoFromLobby(sender)
        sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) вышли из игры.", sender:Name()))
    end,

    add_team = function (sender, args)
        if (not sender:IsSuperAdmin()) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) не имеете доступа к этой функции.", sender:Name()))
            return
        end

        AddTeam(args[1], Color(args[2], args[3], args[4], 255))
        sender:PrintMessage(HUD_PRINTTALK, string.format("Создана новая команда: %s", args[1]))
    end,

    delete_team = function (sender, args)
        if (not sender:IsSuperAdmin()) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) не имеете доступа к этой функции.", sender:Name()))
            return
        end

        DeleteTeam(args[1])
        sender:PrintMessage(HUD_PRINTTALK, string.format("Удалена команда '%s'", args[1]))
    end,

    default_teams = function (sender, args)
        if (not sender:IsSuperAdmin()) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) не имеете доступа к этой функции.", sender:Name()))
            return
        end

        SetDefaultTeams()
        sender:PrintMessage(HUD_PRINTTALK, string.format("Установлены стандартные команды"))
    end,

    start_game = function (sender, args)
        if (not sender:IsSuperAdmin()) then
            sender:PrintMessage(HUD_PRINTTALK, string.format("Вы (%s) не имеете доступа к этой функции.", sender:Name()))
            return
        end

        criticalPoints = ents.FindByClass("critical_point")
        if (#criticalPoints == 0) then
            sender:PrintMessage(HUD_PRINTTALK, "Прежде чем начинать игру, нужно поставить ключевые точки.")
            return
        end

        for k, criticalPoint in ipairs(criticalPoints) do
            criticalPoint:Enable()
        end

        --[[
            Для тестов:
                * я спавню N ботов 
                * происходит генерация случайных тим для игроков на сервере
        ]]--
        local function createRandomTestCase()
            local function randteam()
                local rand = math.random()
                if (rand < 0.3) then
                    return "Red"
                elseif (rand < 0.5) then
                    return "Blue"
                end
                return nil
            end

            ClearLobby()
            for k, v in ipairs(player.GetAll()) do
                PutPlayerInfoToLobby(v, randteam())
            end
        end

        createRandomTestCase()

        --]]--

        local playersInTeams = {}
        local kickedPlayersArray = {}
        playersInTeams, kickedPlayersArray = MergePlayersFromLobby()

        AddGameLogicToTeams()

        --[[
            Теперь когда все манипуляции по перемещение игроков из команды в команду завершены, 
            нам может потребоваться более простой массив игроков:
            {
                [1] = { ply = <entity>, team = <teamName>, ... }
                ...
            }
        ]]--

        KOTFPlayers = {}
        for teamName, teamArray in pairs(playersInTeams) do
            for k, ply in pairs(teamArray) do
                local teamStruct = KOTFTeamsByName[teamName]
                PushPlayerToGame(ply, teamStruct.id, teamName)
                ply:PrintMessage(HUD_PRINTTALK, string.format("Вы начинаете за команду '%s'!", teamName))

                --[[
                ]]
                ply:SetPlayerColor(Vector(teamStruct.color.r, teamStruct.color.g, teamStruct.color.b) / 255)
                --]]--
            end
        end

        if (#KOTFPlayers == 0) then
            sender:PrintMessage(HUD_PRINTTALK, "Не хватает игроков для запуска игры.")
            return
        end

        for steamid64, plyInfo in ipairs(kickedPlayersArray) do
            plyInfo.ply:PrintMessage(HUD_PRINTTALK, "Вас выгнали из игры, так как с Вами не получилось распределить по-ровну.")
        end

        --[[
            Теперь когда игроки распределены, можно начинать игру:
                * создать счетчики победы;
                * жизнь точкам;
            
            (Добавить?)
                * расставить игроков по позициям;
                * возможно для пафоса зафризить и поставить таймер, после которого игра начнется;
                * ...
        ]]--

        winScoreCountersEnts = {}
        for teamName, teamStruct in pairs(KOTFTeamsByName) do
            if (teamStruct.id != noTeamId) then
                local winCounter = ents.Create("win_score_counter")
                if (not winCounter:IsValid()) then
                    break
                end

                winCounter:SetPos(Vector(0, 0, 0))
                winCounter:SetTeamId(teamStruct.id)
                winCounter:Spawn()

                local phys = winCounter:GetPhysicsObject()
                if (not phys:IsValid()) then
                    break
                end

                winScoreCountersEnts[teamStruct.id] = winCounter
            end
        end

        if (table.Count(winScoreCountersEnts) != table.Count(playersInTeams)) then
            print("НЕ УДАЛОСЬ СОЗДАТЬ ЕНТИТИ `win_score_counter`, ИГРА НЕ НАЧНЕТСЯ")

            for teamId, ent in pairs(winScoreCountersEnts) do
                ent:Remove()
            end

            return
        end


        netReceivers = {}
        for k, plyInfo in ipairs(KOTFPlayers) do
            netReceivers[#netReceivers + 1] = plyInfo.ply
        end

        net.Start("KOTFGameStarted")
        net.Send(netReceivers)


        lastTickRealTime = RealTime()
        lastSecondRealTime = RealTime()
        hook.Remove("Tick", "koth_critical_points_management")
        hook.Add("Tick", "koth_critical_points_management", function ()
            local realTime = RealTime()
            local tickInterval = realTime - lastTickRealTime
            lastTickRealTime = realTime

            local teamsCriticalPoints = {}

            for k, criticalPoint in ipairs(criticalPoints) do
                -- Если по какой-то причине точка удалена, то пропустим её...
                if not criticalPoint:IsValid() then
                    continue
                end

                criticalPoint:InteractWithPlayers(tickInterval)

                -- Сколько на данный момент захвачено точек у команд?
                local onwerTeamId = criticalPoint:GetOwnerTeamId()
                if (onwerTeamId != noTeamId) then
                    teamsCriticalPoints[onwerTeamId] = (teamsCriticalPoints[onwerTeamId] or 0) + 1
                end
            end

            -- Каждую секунду вычтем количество очков до победы у каждой команды с точками
            if (realTime - lastSecondRealTime > 1) then
                lastSecondRealTime = realTime

                local winners = {}
                for teamId, cpCount in pairs(teamsCriticalPoints) do
                    local winScore = winScoreCountersEnts[teamId]:DecreaseWinScore(cpCount)

                    if (winScore == 0) then
                        winners[#winners + 1] = teamId
                    end
                end

                if (#winners > 0) then
                    -- Останавливаем игру получается
                    local winnersStr = winners[1]
                    for k, teamId in ipairs(winners) do
                        if (k > 1) then
                            winnersStr = winnersStr .. " " .. teamId
                        end
                    end

                    for k, plyInfo in ipairs(KOTFPlayers) do
                        plyInfo.ply:PrintMessage(HUD_PRINTCENTER, string.format("Игра окончена! Победили следующие команды: %s", winnersStr))
                    end

                    hook.Remove("Tick", "koth_critical_points_management")
                    ClearCriticalPoints()

                    if (netReceivers) then
                        net.Start("KOTFGameFinished")
                        net.Send(netReceivers)
                        netReceivers = nil
                    end
                end
            end
        end)
    end
}

--[[
    Entity
]]--

-- Server-side initialization function for the entity
function ENT:Initialize()
    -- Из примера на wiki.facepunch.com
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl") -- Sets the model for the entity.
    self:PhysicsInit(SOLID_VPHYSICS) -- Initializes physics for the entity, making it solid and interactable.
    self:SetMoveType(MOVETYPE_VPHYSICS) -- Sets how the entity moves, using physics.
    self:SetSolid(SOLID_VPHYSICS) -- Makes the entity solid, allowing for collisions.
    local phys = self:GetPhysicsObject() -- Retrieves the physics object of the entity.
    if (phys:IsValid()) then -- Checks if the physics object is valid.
        phys:Wake() -- Activates the physics object, making the entity subject to physics (gravity, collisions, etc.).
    end

    hook.Remove("PlayerSay", "koth_chat_command_listener")
    hook.Add("PlayerSay", "koth_chat_command_listener", function (sender, text, teamChat)
        if (string.sub(text, 1, chatCommandsPrefixLen) == chatCommandsPrefix) then
            local args = string.Explode(" +", text, true)

            local chatCommandName = string.TrimLeft(args[1], chatCommandsPrefix)
            local chatCommand = chatCommands[chatCommandName]

            table.remove(args, 1)

            if (chatCommand == nil) then
                sender:PrintMessage(HUD_PRINTTALK, string.format("Нет такой чат-команды '%s'", text))
            else
                chatCommand(sender, args)
            end
        end
    end)
end


--[[
    Пока что я решил записать логику выпуска из игры при удалении ентити игры. 

    Тут должно произойти сообщение об окончании игры и восставновления аддона до АДЕКВАТНОГО первоначального состояния.
    Так как я по приколу менял цвета игрокам - их можно вернуть здесь.
]]--

function ClearWinScoreCounters()
    if (winScoreCountersEnts) then
        for k, ent in pairs(winScoreCountersEnts) do
            if (ent:IsValid()) then
                ent:Remove()
            end
        end
        winScoreCountersEnts = nil
    end
end

function ClearKOTFPlayers()
    if (KOTFPlayers) then
        for k, plyInfo in ipairs(KOTFPlayers) do
            plyInfo.ply:PrintMessage(HUD_PRINTCENTER, "Игра окончена.")
            plyInfo.ply:SetPlayerColor(plyInfo.oldPlyColor)
        end
        KOTFPlayers = nil
    end
end

function ClearCriticalPoints()
    if (criticalPoints) then
        for k, criticalPoint in ipairs(criticalPoints) do
            if not criticalPoint:IsValid() then
                continue
            end

            criticalPoint:Disable()
        end
        criticalPoints = nil
    end
end

function ENT:OnRemove(fullUpdate)
    ClearWinScoreCounters()

    hook.Remove("PlayerSay", "koth_chat_command_listener")
    ClearKOTFPlayers()

    hook.Remove("Tick", "koth_critical_points_management")
    ClearCriticalPoints()

    if (netReceivers) then
        net.Start("KOTFGameFinished")
        net.Send(netReceivers)
        netReceivers = nil
    end
end

function ENT:UpdateTransmitState()
    --return TRANSMIT_NEVER
    return TRANSMIT_ALWAYS
end
