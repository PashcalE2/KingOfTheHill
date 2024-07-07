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
]]--
CRITICAL_POINT_STATUS_ENUM = {
    NO_OWNER = 1,
    CAPTURING = 2,
    STRUGGLING = 3,
    RECOVERING = 4,
    PROTECTED = 5,
    DECAPTURING = 6,
    CAPTURED = 7
}

function ENT:SetupDataTables()
    --[[
        value == 0 - точка НИЧЬЯ
        0 < value < 1 - спорное состояние между ВЛАДЕЛЬЦЕМ [OwnerTeam] (может быть `noTeam` см. "game_manager/utils/teams.lua") и ЗАХВАТЫВАЮЩИМ [CaptureTeam] (`noTeam` если CaptureProgress == 0 или 1)
        value == 1 - точка захвачена командой
    ]]--
    self:NetworkVar("Float", 0, "CaptureProgress")

    --[[
        Та команда, которая последняя полностью захватила точку (может быть `noTeam`)
    ]]--
    self:NetworkVar("Int", 0, "OwnerTeamId")

    --[[
        Та команда, которая оспаривает точку (`noTeam` если CaptureProgress == 0 или 1)
    ]]--
    self:NetworkVar("Int", 1, "CaptureTeamId")


    self:NetworkVar("Int", 2, "Status")
end
