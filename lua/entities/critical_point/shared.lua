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

captureRadius = 200

function ENT:SetupDataTables()
    --[[
        value == 0 - точка НИЧЬЯ
        0 < value < 1 - спорное состояние между ВЛАДЕЛЬЦЕМ [OwnerTeam] (может быть `noTeam` см. "game_manager/utils/teams.lua") и ЗАХВАТЫВАЮЩИМ [CaptureTeam] (`noTeam` если CaptureProgress == 0 или 1)
        value == 1 - точка захвачена командой
    ]]--
    self:NetworkVar("Float", 0, "CaptureProgress")
    self:NetworkVarNotify("CaptureProgress", function (ent, name, old, new)
        if (new < 0) then
            new = 0
        elseif (new > 1) then
            new = 1
        end

        print(ent, name, old, new)
    end)

    --[[
        Та команда, которая последняя полностью захватила точку (может быть `noTeam`)
    ]]--
    self:NetworkVar("String", 0, "OwnerTeam")
    self:NetworkVarNotify("OwnerTeam", function (ent, name, old, new)
        print(ent, name, old, new)
    end)

    --[[
        Та команда, которая оспаривает точку (`noTeam` если CaptureProgress == 0 или 1)
    ]]--
    self:NetworkVar("String", 1, "CaptureTeam")
    self:NetworkVarNotify("CaptureTeam", function (ent, name, old, new)
        print(ent, name, old, new)
    end)
end
