include("shared.lua")


function ENT:Draw()
    self:DrawModel()
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
