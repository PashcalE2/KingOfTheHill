AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

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

    self:SetCaptureProgress(-1)
    self:SetOwnerTeam("Amogus")
    self:SetCaptureTeam("Amogus")
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

/*
function ENT:Think()
    print(self:GetCaptureProgress())
    self:SetCaptureProgress(math.sin(CurTime()))
end
*/




