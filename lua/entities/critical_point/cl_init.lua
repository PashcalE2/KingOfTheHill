include("shared.lua")

-- Client-side draw function for the entity
function ENT:Draw()
    self:DrawModel() -- Draws the model of the entity. This function is called every frame.
end


function ENT:Initialize()
    --[[
    timer.Create("repeat", 1, 0, function ()
        print("Progress = " .. self:GetCaptureProgress())
        print("OwnerTeam = " .. self:GetOwnerTeamId())
        print("CaptureTeam = " .. self:GetCaptureTeamId())
        print("Status = " .. self:GetStatus())
    end)
    ]]--
end