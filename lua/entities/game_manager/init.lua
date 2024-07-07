AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")


--[[
    function AddTeam(name, color)
    function GetTeams()
    function DeleteTeam(name)
    function TeamExists(name)
    function SetDefaultTeams()

    function PutPlayerInfoToLobby(arg_ply, arg_wish_team)
    function GetLobby()
    function GetPlayerInfoFromLobby(arg_ply)
    function ClearLobby()
    function RemovePlayerInfoFromLobby(arg_ply)
    function LobbyHasPlayerInfo(arg_ply)

    function MergePlayersFromLobby()
]]--
include("utils/teams.lua")

--[[
    Game logic
]]--

local criticalPoints = {}
local gamePlayers = {}

local function PushPlayerToGame(argPly, argTeamName)
    gamePlayers[#gamePlayers + 1] = { ply = argPly, teamName = argTeamName }
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
            criticalPoint:Enable(0, noTeam, noTeam)
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

        local gameTeamsTypes = GetTeams()

        for steamid64, plyInfo in ipairs(kickedPlayersArray) do
            plyInfo.ply:PrintMessage(HUD_PRINTTALK, "Вас выгнали из игры, так как с Вами не получилось распределить по-ровну.")
        end


        --[[
            Теперь когда все манипуляции по перемещение игроков из команды в команду завершены, 
            нам может потребоваться более простой массив игроков:
            {
                [1] = { ply = <entity>, team = <teamName>, ... }
                ...
            }
        ]]--

        gamePlayers = {}
        for teamName, teamArray in pairs(playersInTeams) do
            for k, ply in pairs(teamArray) do
                PushPlayerToGame(ply, teamName)
                ply:PrintMessage(HUD_PRINTTALK, string.format("Вы начинаете за команду '%s'!", teamName))

                --[[
                ]]
                local clr = gameTeamsTypes[teamName].color
                ply:SetPlayerColor(Vector(clr.r, clr.g, clr.b) / 255)
                --]]--
            end
        end

        --[[
            Теперь когда игроки распределены, можно начинать игру:
                1. расставить игроков по позициям;
                2. возможно для пафоса зафризить и поставить таймер, после которого игра начнется;
                3. ...
        ]]--

        hook.Remove("Tick", "koth_critical_points_management")
        hook.Add("Tick", "koth_critical_points_management", function ()
            for k, criticalPoint in ipairs(criticalPoints) do
                criticalPoint:InteractWithPlayers(gamePlayers)
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

function ENT:OnRemove(fullUpdate)
    hook.Remove("PlayerSay", "koth_chat_command_listener")
    for k, plyInfo in ipairs(gamePlayers) do
        plyInfo.ply:PrintMessage(HUD_PRINTCENTER, "Игра окончена.")
    end
    gamePlayers = nil

    hook.Remove("Tick", "koth_critical_points_management")
    for k, criticalPoint in ipairs(criticalPoints) do
        criticalPoint:Disable()
    end
    criticalPoints = nil
end

function ENT:UpdateTransmitState()
    --return TRANSMIT_NEVER
    return TRANSMIT_ALWAYS
end
