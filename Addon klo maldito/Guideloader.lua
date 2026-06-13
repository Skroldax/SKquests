SKuests = {}

function SKuests:GetCurrentGuide()

    local faction = UnitFactionGroup("player")

    if faction == "Alliance" then
        return AllianceGuide
    else
        return HordeGuide
    end

end