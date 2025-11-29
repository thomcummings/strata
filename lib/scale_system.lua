-- lib/scale_system.lua
-- Musical scale definitions and note mapping

local ScaleSystem = {}

-- Scale interval patterns (semitones from root)
ScaleSystem.scales = {
    ["Major"] = {0, 2, 4, 5, 7, 9, 11},
    ["Natural Minor"] = {0, 2, 3, 5, 7, 8, 10},
    ["Harmonic Minor"] = {0, 2, 3, 5, 7, 8, 11},
    ["Pentatonic Major"] = {0, 2, 4, 7, 9},
    ["Pentatonic Minor"] = {0, 3, 5, 7, 10},
    ["Dorian"] = {0, 2, 3, 5, 7, 9, 10},
    ["Phrygian"] = {0, 1, 3, 5, 7, 8, 10},
    ["Lydian"] = {0, 2, 4, 6, 7, 9, 11},
    ["Mixolydian"] = {0, 2, 4, 5, 7, 9, 10},
    ["Custom"] = {} -- User-defined, starts empty
}

-- Scale names in order for UI navigation
ScaleSystem.scale_names = {
    "Major",
    "Natural Minor", 
    "Harmonic Minor",
    "Pentatonic Major",
    "Pentatonic Minor",
    "Dorian",
    "Phrygian",
    "Lydian",
    "Mixolydian",
    "Custom"
}

-- Note names for display
ScaleSystem.note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

function ScaleSystem.init()
    -- Nothing needed for initialization
end

-- Convert MIDI note number to frequency
local function note_to_freq(note)
    return 440 * 2 ^ ((note - 69) / 12)
end

-- Get MIDI note number for a fader
-- fader_index: 0-7 (or 0-15 for 16 faders)
-- scale_name: name of scale from scales table
-- root_note: MIDI note number for root (e.g., 60 = middle C)
-- octave_offset: -2 to +2, shifts entire range
function ScaleSystem.get_note(fader_index, scale_name, root_note, octave_offset)
    local scale = ScaleSystem.scales[scale_name] or ScaleSystem.scales["Major"]
    local scale_length = #scale
    
    -- If scale is empty (custom not set up yet), use chromatic
    if scale_length == 0 then
        return util.clamp(root_note + fader_index + (octave_offset * 12), 0, 127)
    end
    
    -- Calculate which scale degree and octave
    local degree = fader_index % scale_length
    local octave = math.floor(fader_index / scale_length)
    
    -- Get interval for this degree
    local interval = scale[degree + 1] -- Lua arrays are 1-indexed
    
    -- Calculate final MIDI note
    local note = root_note + (octave * 12) + interval + (octave_offset * 12)
    
    return util.clamp(note, 0, 127)
end

-- Get frequency for a fader (converts MIDI note to Hz)
function ScaleSystem.get_frequency(fader_index, scale_name, root_note, octave_offset)
    local note = ScaleSystem.get_note(fader_index, scale_name, root_note, octave_offset)
    return note_to_freq(note)
end

-- Get display name for root note
function ScaleSystem.get_root_name(root_note)
    local note_in_octave = root_note % 12
    return ScaleSystem.note_names[note_in_octave + 1]
end

-- Set custom scale from array of note indices (0-11 for chromatic notes)
function ScaleSystem.set_custom_scale(note_indices)
    -- Limit to 8 notes max
    local limited = {}
    for i = 1, math.min(#note_indices, 8) do
        table.insert(limited, note_indices[i])
    end
    
    -- Sort intervals in ascending order
    table.sort(limited)
    
    ScaleSystem.scales["Custom"] = limited
end

-- Toggle a note in the custom scale
function ScaleSystem.toggle_custom_note(note_index)
    local custom = ScaleSystem.scales["Custom"]
    local found = false
    local found_idx = -1
    
    -- Check if note is already in scale
    for i, interval in ipairs(custom) do
        if interval == note_index then
            found = true
            found_idx = i
            break
        end
    end
    
    if found then
        -- Remove it
        table.remove(custom, found_idx)
    else
        -- Add it (if room)
        if #custom < 8 then
            table.insert(custom, note_index)
            table.sort(custom) -- Keep sorted
        end
    end
end

-- Check if a note is in the custom scale
function ScaleSystem.is_in_custom_scale(note_index)
    local custom = ScaleSystem.scales["Custom"]
    for i, interval in ipairs(custom) do
        if interval == note_index then
            return true
        end
    end
    return false
end

-- Get the next scale name (for cycling through scales)
function ScaleSystem.get_next_scale(current_scale, delta)
    local idx = 1
    for i, name in ipairs(ScaleSystem.scale_names) do
        if name == current_scale then
            idx = i
            break
        end
    end
    
    idx = util.wrap(idx + delta, 1, #ScaleSystem.scale_names)
    return ScaleSystem.scale_names[idx]
end

return ScaleSystem
