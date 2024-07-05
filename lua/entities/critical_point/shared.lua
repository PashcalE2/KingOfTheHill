-- Defines the entity's type, base, printable name, and author for shared access (both server and client)
ENT.Type = "anim" -- Sets the entity type to 'anim', indicating it's an animated entity.
ENT.Base = "base_gmodentity" -- Specifies that this entity is based on the 'base_gmodentity', inheriting its functionality.
ENT.PrintName = "Critical point" -- The name that will appear in the spawn menu.
ENT.Author = "Pashcal & " -- The author's name for this entity.
ENT.Category = "King of the hill" -- The category for this entity in the spawn menu.
ENT.Contact = "STEAM_0:1:12345678" -- The contact details for the author of this entity.
ENT.Purpose = "Spawn these ents after 'game_manager'." -- The purpose of this entity.
ENT.Spawnable = true -- Specifies whether this entity can be spawned by players in the spawn menu.
ENT.AdminOnly = true

function ENT:SetupDataTables()
    --[[
        value == 0 - точка НИЧЬЯ
        0 < value < 1 - спорное состояние между ВЛАДЕЛЬЦЕМ [OwnerTeam] (может быть NoTeam) и ЗАХВАТЫВАЮЩИМ [CaptureTeam] (NoTeam если CaptureProgress == 0 или 1)
        value == 1 - точка захвачена командой
    ]]--
    self:NetworkVar("Float", 0, "CaptureProgress")

    --[[
        Та команда, которая последняя полностью захватила точку (может быть nil)
    ]]--
    self:NetworkVar("String", 0, "OwnerTeam")

    --[[
        Та команда, которая оспаривает точку (nil если CaptureProgress == 0 или 1)
    ]]--
    self:NetworkVar("String", 1, "CaptureTeam")
end
