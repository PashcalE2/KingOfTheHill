include("shared.lua")

local gameFinished = true
local criticalPoints
local winScoreCountersEnts


local basePos = { x = 100, y = 100 }
local defaultFont = "DermaDefault"
local defaultTextColor = Color(255, 255, 255, 255)

hook.Remove("HUDPaint", "kotf_2d_render")
hook.Add("HUDPaint", "kotf_2d_render", function ()
    if (gameFinished) then
        return
    end

    for i = 1, #winScoreCountersEnts do
        local winScoreCounter = winScoreCountersEnts[i]

        draw.SimpleText(
            winScoreCounter:GetTeamId() .. ": " .. winScoreCounter:GetWinScore(),
            defaultFont,
            basePos.x,
            basePos.y + i * 30,
            defaultTextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end
end)

hook.Remove("HUDPaint", "test")
--[[]
local X = 0
hook.Add("HUDPaint", "test", function ()
    surface.SetDrawColor(255, 0, 0, 255)
    surface.DrawRect(100, 100, X, 10)
    X = math.abs(math.sin(CurTime()) * 100)
end)
--]]--

net.Receive("KOTFGameStarted", function()
    timer.Create("kotf_wait_before_find_ents", 0.5, 1, function ()
        gameFinished = false
        criticalPoints = ents.FindByClass("critical_point")
        winScoreCountersEnts = ents.FindByClass("win_score_counter")
    end)

    print("А игра то началась!")
end)

net.Receive("KOTFGameFinished", function()
    gameFinished = true
    criticalPoints = nil
    winScoreCountersEnts = nil
    print("А игра то закончилась!")
end)
