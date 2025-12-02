-- tape_presets.lua
-- Tape FX presets for strata

local TapePresets = {}

TapePresets.presets = {
    {
        name = "Clean",
        description = "Neutral (no FX)",
        params = {
            mix = 0.0,
            saturation = 0.0,
            wow = 0.0,
            flutter = 0.0,
            aging = 0.0,
            noise = 0.0,
            bias = 0.5,
            compression = 0.0,
            dropout = 0.0,
            width = 1.0
        }
    },
    {
        name = "Subtle Warmth",
        description = "Gentle tape character",
        params = {
            mix = 0.3,
            saturation = 0.2,
            wow = 0.05,
            flutter = 0.02,
            aging = 0.1,
            noise = 0.05,
            bias = 0.6,
            compression = 0.2,
            dropout = 0.0,
            width = 1.0
        }
    },
    {
        name = "Vintage Reel",
        description = "Classic studio tape",
        params = {
            mix = 0.5,
            saturation = 0.4,
            wow = 0.15,
            flutter = 0.1,
            aging = 0.3,
            noise = 0.15,
            bias = 0.6,
            compression = 0.35,
            dropout = 0.05,
            width = 1.0
        }
    },
    {
        name = "Lo-Fi",
        description = "Degraded cassette",
        params = {
            mix = 0.7,
            saturation = 0.7,
            wow = 0.4,
            flutter = 0.3,
            aging = 0.6,
            noise = 0.4,
            bias = 0.4,
            compression = 0.5,
            dropout = 0.2,
            width = 0.85
        }
    },
    {
        name = "Destroyed",
        description = "Heavily damaged",
        params = {
            mix = 0.8,
            saturation = 0.9,
            wow = 0.7,
            flutter = 0.6,
            aging = 0.9,
            noise = 0.7,
            bias = 0.3,
            compression = 0.7,
            dropout = 0.5,
            width = 0.75
        }
    },
    {
        name = "Modern Clean",
        description = "Contemporary character",
        params = {
            mix = 0.4,
            saturation = 0.3,
            wow = 0.03,
            flutter = 0.0,
            aging = 0.1,
            noise = 0.05,
            bias = 0.55,
            compression = 0.4,
            dropout = 0.0,
            width = 1.05
        }
    }
}

function TapePresets.get_preset(index)
    if index >= 1 and index <= #TapePresets.presets then
        return TapePresets.presets[index]
    end
    return nil
end

function TapePresets.get_count()
    return #TapePresets.presets
end

function TapePresets.get_preset_names()
    local names = {}
    for i, preset in ipairs(TapePresets.presets) do
        names[i] = preset.name
    end
    return names
end

return TapePresets
