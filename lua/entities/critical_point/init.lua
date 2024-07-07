AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")


--[[
    При спавне и после раундов, желательно сбрасывать точки в состояние невозможности использования.
    Возможно это понадобится фронтендерам.
]]--
function ENT:Disable()
    self:SetCaptureProgress(0)
    self:SetOwnerTeamId(noTeamId)
    self:SetCaptureTeamId(noTeamId)
    self:SetStatus(CRITICAL_POINT_STATUS_ENUM.NO_OWNER)
end


--[[
    В начале раунда желательно установить начальное состояние точки.
    Возможно это понадобится фронтендерам.

    Данный механизм может добавить гибкости. Например, можно сделать несколько точек уже захваченными в начале раунда.
]]--
function ENT:Enable()
    self:SetCaptureProgress(0)
    self:SetOwnerTeamId(noTeamId)
    self:SetCaptureTeamId(noTeamId)
    self:SetStatus(CRITICAL_POINT_STATUS_ENUM.NO_OWNER)
end


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

    self:Disable()
end


function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end


--[[
    Состояния точки (нужно фронтендерам):
        1. ничья <=> начальное состояние
        2. захватывается <=> ничья И есть захватчики ОДНОЙ КОМАНДЫ
        3. борьба <=> ничья И есть РАЗНЫЕ захватчики
            * захват приостановлен
            * та команда, которая осталась после борьбы, продолжает захват
        4. восстановливается <=> НЕ ничья И есть владельцы И нет захватчиков ВОЗМОЖНО РАЗНЫХ КОМАНД
            * прогресс захвата восстанавливается до 1
        5. под защитой <=> НЕ ничья И есть владельцы И есть захватчики ВОЗМОЖНО РАЗНЫХ КОМАНД
            * прогресс отхвата приостанавливается
        6. отхватывается <=> НЕ ничья И есть захватчики ВОЗМОЖНО РАЗНЫХ КОМАНД
        7. захвачена <=> НЕ ничья И на точке пусто

    Интерактив точки будет работать так:
        * игрок подходит на определенное расстояние;
        * точка понимает что рядом есть игрок;
        * остальное по состояниям

    Структура `KOTFPlayers`:
    {
        [1] = { ply = <entity>, teamName = <string>, ... }
        ...
    }

]]--


captureTime = 10 -- секунды

function ENT:InteractWithPlayers(tickInterval)
    local oldCaptureProgress = self:GetCaptureProgress()
    local oldOwnerTeamId = self:GetOwnerTeamId()
    local oldCaptureTeamId = self:GetCaptureTeamId()
    local oldStatus = self:GetStatus()

    local newCaptureProgress = oldCaptureProgress
    local newOwnerTeamId = oldOwnerTeamId
    local newCaptureTeamId = oldCaptureTeamId
    local newStatus = oldStatus

    local enemyIsHere = {}
    local captureProgressPerTick = tickInterval / captureTime

    local ownerIsHere = false

    for k, plyInfo in ipairs(KOTFPlayers) do
        --print(plyInfo.ply, plyInfo.ply:GetPos():Distance(self:GetPos()))
        if (plyInfo.ply:GetPos():Distance(self:GetPos()) < captureRadius) then
            if (plyInfo.teamId == oldOwnerTeamId) then
                ownerIsHere = true
            else
                enemyIsHere[plyInfo.teamId] = true
            end
        end
    end

    local captureTeams = {}
    for k, v in pairs(enemyIsHere) do
        captureTeams[#captureTeams + 1] = k
    end

    if (oldOwnerTeamId == noTeamId) then
        -- 1. ничья
        newStatus = CRITICAL_POINT_STATUS_ENUM.NO_OWNER

        if (#captureTeams == 1) then
            -- 2. захватывается
            newStatus = CRITICAL_POINT_STATUS_ENUM.CAPTURING
            newCaptureTeamId = captureTeams[1]
            newCaptureProgress = oldCaptureProgress + captureProgressPerTick
        elseif (#captureTeams > 1) then
            -- 3. борьба
            newStatus = CRITICAL_POINT_STATUS_ENUM.STRUGGLING
            newCaptureTeamId = noTeamId
        end
    else
        if (ownerIsHere) then
            if (#captureTeams == 0) then
                -- 4. восстановливается
                newStatus = CRITICAL_POINT_STATUS_ENUM.RECOVERING
                newCaptureTeamId = noTeamId
                newCaptureProgress = oldCaptureProgress + captureProgressPerTick
            else
                -- 5. под защитой
                newStatus = CRITICAL_POINT_STATUS_ENUM.PROTECTED
                -- ВАЖНО! На самом деле не знаю, стоит ли делать типа массив захватывающих команд (например через строковую NetworkVar).
                newCaptureTeamId = captureTeams[1]
            end
        elseif (#captureTeams > 0) then
            -- 6. отхватывается
            newStatus = CRITICAL_POINT_STATUS_ENUM.DECAPTURING
            newCaptureTeamId = captureTeams[1]
            newCaptureProgress = oldCaptureProgress - captureProgressPerTick
        else
            -- 7. захвачена
            newStatus = CRITICAL_POINT_STATUS_ENUM.CAPTURED
            newCaptureTeamId = noTeamId
        end
    end

    if (newCaptureProgress < 0) then
        newStatus = CRITICAL_POINT_STATUS_ENUM.NO_OWNER
        newCaptureProgress = 0
        newOwnerTeamId = noTeamId
        newCaptureTeamId = noTeamId
    elseif (newCaptureProgress > 1) then
        newCaptureProgress = 1
        if (oldOwnerTeamId == noTeamId) then
            newStatus = CRITICAL_POINT_STATUS_ENUM.CAPTURED
            newOwnerTeamId = newCaptureTeamId
            newCaptureTeamId = noTeamId
        end
    end

    if (oldCaptureProgress != newCaptureProgress) then
        self:SetCaptureProgress(newCaptureProgress)
    end

    if (oldOwnerTeamId != newOwnerTeamId) then
        self:SetOwnerTeamId(newOwnerTeamId)
    end

    if (oldCaptureTeamId != newCaptureTeamId) then
        self:SetCaptureTeamId(newCaptureTeamId)
    end

    if (oldStatus != newStatus) then
        self:SetStatus(newStatus)
    end
end

