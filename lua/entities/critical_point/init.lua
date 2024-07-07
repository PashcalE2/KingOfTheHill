AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")


function ENT:Disable()
    self:SetCaptureProgress(0)
    self:SetOwnerTeam("Placeholder")
    self:SetCaptureTeam("Placeholder")
end


function ENT:Enable(progress, ownerTeam, captureTeam)
    self:SetCaptureProgress(progress)
    self:SetOwnerTeam(ownerTeam)
    self:SetCaptureTeam(captureTeam)
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
    Состояния точки:
        1. ничья <=> начальное состояние
        2. захватывается <=> ничья И есть захватчики ОДНОЙ КОМАНДЫ
        3. захвачена <=> устанавливается новый владелец
        4. отхватывается <=> НЕ ничья И есть захватчики РАЗНЫХ КОМАНД
        5. под защитой (перезахват остановлен) <=> НЕ ничья И есть владельцы И захватчики РАЗНЫХ КОМАНД
        6. борьба (захват остановлен) <=> ничья И есть РАЗНЫЕ захватчики
            * та команда, которая осталась после борьбы, продолжает захват

    Интерактив точки будет работать так:
        * игрок подходит на определенное расстояние;
        * точка понимает что рядом есть игрок;
        * остальное по сосстояниям

    Структура массива `players`:
    {
        [1] = { ply = <entity>, teamName = <string> }
        ...
    }
]]--

function ENT:InteractWithPlayers(players)
    for k, plyInfo in ipairs(players) do
        if (plyInfo.ply:GetPos():Distance(self:GetPos()) < captureRadius) then
        end
    end
end

