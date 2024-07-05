include("shared.lua")

-- Client-side draw function for the entity
function ENT:Draw()
    self:DrawModel() -- Draws the model of the entity. This function is called every frame.
end

/*
function ENT:Think()
    print(self:GetCaptureProgress())
end
*/

function ENT:Initialize()
    print(self:GetCaptureProgress())
    print(self:GetOwnerTeam())
    print(self:GetCaptureTeam())
end