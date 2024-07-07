-- Defines the entity's type, base, printable name, and author for shared access (both server and client)
ENT.Type = "anim" -- Sets the entity type to 'anim', indicating it's an animated entity.
ENT.Base = "base_gmodentity" -- Specifies that this entity is based on the 'base_gmodentity', inheriting its functionality.
ENT.PrintName = "Game manager" -- The name that will appear in the spawn menu.
ENT.Author = "Pashcal & " -- The author's name for this entity.
ENT.Category = "King of the hill" -- The category for this entity in the spawn menu.
ENT.Contact = "STEAM_0:1:12345678" -- The contact details for the author of this entity.
ENT.Purpose = "Contains each team id and win score." -- The purpose of this entity.
ENT.Spawnable = false -- Specifies whether this entity can be spawned by players in the spawn menu.
ENT.AdminOnly = true


defaultStartWinScore = 500


function ENT:SetupDataTables()
    --[[
    ]]--
    self:NetworkVar("Int", 0, "TeamId")


    --[[
    ]]--
    self:NetworkVar("Int", 1, "WinScore")
end
