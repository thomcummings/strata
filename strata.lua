-- strata
-- 8-voice performance sampler
-- v1.0
--
-- inspired by vestax faderboard
--
-- K2: load sample
-- K3: start sequencer
-- E1: change page
-- E2/E3: adjust parameters
--
-- load chord packs in snapshots
-- sequence between snapshots
-- modulate with filters & lfos

engine.name = "Strata"

local ScaleSystem = include("lib/scale_system")
local MidiHandler = include("lib/midi_handler")
local SnapshotPacks = include("lib/snapshot_packs") 
local fileselect = require("fileselect")

-- File selection state
local selecting = false

-- Notification system
local notification = {
    active = false,
    message = "",
    start_time = 0,
    duration = 2.0
}

function show_notification(msg, duration)
    notification.message = msg
    notification.duration = duration or 2.0
    notification.start_time = util.time()
    notification.active = true
end

-- File selection callback
function load_file_callback(file)
    selecting = false
    if file ~= "cancel" then
        load_sample(file)
    end
end

-- Global state
local state = {
    -- Fader states
    faders = {},
    num_faders = 8,
    
    -- Sample parameters
    sample_path = "",
    loop_start = 0,
    loop_length = 1.0,  -- Changed from loop_end, now in seconds
    speed = 1.0,
    reverse = 0,
    sample_duration = 1.0,  -- Total sample length in seconds
    waveform = {},
    xfade_time = 0.1,
    sample_gain = 1.0,  -- Add this (0.1 to 2.0 range, 1.0 = unity)
    trigger_mode = false,

    -- Envelope parameters
    env_attack = 0.1,
    env_decay = 0.1,
    env_sustain = 1.0,
    env_release = 0.2,
    env_filter_mod = 0.0,  -- 0.0 to 1.0 (0% to 100% of 10kHz range)
    
    -- Scale parameters
    current_scale = "Major",
    root_note = 60,
    octave_offset = 0,
    octave_mode = "normal",
    
    -- Filter parameters
    master_filter_cutoff = 20000,
    master_filter_resonance = 0.1,
    master_filter_type = 0,
    filter_drive = 1.0,

    -- Reverb parameters (Greyhole)
    reverb_mix = 0.0,        -- 0.0 to 1.0 (wet/dry blend)
    reverb_time = 2.0,       -- 0.1 to 10.0 seconds (mapped to delayTime)
    reverb_size = 2.0,       -- 0.5 to 5.0 (room size)
    reverb_damping = 0.5,    -- 0.0 to 1.0 (high freq damping)
    reverb_feedback = 0.9,   -- 0.0 to 1.0 (reverb tail length)
    reverb_diff = 0.7,       -- 0.0 to 1.0 (diffusion/smoothness)
    reverb_mod_depth = 0.2,  -- 0.0 to 1.0 (modulation depth)
    reverb_mod_freq = 0.5,   -- 0.1 to 10.0 (modulation frequency)

    -- LFO parameters
    lfo_count = 3,  -- Can increase this later
    lfos = {
        {
            enabled = false,
            shape = 1,  -- 1=sine, 2=triangle, 3=square, 4=random
            rate_mode = 1,  -- 1=Hz, 2=BPM-sync
            rate_hz = 1.0,
            rate_bpm_div = 4,  -- Index into divisions table (1/4 note default)
            depth = 50,  -- -100 to +100
            destination = 1,  -- Index into destinations table
            dest_param = 1,  -- For destinations with multiple options (e.g., which fader)
            phase = 0,  -- Current phase 0-1
            value = 0   -- Current output value -1 to 1
        },
        {
            enabled = false,
            shape = 1,
            rate_mode = 1,
            rate_hz = 2.0,
            rate_bpm_div = 4,
            depth = 50,
            destination = 2,
            dest_param = 1,
            phase = 0,
            value = 0
        },
        {
            enabled = false,
            shape = 1,
            rate_mode = 1,
            rate_hz = 0.5,
            rate_bpm_div = 4,
            depth = 50,
            destination = 3,
            dest_param = 1,
            phase = 0,
            value = 0
        }
    },
    
    -- LFO destination definitions
    lfo_destinations = {
        {name = "Fader", has_param = true, param_name = "Fader#", param_min = 1, param_max = 8},
        {name = "Filter Cut", has_param = false},
        {name = "Filter Res", has_param = false},
        {name = "Smp Start", has_param = false},
        {name = "Smp Length", has_param = false},
        {name = "Smp Speed", has_param = false},
        {name = "Smp XFade", has_param = false},
        {name = "Smp Gain", has_param = false},
        {name = "Env Attack", has_param = false},
        {name = "Env Decay", has_param = false},
        {name = "Env Sustain", has_param = false},
        {name = "Env Release", has_param = false},
        {name = "Octave", has_param = false},
        {name = "Rvb Mix", has_param = false},
        {name = "Rvb Time", has_param = false},
        {name = "Rvb Size", has_param = false},
        {name = "Rvb Damping", has_param = false},
        {name = "Rvb Feedback", has_param = false},
        {name = "Rvb Diff", has_param = false},
        {name = "Rvb ModDepth", has_param = false},
        {name = "Rvb ModFreq", has_param = false}
    },
    
    -- LFO shape names
    lfo_shape_names = {"Sine", "Triangle", "Square", "Random", "Smooth Random"},
    
    -- LFO BPM divisions
    lfo_bpm_divisions = {
        {name = "1/16", beats = 0.25},
        {name = "1/8", beats = 0.5},
        {name = "1/4", beats = 1.0},
        {name = "1/2", beats = 2.0},
        {name = "1", beats = 4.0},
        {name = "2", beats = 8.0},
        {name = "4", beats = 16.0}
    },
    
    -- LFO UI state
    lfo_selected = 1,
    lfo_selected_param = 1,
    
    -- Recording state
    recording = false,
    recording_time = 0,
    recording_clock = nil,
    recording_start_time = 0, 
    
    -- Snapshot system (8 slots)
    snapshots = {},
    snapshot_next_empty = 1,
    snapshot_current = 0,
    snapshot_selected = 1,
    snapshot_pack_selected = 1,  -- ADD THIS
    
    snapshot_player = {
        playing = false,
        current_index = 1,
        mode = "sequential",  -- "sequential", "random", "pattern", "euclidean"
        bpm = 120,
        duration_beats = 4,
        
        -- Pattern mode
        pattern = {},
        pattern_position = 1,
        pattern_edit_value = 1,
        
        -- Euclidean mode
        euclidean_pulses = 4,
        euclidean_steps = 8,
        euclidean_rotation = 0,
        euclidean_rest_behavior = "hold",  -- "hold" or "fade"
        euclidean_pattern = {},
        euclidean_position = 1
    },
  
    -- Scene system (8 slots)
    scenes = {},
    scene_selected = 1,
    
    morphing = {
        active = false,
        from_positions = {},
        to_positions = {},
        target_positions = {},
        start_time = 0,
        duration = 2.0,
        progress = 0,
        manual_override = {}
    },
    
    -- UI state
    current_page = 1,
    selected_param = 1,
    k1_held = false,
    k3_held = false,
    
    -- Gate threshold
    gate_threshold = 0.01,

    -- MIDI keyboard support (chromatic, background, with velocity)
    keyboard = {
        next_voice = 0,  -- Round-robin voice allocation (0-7)
        active_notes = {}  -- Maps MIDI note number to voice index
    },
}

-- Initialize fader states
for i = 0, 7 do
    state.faders[i] = {
        position = 0,
        active = false,
        note = 0,
        freq = 440,
        was_above_threshold = false
    }
    state.morphing.manual_override[i] = false
    state.morphing.target_positions[i] = 0
end

-- Initialize 8 empty snapshot slots
for i = 1, 8 do
    state.snapshots[i] = {
        positions = {},
        enabled = true,
        empty = true
    }
end

-- Initialize 8 empty scene slots
for i = 1, 8 do
    state.scenes[i] = {
        empty = true
    }
end

-- Initialize LFO random values
for i = 1, state.lfo_count do
    state.lfos[i].random_value = 0
    state.lfos[i].next_random_value = (math.random() * 2) - 1
    state.lfos[i].last_phase = 0
end

-- Calculate normalized loop end from start + length
function calculate_loop_end()
    if state.sample_duration == 0 then
        return 1.0
    end
    local end_point = state.loop_start + (state.loop_length / state.sample_duration)
    return math.min(end_point, 1.0)
end

-- LFO calculation functions
function calculate_lfo_value(lfo)
    local phase = lfo.phase
    local value = 0
    
    if lfo.shape == 1 then
        -- Sine
        value = math.sin(phase * math.pi * 2)
    elseif lfo.shape == 2 then
        -- Triangle
        if phase < 0.5 then
            value = (phase * 4) - 1
        else
            value = 3 - (phase * 4)
        end
    elseif lfo.shape == 3 then
        -- Square
        value = phase < 0.5 and -1 or 1
    elseif lfo.shape == 4 then
        -- Random (sample and hold - changes at phase wrap)
        -- Value is stored and only updates when phase wraps
        if phase < lfo.last_phase then
            lfo.random_value = (math.random() * 2) - 1
        end
        value = lfo.random_value or 0
    elseif lfo.shape == 5 then
        -- Smooth Random (interpolated random)
        -- Smoothly glides from one random value to the next
        if phase < lfo.last_phase then
            -- Phase wrapped - move to next random value
            lfo.random_value = lfo.next_random_value or 0
            lfo.next_random_value = (math.random() * 2) - 1
        end
        -- Linear interpolation between current and next random value
        local current = lfo.random_value or 0
        local next = lfo.next_random_value or 0
        value = current + (next - current) * phase
    end

    lfo.last_phase = phase
    return value
end

function get_lfo_rate_hz(lfo)
    if lfo.rate_mode == 1 then
        -- Hz mode
        return lfo.rate_hz
    else
        -- BPM-sync mode
        local bpm = state.snapshot_player.bpm
        local beats = state.lfo_bpm_divisions[lfo.rate_bpm_div].beats
        local seconds_per_cycle = (beats / bpm) * 60
        return 1.0 / seconds_per_cycle
    end
end

function apply_lfo_modulation()
    for i = 1, state.lfo_count do
        local lfo = state.lfos[i]
        
        if not lfo.enabled then
            goto continue
        end
        
        local dest = state.lfo_destinations[lfo.destination]
        local mod_amount = lfo.value * (lfo.depth / 100.0)
        
        -- Route to destination
        if dest.name == "Fader" then
            local fader_idx = lfo.dest_param - 1  -- Convert to 0-indexed
            if fader_idx >= 0 and fader_idx < 8 then
                -- Only apply if not being controlled by MIDI or morphing
                if not state.morphing.active and not state.morphing.manual_override[fader_idx] then
                    local base_pos = state.faders[fader_idx].position
                    local new_pos = util.clamp(base_pos + mod_amount, 0, 1)
                    state.faders[fader_idx].position = new_pos
                    
                    if state.faders[fader_idx].active then
                        engine.setFaderPos(fader_idx, new_pos)
                    end
                end
            end
            
        elseif dest.name == "Filter Cut" then
            local base = state.master_filter_cutoff
            local range = 10000  -- ±10kHz modulation range
            local new_val = util.clamp(base + (mod_amount * range), 20, 20000)
            engine.setMasterFilter(new_val, state.master_filter_resonance, state.master_filter_type)
            
        elseif dest.name == "Filter Res" then
            local base = state.master_filter_resonance
            local new_val = util.clamp(base + (mod_amount * 0.5), 0, 1)
            engine.setMasterFilter(state.master_filter_cutoff, new_val, state.master_filter_type)
            
        elseif dest.name == "Smp Start" then
            local base = state.loop_start
            local new_val = util.clamp(base + (mod_amount * 0.5), 0, 0.99)
            engine.setLoopPoints(new_val, calculate_loop_end())
            
        elseif dest.name == "Smp Length" then
            local base = state.loop_length
            local max_range = state.sample_duration * 0.5
            local new_val = util.clamp(base + (mod_amount * max_range), 0.001, state.sample_duration)
            -- Temporarily update for engine (don't overwrite state)
            local temp_start = state.loop_start
            local temp_end = math.min(temp_start + (new_val / state.sample_duration), 1.0)
            engine.setLoopPoints(temp_start, temp_end)
            
        elseif dest.name == "Smp Speed" then
            local base = state.speed
            local new_val = util.clamp(base + (mod_amount * 1.0), 0.1, 2.0)
            engine.setSpeed(new_val)
            
        elseif dest.name == "Smp XFade" then
            local base = state.xfade_time
            local new_val = util.clamp(base + (mod_amount * 0.25), 0.01, 0.5)
            engine.setXfadeTime(new_val)
            
        
        elseif dest.name == "Smp Gain" then
            local base = state.sample_gain
            -- Asymmetric modulation: can go down to 0, but only up by +0.3
            local range_down = base  -- Can modulate all the way to zero
            local range_up = 0.3     -- Can only increase by 0.3
            local modulation = mod_amount < 0 and (mod_amount * range_down) or (mod_amount * range_up)
            local new_val = util.clamp(base + modulation, 0.0, 2.0)
            -- Apply to all voices
            for v = 0, 7 do
                engine.setVoiceAmp(v, new_val)
            end
            
        elseif dest.name == "Env Attack" then
            local base = state.env_attack
            local new_val = util.clamp(base + (mod_amount * 1.0), 0.001, 2.0)
            for v = 0, 7 do
                engine.setVoiceEnvelope(v, new_val, state.env_decay, state.env_sustain, state.env_release)
            end
            
        elseif dest.name == "Env Decay" then
            local base = state.env_decay
            local new_val = util.clamp(base + (mod_amount * 1.0), 0.01, 2.0)
            for v = 0, 7 do
                engine.setVoiceEnvelope(v, state.env_attack, new_val, state.env_sustain, state.env_release)
            end
            
        elseif dest.name == "Env Sustain" then
            local base = state.env_sustain
            local new_val = util.clamp(base + (mod_amount * 0.5), 0, 1.0)
            for v = 0, 7 do
                engine.setVoiceEnvelope(v, state.env_attack, state.env_decay, new_val, state.env_release)
            end
            
        elseif dest.name == "Env Release" then
            local base = state.env_release
            local new_val = util.clamp(base + (mod_amount * 2.5), 0.01, 5.0)
            for v = 0, 7 do
                engine.setVoiceEnvelope(v, state.env_attack, state.env_decay, state.env_sustain, new_val)
            end
            
        elseif dest.name == "Octave" then
            -- Octave modulation: quantize to integers -2 to +2
            local base = state.octave_offset
            local mod_octave = math.floor((mod_amount * 2) + 0.5)  -- Rounds to nearest integer
            local new_octave = util.clamp(base + mod_octave, -2, 2)

            -- Only update if octave changed
            if new_octave ~= state.octave_offset then
                state.octave_offset = new_octave
                update_all_notes()
            end

        -- Reverb parameters
        elseif dest.name == "Rvb Mix" then
            local base = state.reverb_mix
            local new_val = util.clamp(base + (mod_amount * 0.5), 0.0, 1.0)
            engine.setReverbMix(new_val)

        elseif dest.name == "Rvb Time" then
            local base = state.reverb_time
            local new_val = util.clamp(base + (mod_amount * 5.0), 0.1, 10.0)
            engine.setReverbTime(new_val)

        elseif dest.name == "Rvb Size" then
            local base = state.reverb_size
            local new_val = util.clamp(base + (mod_amount * 2.0), 0.5, 5.0)
            engine.setReverbSize(new_val)

        elseif dest.name == "Rvb Damping" then
            local base = state.reverb_damping
            local new_val = util.clamp(base + (mod_amount * 0.5), 0.0, 1.0)
            engine.setReverbDamping(new_val)

        elseif dest.name == "Rvb Feedback" then
            local base = state.reverb_feedback
            local new_val = util.clamp(base + (mod_amount * 0.5), 0.0, 1.0)
            engine.setReverbFeedback(new_val)

        elseif dest.name == "Rvb Diff" then
            local base = state.reverb_diff
            local new_val = util.clamp(base + (mod_amount * 0.5), 0.0, 1.0)
            engine.setReverbDiff(new_val)

        elseif dest.name == "Rvb ModDepth" then
            local base = state.reverb_mod_depth
            local new_val = util.clamp(base + (mod_amount * 0.5), 0.0, 1.0)
            engine.setReverbModDepth(new_val)

        elseif dest.name == "Rvb ModFreq" then
            local base = state.reverb_mod_freq
            local new_val = util.clamp(base + (mod_amount * 5.0), 0.1, 10.0)
            engine.setReverbModFreq(new_val)
        end
        
        ::continue::
    end
end

-- Euclidean rhythm generator (Bjorklund's algorithm)
function generate_euclidean_pattern(pulses, steps, rotation)
    if pulses >= steps then
        -- All steps are pulses
        local pattern = {}
        for i = 1, steps do
            pattern[i] = true
        end
        return pattern
    end
    
    if pulses == 0 then
        -- No pulses
        local pattern = {}
        for i = 1, steps do
            pattern[i] = false
        end
        return pattern
    end
    
    -- Bjorklund's algorithm
    local pattern = {}
    local counts = {}
    local remainders = {}
    
    local divisor = steps - pulses
    remainders[1] = pulses
    
    local level = 0
    
    repeat
        counts[level] = math.floor(divisor / remainders[level])
        remainders[level + 1] = divisor % remainders[level]
        divisor = remainders[level]
        level = level + 1
    until remainders[level] <= 1
    
    counts[level] = divisor
    
    -- Build pattern
    local function build(level)
        if level == -1 then
            table.insert(pattern, false)
        elseif level == -2 then
            table.insert(pattern, true)
        else
            for i = 1, counts[level] do
                build(level - 1)
            end
            if remainders[level] ~= 0 then
                build(level - 2)
            end
        end
    end
    
    build(level)
    
    -- Apply rotation
    if rotation ~= 0 then
        local rot = rotation % steps
        local rotated = {}
        for i = 1, steps do
            rotated[i] = pattern[((i - 1 - rot) % steps) + 1]
        end
        pattern = rotated
    end
    
    return pattern
end

-- Snapshot functions
function save_snapshot()
    -- Check if library is full
    local has_empty = false
    for i = 1, 8 do
        if state.snapshots[i].empty then
            has_empty = true
            break
        end
    end
    
    if not has_empty then
        show_notification("LIBRARY FULL", 2.0)
        return
    end
    
    local slot = state.snapshot_next_empty
    
    -- Capture current fader positions
    local positions = {}
    for i = 0, 7 do
        positions[i] = state.faders[i].position
    end
    
    state.snapshots[slot] = {
        positions = positions,
        enabled = true,
        empty = false
    }
    
    show_notification("SNP " .. slot .. " SAVED", 2.0)
    print("Snapshot saved to slot " .. slot)
    
    -- Find next empty slot
    state.snapshot_next_empty = find_next_empty_slot()
    
    -- Save to disk
    save_snapshots_to_disk()
end

function find_next_empty_slot()
    for i = 1, 8 do
        if state.snapshots[i].empty then
            return i
        end
    end
    -- All full, wrap to 1
    return 1
end

function get_enabled_snapshot_indices()
    local indices = {}
    for i = 1, 8 do
        if not state.snapshots[i].empty and state.snapshots[i].enabled then
            table.insert(indices, i)
        end
    end
    return indices
end

function get_next_snapshot_index()
    local enabled = get_enabled_snapshot_indices()
    
    if #enabled == 0 then
        return nil
    end
    
    if state.snapshot_player.mode == "sequential" then
        -- Find current index in enabled list
        local current_pos = 1
        for i, idx in ipairs(enabled) do
            if idx == state.snapshot_player.current_index then
                current_pos = i
                break
            end
        end
        -- Advance to next
        local next_pos = (current_pos % #enabled) + 1
        return enabled[next_pos]
        
    elseif state.snapshot_player.mode == "random" then
        return enabled[math.random(#enabled)]
        
    elseif state.snapshot_player.mode == "pattern" then
        if #state.snapshot_player.pattern == 0 then
            return nil
        end
        
        -- Advance position
        state.snapshot_player.pattern_position = 
            (state.snapshot_player.pattern_position % #state.snapshot_player.pattern) + 1
        
        return state.snapshot_player.pattern[state.snapshot_player.pattern_position]
        
    elseif state.snapshot_player.mode == "euclidean" then
        if #enabled == 0 then
            return nil
        end
        
        -- Generate pattern if needed
        if #state.snapshot_player.euclidean_pattern == 0 then
            state.snapshot_player.euclidean_pattern = generate_euclidean_pattern(
                state.snapshot_player.euclidean_pulses,
                state.snapshot_player.euclidean_steps,
                state.snapshot_player.euclidean_rotation
            )
        end
        
        -- Advance position
        state.snapshot_player.euclidean_position = 
            (state.snapshot_player.euclidean_position % state.snapshot_player.euclidean_steps) + 1
        
        local is_pulse = state.snapshot_player.euclidean_pattern[state.snapshot_player.euclidean_position]
        
        if is_pulse then
            -- Advance to next enabled snapshot
            local current_pos = 1
            for i, idx in ipairs(enabled) do
                if idx == state.snapshot_player.current_index then
                    current_pos = i
                    break
                end
            end
            local next_pos = (current_pos % #enabled) + 1
            return enabled[next_pos]
        else
            -- Rest - either hold or fade to zero
            if state.snapshot_player.euclidean_rest_behavior == "fade" then
                return "rest"  -- Special indicator to morph to zero
            else
                return nil  -- Hold current
            end
        end
    end
end

function start_morph(to_idx)
    if to_idx == "rest" then
        -- Morph all faders to zero
        local from_positions = {}
        for i = 0, 7 do
            from_positions[i] = state.faders[i].position
        end
        
        local to_positions = {}
        for i = 0, 7 do
            to_positions[i] = 0
        end
        
        state.morphing.from_positions = from_positions
        state.morphing.to_positions = to_positions
        state.morphing.start_time = util.time()
        state.morphing.progress = 0
        state.morphing.active = true
        
        for i = 0, 7 do
            state.morphing.manual_override[i] = false
        end
        
        state.snapshot_current = 0
        print("Morphing to rest")
        return
    end
    
    if state.snapshots[to_idx].empty then
        return
    end
    
    -- Capture current fader positions as "from"
    local from_positions = {}
    for i = 0, 7 do
        from_positions[i] = state.faders[i].position
    end
    
    state.morphing.from_positions = from_positions
    state.morphing.to_positions = state.snapshots[to_idx].positions
    state.morphing.start_time = util.time()
    state.morphing.progress = 0
    state.morphing.active = true
    
    -- Reset manual override flags
    for i = 0, 7 do
        state.morphing.manual_override[i] = false
    end
    
    state.snapshot_current = to_idx
    
    print("Morphing to snapshot " .. to_idx)
end

function jump_to_snapshot(idx)
    if state.snapshots[idx].empty then
        return
    end
    
    -- Stop sequencer if playing
    if state.snapshot_player.playing then
        stop_snapshot_sequencer()
    end
    
    start_morph(idx)
end

function clear_snapshot(idx)
    state.snapshots[idx] = {
        positions = {},
        enabled = true,
        empty = true
    }
    
    -- Update next empty slot
    state.snapshot_next_empty = find_next_empty_slot()
    
    show_notification("SNP " .. idx .. " CLEARED", 1.5)
    print("Cleared snapshot " .. idx)
    save_snapshots_to_disk()
end

function toggle_snapshot_enabled(idx)
    if not state.snapshots[idx].empty then
        state.snapshots[idx].enabled = not state.snapshots[idx].enabled
        local status = state.snapshots[idx].enabled and "ENABLED" or "DISABLED"
        show_notification("SNP " .. idx .. " " .. status, 1.5)
        save_snapshots_to_disk()
    end
end

function generate_snapshot_from_chord(chord_data)
    -- Simply return the fader positions directly
    -- The chord_data.faders array already has 8 values (0.0-1.0)
    local positions = {}
    for i = 0, 7 do
        positions[i] = chord_data.faders[i + 1]  -- Lua arrays are 1-indexed
    end
    return positions
end

function load_snapshot_pack(pack_idx)
    if pack_idx < 1 or pack_idx > #SnapshotPacks.packs then
        return
    end
    
    local pack = SnapshotPacks.packs[pack_idx]
    
    -- Load all 8 chords into snapshot slots
    for i = 1, 8 do
        if i <= #pack.chords then
            local positions = generate_snapshot_from_chord(pack.chords[i])
            
            state.snapshots[i] = {
                positions = positions,
                enabled = true,
                empty = false
            }
        else
            -- Empty any remaining slots
            state.snapshots[i] = {
                positions = {},
                enabled = true,
                empty = true
            }
        end
    end
    
    -- Update next empty slot
    state.snapshot_next_empty = find_next_empty_slot()
    
    show_notification("LOADED: " .. pack.name, 2.0)
    print("Loaded snapshot pack: " .. pack.name)
    
    -- Save to disk
    save_snapshots_to_disk()
end

-- Pattern mode functions
function pattern_add_snapshot()
    if #state.snapshot_player.pattern >= 16 then
        show_notification("PATTERN FULL", 1.5)
        return
    end
    
    table.insert(state.snapshot_player.pattern, state.snapshot_player.pattern_edit_value)
    show_notification("ADDED " .. state.snapshot_player.pattern_edit_value, 1.0)
    save_snapshots_to_disk()
end

function pattern_remove_last()
    if #state.snapshot_player.pattern > 0 then
        local removed = table.remove(state.snapshot_player.pattern)
        show_notification("REMOVED " .. removed, 1.0)
        save_snapshots_to_disk()
    end
end

function pattern_clear()
    state.snapshot_player.pattern = {}
    state.snapshot_player.pattern_position = 1
    show_notification("PATTERN CLEARED", 1.5)
    save_snapshots_to_disk()
end

function start_snapshot_sequencer()
    local enabled = get_enabled_snapshot_indices()
    
    if state.snapshot_player.mode == "pattern" then
        if #state.snapshot_player.pattern == 0 then
            show_notification("PATTERN EMPTY", 2.0)
            return
        end
        state.snapshot_player.pattern_position = 0  -- Will advance to 1
    elseif state.snapshot_player.mode == "euclidean" then
        -- Generate euclidean pattern
        state.snapshot_player.euclidean_pattern = generate_euclidean_pattern(
            state.snapshot_player.euclidean_pulses,
            state.snapshot_player.euclidean_steps,
            state.snapshot_player.euclidean_rotation
        )
        state.snapshot_player.euclidean_position = 0  -- Will advance to 1
    else
        if #enabled == 0 then
            show_notification("NO ENABLED SNPS", 2.0)
            print("No enabled snapshots!")
            return
        end
        state.snapshot_player.current_index = enabled[1]
    end
    
    state.snapshot_player.playing = true
    
    print("Sequencer started")
end

function stop_snapshot_sequencer()
    state.snapshot_player.playing = false
    print("Sequencer stopped")
end

-- Save/load snapshots to disk
function save_snapshots_to_disk()
    local path = _path.data .. "strata/"
    util.make_dir(path)
    
    local data = {
        snapshots = state.snapshots,
        next_empty = state.snapshot_next_empty,
        player = state.snapshot_player
    }
    
    tab.save(data, path .. "snapshots.data")
end

function load_snapshots()
    local path = _path.data .. "strata/snapshots.data"
    
    if util.file_exists(path) then
        local data = tab.load(path)
        if data then
            state.snapshots = data.snapshots or state.snapshots
            state.snapshot_next_empty = data.next_empty or 1
            if data.player then
                state.snapshot_player.mode = data.player.mode or "sequential"
                state.snapshot_player.bpm = data.player.bpm or 120
                state.snapshot_player.duration_beats = data.player.duration_beats or 4
                state.snapshot_player.pattern = data.player.pattern or {}
                state.snapshot_player.euclidean_pulses = data.player.euclidean_pulses or 4
                state.snapshot_player.euclidean_steps = data.player.euclidean_steps or 8
                state.snapshot_player.euclidean_rotation = data.player.euclidean_rotation or 0
                state.snapshot_player.euclidean_rest_behavior = data.player.euclidean_rest_behavior or "hold"
            end
            print("Snapshots loaded")
        end
    end
end

-- Scene management functions
function save_scene(slot)
    -- Capture complete state
    state.scenes[slot] = {
        empty = false,
        
        -- Snapshots
        snapshots = {},
        snapshot_next_empty = state.snapshot_next_empty,
        
        -- Sample settings
        sample_path = state.sample_path,
        loop_start = state.loop_start,
        loop_length = state.loop_length,
        speed = state.speed,
        reverse = state.reverse,
        xfade_time = state.xfade_time,
        sample_duration = state.sample_duration,
        trigger_mode = state.trigger_mode,
        
        -- Envelope
        env_attack = state.env_attack,
        env_decay = state.env_decay,
        env_sustain = state.env_sustain,
        env_release = state.env_release,
        env_filter_mod = state.env_filter_mod,
        
        -- Scale
        current_scale = state.current_scale,
        root_note = state.root_note,
        octave_offset = state.octave_offset,
        octave_mode = state.octave_mode,
        
        -- Filter
        master_filter_cutoff = state.master_filter_cutoff,
        master_filter_resonance = state.master_filter_resonance,
        master_filter_type = state.master_filter_type,
        filter_drive = state.filter_drive,

        -- Reverb
        reverb_mix = state.reverb_mix,
        reverb_time = state.reverb_time,
        reverb_size = state.reverb_size,
        reverb_damping = state.reverb_damping,
        reverb_feedback = state.reverb_feedback,
        reverb_diff = state.reverb_diff,
        reverb_mod_depth = state.reverb_mod_depth,
        reverb_mod_freq = state.reverb_mod_freq,

        -- LFO (placeholder for future)
        lfos = {
            {rate = state.lfos[1].rate, depth = state.lfos[1].depth, shape = state.lfos[1].shape},
            {rate = state.lfos[2].rate, depth = state.lfos[2].depth, shape = state.lfos[2].shape},
            {rate = state.lfos[3].rate, depth = state.lfos[3].depth, shape = state.lfos[3].shape}
        },
        
        -- Sequencer
        snapshot_player_mode = state.snapshot_player.mode,
        snapshot_player_bpm = state.snapshot_player.bpm,
        snapshot_player_duration_beats = state.snapshot_player.duration_beats,
        snapshot_player_pattern = {},
        snapshot_player_euclidean_pulses = state.snapshot_player.euclidean_pulses,
        snapshot_player_euclidean_steps = state.snapshot_player.euclidean_steps,
        snapshot_player_euclidean_rotation = state.snapshot_player.euclidean_rotation,
        snapshot_player_euclidean_rest_behavior = state.snapshot_player.euclidean_rest_behavior
    }
    
    -- Deep copy snapshots
    for i = 1, 8 do
        state.scenes[slot].snapshots[i] = {
            positions = {},
            enabled = state.snapshots[i].enabled,
            empty = state.snapshots[i].empty
        }
        if not state.snapshots[i].empty then
            for j = 0, 7 do
                state.scenes[slot].snapshots[i].positions[j] = state.snapshots[i].positions[j]
            end
        end
    end
    
    -- Deep copy pattern
    for i, v in ipairs(state.snapshot_player.pattern) do
        table.insert(state.scenes[slot].snapshot_player_pattern, v)
    end
    
    show_notification("SCENE " .. slot .. " SAVED", 2.0)
    save_scenes_to_disk()
end

function load_scene(slot)
    if state.scenes[slot].empty then
        show_notification("SCENE EMPTY", 1.5)
        return
    end
    
    local scene = state.scenes[slot]
    
    -- Stop sequencer if playing
    if state.snapshot_player.playing then
        stop_snapshot_sequencer()
    end
    
    -- Load snapshots
    for i = 1, 8 do
        state.snapshots[i] = {
            positions = {},
            enabled = scene.snapshots[i].enabled,
            empty = scene.snapshots[i].empty
        }
        if not scene.snapshots[i].empty then
            for j = 0, 7 do
                state.snapshots[i].positions[j] = scene.snapshots[i].positions[j]
            end
        end
    end
    state.snapshot_next_empty = scene.snapshot_next_empty
    
    -- Load sample
    if scene.sample_path ~= "" then
        if util.file_exists(scene.sample_path) then
            load_sample(scene.sample_path)
        else
            show_notification("SAMPLE NOT FOUND", 3.0)
            state.sample_path = ""
            state.current_page = 2  -- Jump to SAMPLE page
        end
    end
    
    -- Load sample settings
    state.loop_start = scene.loop_start
    state.loop_length = scene.loop_length
    state.speed = scene.speed
    state.reverse = scene.reverse
    state.xfade_time = scene.xfade_time
    state.sample_duration = scene.sample_duration
    state.trigger_mode = scene.trigger_mode or false
    
    -- Load envelope
    state.env_attack = scene.env_attack
    state.env_decay = scene.env_decay
    state.env_sustain = scene.env_sustain
    state.env_release = scene.env_release
    state.env_filter_mod = scene.env_filter_mod or 0.0
    
    -- Load scale
    state.current_scale = scene.current_scale
    state.root_note = scene.root_note
    state.octave_offset = scene.octave_offset
    state.octave_mode = scene.octave_mode
    
    -- Load filter
    state.master_filter_cutoff = scene.master_filter_cutoff
    state.master_filter_resonance = scene.master_filter_resonance
    state.master_filter_type = scene.master_filter_type
    state.filter_drive = scene.filter_drive

    -- Load reverb (with defaults for backward compatibility)
    state.reverb_mix = scene.reverb_mix or 0.0
    state.reverb_time = scene.reverb_time or 2.0
    state.reverb_size = scene.reverb_size or 2.0
    state.reverb_damping = scene.reverb_damping or 0.5
    state.reverb_feedback = scene.reverb_feedback or 0.9
    state.reverb_diff = scene.reverb_diff or 0.7
    state.reverb_mod_depth = scene.reverb_mod_depth or 0.2
    state.reverb_mod_freq = scene.reverb_mod_freq or 0.5

    -- Load LFO (placeholder)
    state.lfos[1].rate = scene.lfos[1].rate
    state.lfos[1].depth = scene.lfos[1].depth
    state.lfos[1].shape = scene.lfos[1].shape
    state.lfos[2].rate = scene.lfos[2].rate
    state.lfos[2].depth = scene.lfos[2].depth
    state.lfos[2].shape = scene.lfos[2].shape
    state.lfos[3].rate = scene.lfos[3].rate
    state.lfos[3].depth = scene.lfos[3].depth
    state.lfos[3].shape = scene.lfos[3].shape
    
    -- Load sequencer
    state.snapshot_player.mode = scene.snapshot_player_mode
    state.snapshot_player.bpm = scene.snapshot_player_bpm
    state.snapshot_player.duration_beats = scene.snapshot_player_duration_beats
    state.snapshot_player.pattern = {}
    for i, v in ipairs(scene.snapshot_player_pattern) do
        table.insert(state.snapshot_player.pattern, v)
    end
    state.snapshot_player.euclidean_pulses = scene.snapshot_player_euclidean_pulses
    state.snapshot_player.euclidean_steps = scene.snapshot_player_euclidean_steps
    state.snapshot_player.euclidean_rotation = scene.snapshot_player_euclidean_rotation
    state.snapshot_player.euclidean_rest_behavior = scene.snapshot_player_euclidean_rest_behavior
    
    -- Reset sequencer state
    state.snapshot_player.pattern_position = 1
    state.snapshot_player.euclidean_pattern = {}
    state.snapshot_player.euclidean_position = 1
    
    -- Apply settings to engine
    engine.setLoopPoints(state.loop_start, calculate_loop_end())
    engine.setSpeed(state.speed)
    engine.setReverse(state.reverse)
    engine.setXfadeTime(state.xfade_time)
    engine.setMasterFilter(state.master_filter_cutoff, state.master_filter_resonance, state.master_filter_type)

    -- Apply reverb settings
    engine.setReverbMix(state.reverb_mix)
    engine.setReverbTime(state.reverb_time)
    engine.setReverbSize(state.reverb_size)
    engine.setReverbDamping(state.reverb_damping)
    engine.setReverbFeedback(state.reverb_feedback)
    engine.setReverbDiff(state.reverb_diff)
    engine.setReverbModDepth(state.reverb_mod_depth)
    engine.setReverbModFreq(state.reverb_mod_freq)

    for i = 0, state.num_faders - 1 do
        engine.setVoiceEnvelope(i, state.env_attack, state.env_decay, state.env_sustain, state.env_release)
    end

    -- Apply envelope filter modulation
    engine.setEnvFilterMod(state.env_filter_mod)

    -- Update any active notes with new scale
    update_all_notes()
    
    if util.file_exists(scene.sample_path) then
        show_notification("SCENE " .. slot .. " LOADED", 2.0)
    end
end

function clear_scene(slot)
    state.scenes[slot] = {
        empty = true
    }
    show_notification("SCENE " .. slot .. " CLEARED", 1.5)
    save_scenes_to_disk()
end

-- Save/load scenes to disk
function save_scenes_to_disk()
    local path = _path.data .. "strata/"
    util.make_dir(path)
    
    tab.save(state.scenes, path .. "scenes.data")
end

function load_scenes_from_disk()
    local path = _path.data .. "strata/scenes.data"
    
    if util.file_exists(path) then
        local data = tab.load(path)
        if data then
            -- Ensure all 8 slots exist
            for i = 1, 8 do
                if data[i] then
                    state.scenes[i] = data[i]
                else
                    state.scenes[i] = { empty = true }
                end
            end
            print("Scenes loaded")
        end
    end
end

function init()
    -- Initialize subsystems
    ScaleSystem.init()
    MidiHandler.init()
    
    -- Set default MIDI CC range to 34-41
    MidiHandler.set_fader_cc_start(34)
    
    -- Load saved snapshots
    load_snapshots()
        
    -- Load saved scenes
    load_scenes_from_disk()
    
    -- Set up MIDI callbacks
    MidiHandler.on_fader = handle_fader_change
    MidiHandler.on_filter_cutoff = handle_filter_cutoff
    MidiHandler.on_filter_resonance = handle_filter_resonance
    MidiHandler.on_voice_filter_offset = handle_voice_filter_offset
    MidiHandler.on_note_on = handle_note_on
    MidiHandler.on_note_off = handle_note_off
    
    -- Set up OSC receiver for waveform data, sample duration, and input levels
    osc.event = function(path, args, from)
        if path == "/waveform" then
            state.waveform = {}
            for i, val in ipairs(args) do
                table.insert(state.waveform, val)
            end
        elseif path == "/sample_duration" then
            state.sample_duration = args[1]
            print("Sample duration: " .. string.format("%.2f", state.sample_duration) .. "s")
        elseif path == "/recording_levels" then
            -- Receive accumulated peak levels from engine
            local peakL = args[1]
            local peakR = args[2]
            print("Received levels: L=" .. string.format("%.3f", peakL) ..
                  " R=" .. string.format("%.3f", peakR))

            -- Determine mono/stereo with threshold
            local threshold = 0.01
            local hasLeft = peakL > threshold
            local hasRight = peakR > threshold

            -- Store for use in file writing
            state.recording_is_mono = hasLeft ~= hasRight
            state.recording_mono_voice = hasLeft and 1 or 2

            print("Detection: " .. (state.recording_is_mono and "MONO" or "STEREO"))
            if state.recording_is_mono then
                print("Mono source: " .. (state.recording_mono_voice == 1 and "LEFT" or "RIGHT"))
            end

            -- Trigger the actual file write
            clock.run(write_recording_file)
        end
        -- Note: Recording levels monitored via SC control buses
    end
    
    -- Wait for engine to be ready
    clock.run(function()
        clock.sleep(0.5)
        
        -- Set initial engine parameters
          engine.setMasterFilter(state.master_filter_cutoff, state.master_filter_resonance, state.master_filter_type)
          engine.setSpeed(state.speed)
          engine.setReverse(state.reverse)
          engine.setLoopPoints(state.loop_start, calculate_loop_end())  -- Changed to use helper
          engine.setXfadeTime(state.xfade_time)

        -- Set reverb parameters
        engine.setReverbMix(state.reverb_mix)
        engine.setReverbTime(state.reverb_time)
        engine.setReverbSize(state.reverb_size)
        engine.setReverbDamping(state.reverb_damping)
        engine.setReverbFeedback(state.reverb_feedback)
        engine.setReverbDiff(state.reverb_diff)
        engine.setReverbModDepth(state.reverb_mod_depth)
        engine.setReverbModFreq(state.reverb_mod_freq)

        -- Set envelope for all voices
        for i = 0, state.num_faders - 1 do
            engine.setVoiceEnvelope(i, state.env_attack, state.env_decay, state.env_sustain, state.env_release)
        end

        -- Set envelope filter modulation
        engine.setEnvFilterMod(state.env_filter_mod)

        print("Strata v1.2 ready")
        print("MIDI channel: " .. MidiHandler.midi_channel)
        print("Fader CCs: " .. MidiHandler.fader_cc_start .. "-" .. (MidiHandler.fader_cc_start + 7))
    end)
    
    -- Start notification timeout clock
    clock.run(function()
        while true do
            clock.sleep(0.1)
            if notification.active then
                if util.time() - notification.start_time > notification.duration then
                    notification.active = false
                end
            end
        end
    end)
    
    -- Start morph clock
    clock.run(morph_clock)
    
    -- Start sequencer clock
    clock.run(sequencer_clock)
    
    -- Start LFO clock
    clock.run(lfo_clock)
    
    -- Start UI refresh clock
    clock.run(function()
        while true do
            clock.sleep(1/15)
            redraw()
        end
    end)
end

-- Morph clock - handles interpolation
function morph_clock()
    while true do
        clock.sleep(1/60)  -- 60 FPS update
        
        if state.morphing.active then
            local elapsed = util.time() - state.morphing.start_time
            state.morphing.progress = math.min(elapsed / state.morphing.duration, 1.0)
            
            -- Interpolate each fader position
            for i = 0, 7 do
                if not state.morphing.manual_override[i] then
                    local from = state.morphing.from_positions[i]
                    local to = state.morphing.to_positions[i]
                    local target = from + (to - from) * state.morphing.progress
                    
                    state.morphing.target_positions[i] = target
                    
                    -- Apply to fader state
                    state.faders[i].position = target
                    
                    -- Update engine
                    if state.faders[i].active then
                        engine.setFaderPos(i, target)
                    end
                    
                    -- Handle gate threshold crossing
                    if target > state.gate_threshold and not state.faders[i].active then
                        trigger_note(i)
                    elseif target <= state.gate_threshold and state.faders[i].active then
                        release_note(i)
                    end
                end
            end
            
            -- Morph complete
            if state.morphing.progress >= 1.0 then
                state.morphing.active = false
            end
        end
    end
end

-- Sequencer clock
function sequencer_clock()
    while true do
        if state.snapshot_player.playing then
            local beat_time = 60.0 / state.snapshot_player.bpm
            local wait_time = beat_time * state.snapshot_player.duration_beats
            
            -- Wait for morph to complete before advancing
            while state.morphing.active do
                clock.sleep(0.1)
            end
            
            clock.sleep(wait_time)
            
            -- Advance to next snapshot
            local next_idx = get_next_snapshot_index()
            if next_idx then
                state.snapshot_player.current_index = next_idx
                start_morph(next_idx)
            end
        else
            clock.sleep(0.1)
        end
    end
end

-- LFO clock
function lfo_clock()
    local last_time = util.time()
    
    while true do
        clock.sleep(1/60)  -- 60 FPS
        
        local current_time = util.time()
        local dt = current_time - last_time
        last_time = current_time
        
        for i = 1, state.lfo_count do            state.recording_time = state.recording_time + 0.1

            local lfo = state.lfos[i]
            
            if lfo.enabled then
                -- Advance phase
                local rate_hz = get_lfo_rate_hz(lfo)
                lfo.phase = (lfo.phase + (rate_hz * dt)) % 1.0
                
                -- Calculate value
                lfo.value = calculate_lfo_value(lfo)
            end
        end
        
        -- Apply modulation
        apply_lfo_modulation()
    end
end

-- Handle fader CC changes
function handle_fader_change(fader_idx, position)
    -- Ignore MIDI during recording
    if state.recording then
        return
    end
    
    local fader = state.faders[fader_idx]
    local was_active = fader.active
    
    -- Check if this is manual override during morph
    if state.morphing.active then
        state.morphing.manual_override[fader_idx] = true
    end
    
    fader.position = position
    
    local is_above = position > state.gate_threshold
    local was_above = fader.was_above_threshold
    
    if state.trigger_mode then
        -- TRIGGER MODE: Retrigger on every threshold crossing
        if is_above and not was_above then
            -- Crossed threshold UP - always retrigger
            if was_active then
                release_note(fader_idx)
            end
            trigger_note(fader_idx)
        elseif not is_above and was_active then
            -- Dropped below threshold - release
            release_note(fader_idx)
        elseif is_above and was_active then
            -- Still above - just update position
            engine.setFaderPos(fader_idx, position)
        end
    else
        -- GATE MODE: Smooth envelope control (current behavior)
        if is_above then
            if not was_active then
                trigger_note(fader_idx)
            else
                engine.setFaderPos(fader_idx, position)
            end
        else
            if was_active then
                release_note(fader_idx)
            end
        end
    end
    
    fader.was_above_threshold = is_above
end

-- Trigger a note on a fader
function trigger_note(fader_idx)
    local fader = state.faders[fader_idx]
    
    local octave_shift = state.octave_offset
    if state.octave_mode == "random" then
        octave_shift = octave_shift + math.random(-1, 1)
    end
    
    local freq = ScaleSystem.get_frequency(
        fader_idx,
        state.current_scale,
        state.root_note,
        octave_shift
    )
    
    fader.freq = freq
    fader.active = true
    
    engine.noteOn(fader_idx, freq)
    engine.setFaderPos(fader_idx, fader.position)
end

-- Release a note on a fader
function release_note(fader_idx)
    local fader = state.faders[fader_idx]
    fader.active = false

    engine.noteOff(fader_idx)
end

-- MIDI Keyboard handlers (chromatic, always-on, with velocity)
function handle_note_on(note, vel)
    -- Ignore during recording
    if state.recording then
        return
    end

    -- Check if note is already playing
    if state.keyboard.active_notes[note] then
        return  -- Already playing this note
    end

    -- Allocate next voice (round-robin)
    local voice = state.keyboard.next_voice

    -- If this voice is already playing a keyboard note, release it
    for midi_note, voice_idx in pairs(state.keyboard.active_notes) do
        if voice_idx == voice then
            state.keyboard.active_notes[midi_note] = nil
            break
        end
    end

    -- Calculate chromatic frequency (MIDI note to Hz)
    -- A4 (MIDI 69) = 440 Hz
    local freq = 440 * math.pow(2, (note - 69) / 12)

    -- Convert MIDI velocity (0-127) to position (0-1.0)
    local velocity = vel / 127.0

    -- Track this note
    state.keyboard.active_notes[note] = voice

    -- Advance to next voice (round-robin 0-7)
    state.keyboard.next_voice = (voice + 1) % 8

    -- Trigger note on engine with velocity
    engine.noteOn(voice, freq)
    engine.setFaderPos(voice, velocity)
end

function handle_note_off(note, vel)
    -- Ignore during recording
    if state.recording then
        return
    end

    -- Find which voice is playing this note
    local voice = state.keyboard.active_notes[note]
    if voice then
        -- Release the note
        engine.noteOff(voice)

        -- Remove from active notes
        state.keyboard.active_notes[note] = nil
    end
end

-- Load a sample
function load_sample(path)
    if util.file_exists(path) then
        state.sample_path = path
        engine.loadSample(path)
        print("Loading sample: " .. path)
        state.waveform = {}
        -- Reset loop points to full sample (will be updated when duration arrives)
        state.loop_start = 0
        state.loop_length = state.sample_duration
    else
        print("ERROR: File not found: " .. path)
    end
end

-- Start recording
function start_recording()
    -- FORCE stop all playback
    for i = 0, 7 do
        -- Force gate off and zero position
        engine.noteOff(i)
        state.faders[i].active = false
        state.faders[i].position = 0
        engine.setFaderPos(i, 0)
    end
    
    -- Stop sequencer if playing
    if state.snapshot_player.playing then
        stop_snapshot_sequencer()
    end
    
    -- Save current state to restore if cancelled
    state.recording_saved_path = state.sample_path
    state.recording_saved_waveform = {}
    for i, v in ipairs(state.waveform) do
        state.recording_saved_waveform[i] = v
    end
    state.recording_saved_duration = state.sample_duration
    
    state.recording = true
    state.recording_time = 0
    state.recording_level_l = 0
    state.recording_level_r = 0
    state.recording_peak_l = 0  -- Track peak levels to detect mono
    state.recording_peak_r = 0
    
    -- Create date-organized folder structure
    local date_folder = os.date("%Y%m%d")
    local timestamp = os.date("%H%M%S")
    local filename = timestamp .. "_strata_rec.wav"
    local folder_path = _path.audio .. "strata/" .. date_folder .. "/"
    local path = folder_path .. filename

    -- Create both base and date folders
    util.make_dir(_path.audio .. "strata/")
    util.make_dir(folder_path)

    state.recording_path = path
    
    -- Simple stereo recording setup
    -- Voice 1 - LEFT channel
    softcut.enable(1, 1)
    softcut.buffer(1, 1)
    softcut.level(1, 1.0)
    softcut.level_slew_time(1, 0)
    softcut.level_input_cut(1, 1, 1.0)
    softcut.level_input_cut(2, 1, 0.0)
    softcut.pan(1, 0)
    softcut.play(1, 1)
    softcut.rate(1, 1)
    softcut.rate_slew_time(1, 0)
    softcut.loop_start(1, 0)
    softcut.loop_end(1, 30)
    softcut.loop(1, 1)
    softcut.fade_time(1, 0.1)
    softcut.rec(1, 1)
    softcut.rec_level(1, 1.0)
    softcut.pre_level(1, 0.0)
    softcut.position(1, 0)
    softcut.rec_offset(1, 0)
    
    -- Voice 2 - RIGHT channel
    softcut.enable(2, 1)
    softcut.buffer(2, 2)
    softcut.level(2, 1.0)
    softcut.level_slew_time(2, 0)
    softcut.level_input_cut(1, 2, 0.0)
    softcut.level_input_cut(2, 2, 1.0)
    softcut.pan(2, 0)
    softcut.play(2, 1)
    softcut.rate(2, 1)
    softcut.rate_slew_time(2, 0)
    softcut.loop_start(2, 0)
    softcut.loop_end(2, 30)
    softcut.loop(2, 1)
    softcut.fade_time(2, 0.1)
    softcut.rec(2, 1)
    softcut.rec_level(2, 1.0)
    softcut.pre_level(2, 0.0)
    softcut.position(2, 0)
    softcut.rec_offset(2, 0)
    
    -- Start input monitoring for VU meters (using norns audio API)
    audio.level_adc_cut(1)  -- Enable ADC monitoring
    audio.level_cut(0.05)   -- Fast meter response

    -- Stop any existing recording clock
    if state.recording_clock then
        clock.cancel(state.recording_clock)
    end

    -- Store start time
    state.recording_start_time = util.time()

    -- Start engine input monitoring (tracks peaks in SC)
    engine.startInputMonitor()

    -- Simple timer clock for recording timeout
    state.recording_clock = clock.run(function()
        while state.recording do
            clock.sleep(0.1)  -- Check every 100ms

            -- Update time from start
            state.recording_time = util.time() - state.recording_start_time

            -- Debug: show time every second
            if math.floor(state.recording_time) ~= math.floor(state.recording_time - 0.1) then
                print("Recording time: " .. string.format("%.1f", state.recording_time) .. "s")
            end

            if state.recording_time >= 30 then
                print("Recording timeout reached at 30s")
                stop_recording()
                break
            end
        end
        state.recording_clock = nil
    end)

    print("Recording started: " .. filename)
    show_notification("RECORDING", 1.0)
end

-- Cancel recording
function cancel_recording()
    if not state.recording then
        return
    end
    
    state.recording = false
    
    -- Stop recording
    softcut.rec(1, 0)
    softcut.rec(2, 0)
    softcut.play(1, 0)
    softcut.play(2, 0)
    softcut.enable(1, 0)
    softcut.enable(2, 0)

    -- Stop engine monitoring
    engine.stopInputMonitor()

    -- Stop recording clock
    if state.recording_clock then
        clock.cancel(state.recording_clock)
        state.recording_clock = nil
    end
    
    -- Restore previous state
    state.sample_path = state.recording_saved_path
    state.waveform = state.recording_saved_waveform
    state.sample_duration = state.recording_saved_duration  -- Fixed typo here
    
    print("Recording cancelled")
    show_notification("CANCELLED", 1.5)
end

-- Write recording file (called after level analysis)
function write_recording_file()
    local duration = state.recording_time
    local path = state.recording_path

    show_notification("SAVING...", 2.0)

    -- Write file based on mono/stereo detection
    if state.recording_is_mono then
        local voice = state.recording_mono_voice
        print("Writing mono file from voice " .. voice .. "...")
        softcut.buffer_write_mono(path, 0, duration, voice)
    else
        print("Writing stereo file...")
        softcut.buffer_write_stereo(path, 0, duration, 1, 2)
    end

    print("Saving to: " .. path)

    -- Wait for file write, then clean up and load
    clock.sleep(duration * 0.1 + 1)  -- Wait proportional to recording length

    -- Stop playback and disable softcut
    softcut.play(1, 0)
    softcut.play(2, 0)
    softcut.enable(1, 0)
    softcut.enable(2, 0)

    -- Verify and load
    if util.file_exists(path) then
        print("File verified, loading...")
        load_sample(path)
        show_notification("LOADED: " .. string.format("%.1fs", duration), 2.0)
    else
        show_notification("SAVE FAILED", 2.0)
        print("ERROR: File not found: " .. path)
    end
end

-- Stop recording
function stop_recording()
    if not state.recording then
        return
    end

    state.recording = false
    local duration = state.recording_time
    
    -- Stop recording clock
    if state.recording_clock then
        clock.cancel(state.recording_clock)
        state.recording_clock = nil
    end

    -- Stop recording
    softcut.rec(1, 0)
    softcut.rec(2, 0)

    -- Stop engine input monitoring
    engine.stopInputMonitor()

    print("Recording stopped after " .. string.format("%.1f", duration) .. "s")
    show_notification("ANALYZING...", 1.0)

    -- Request accumulated levels from engine
    -- Response will come via /recording_levels OSC message
    engine.getRecordingLevels()
end

-- Handle filter cutoff CC
function handle_filter_cutoff(cutoff)
    state.master_filter_cutoff = cutoff
    engine.setMasterFilter(cutoff, state.master_filter_resonance, state.master_filter_type)
end

-- Handle filter resonance CC
function handle_filter_resonance(resonance)
    state.master_filter_resonance = resonance
    engine.setMasterFilter(state.master_filter_cutoff, resonance, state.master_filter_type)
end

-- Handle per-voice filter offset
function handle_voice_filter_offset(voice_idx, offset)
    engine.setVoiceFilterOffset(voice_idx, offset)
end

-- Update all active notes
function update_all_notes()
    for i = 0, state.num_faders - 1 do
        if state.faders[i].active then
            release_note(i)
            trigger_note(i)
        end
    end
end

-- Encoder input
function enc(n, delta)
    
    if n == 1 then
    -- Page navigation
    local old_page = state.current_page
    state.current_page = util.clamp(state.current_page + delta, 1, 10)
    
    -- Reset parameter selection when entering LFO page
    if state.current_page == 9 and old_page ~= 9 then
        state.lfo_selected_param = 1
        -- Also ensure lfo_selected is valid
        state.lfo_selected = util.clamp(state.lfo_selected, 1, state.lfo_count)
    end
    
    elseif state.current_page == 1 then
    -- PLAY page
    if n == 2 then
        if state.k1_held then
            -- K1+E2: Cycle filter type
            if delta ~= 0 then
                state.master_filter_type = (state.master_filter_type + (delta > 0 and 1 or -1)) % 3
                engine.setMasterFilter(
                    state.master_filter_cutoff,
                    state.master_filter_resonance,
                    state.master_filter_type
                )
            end
        else
            -- E2: Octave offset (existing code)
            if delta > 0 then
                if state.octave_mode == "normal" then
                    state.octave_offset = util.clamp(state.octave_offset + 1, -2, 2)
                else
                    if state.octave_offset >= 2 then
                        state.octave_mode = "normal"
                        state.octave_offset = -2
                    else
                        state.octave_offset = util.clamp(state.octave_offset + 1, -2, 2)
                    end
                end
            else
                if state.octave_offset <= -2 then
                    state.octave_mode = "random"
                    state.octave_offset = 0
                else
                    state.octave_offset = util.clamp(state.octave_offset - 1, -2, 2)
                end
            end
            update_all_notes()
        end
    elseif n == 3 then
        if state.k1_held then  -- Changed from k3_held
            state.master_filter_resonance = util.clamp(
                state.master_filter_resonance + (delta * 0.05),
                0, 1
            )
            engine.setMasterFilter(
                state.master_filter_cutoff,
                state.master_filter_resonance,
                state.master_filter_type
            )
        else
            state.master_filter_cutoff = util.clamp(
                state.master_filter_cutoff + (delta * 100),
                20, 20000
            )
            engine.setMasterFilter(
                state.master_filter_cutoff,
                state.master_filter_resonance,
                state.master_filter_type
            )
        end
    end
        
    elseif state.current_page == 2 then
    -- SAMPLE page
    if n == 2 then
        state.selected_param = util.wrap(state.selected_param + delta, 1, 7)  -- Changed from 5 to 6
    elseif n == 3 then
        if state.selected_param == 1 then
            -- Loop start (existing code)
            local margin = 0.02
            local current_end = calculate_loop_end()
            
            if current_end - state.loop_start < margin then
                local new_start = util.clamp(state.loop_start + (delta * 0.01), 0, 1 - margin)
                state.loop_start = new_start
            else
                local new_start = util.clamp(state.loop_start + (delta * 0.01), 0, 0.99)
                local max_length = (1.0 - new_start) * state.sample_duration
                state.loop_start = new_start
                state.loop_length = math.min(state.loop_length, max_length)
            end
            engine.setLoopPoints(state.loop_start, calculate_loop_end())
            
        elseif state.selected_param == 2 then
            -- Length with adaptive step size
            -- Use smaller steps (<1s) for fine control, larger steps (>1s) for speed
            local step_size = state.loop_length < 1.0 and 0.001 or 0.05
            local new_length = state.loop_length + (delta * step_size)
            local max_length = (1.0 - state.loop_start) * state.sample_duration
            state.loop_length = util.clamp(new_length, 0.001, max_length)
            engine.setLoopPoints(state.loop_start, calculate_loop_end())
            
        elseif state.selected_param == 3 then
            -- Speed (existing code)
            state.speed = util.clamp(state.speed + (delta * 0.05), 0.1, 2.0)
            engine.setSpeed(state.speed)
            
        elseif state.selected_param == 4 then
            -- Reverse (existing code)
            if delta ~= 0 then
                state.reverse = 1 - state.reverse
                engine.setReverse(state.reverse)
            end
            
        elseif state.selected_param == 5 then
            -- XFade (existing code)
            state.xfade_time = util.clamp(state.xfade_time + (delta * 0.01), 0.01, 0.5)
            engine.setXfadeTime(state.xfade_time)
            
        elseif state.selected_param == 6 then
            -- Gain (NEW)
            state.sample_gain = util.clamp(state.sample_gain + (delta * 0.05), 0.1, 2.0)
            -- Apply to all voices
            for i = 0, 7 do
                engine.setVoiceAmp(i, state.sample_gain)
            end
            
        elseif state.selected_param == 7 then
            -- Trigger Mode (NEW)
            if delta ~= 0 then
                state.trigger_mode = not state.trigger_mode
            end
        end
    end
        
    elseif state.current_page == 3 then
        -- SNAPSHOTS page
        if n == 2 then
            if state.k1_held then
                -- K1+E2: Browse snapshot packs
                state.snapshot_pack_selected = util.wrap(
                    state.snapshot_pack_selected + delta, 1, #SnapshotPacks.packs
                )
            else
                -- E2: Select snapshot slot
                state.snapshot_selected = util.wrap(state.snapshot_selected + delta, 1, 8)
            end
        end
        
    elseif state.current_page == 4 then
        -- SEQUENCER page
        if n == 2 then
            -- Determine number of params based on mode
            local num_params = 1  -- Just Mode for live
            if state.snapshot_player.mode == "live" then
                num_params = 1  -- Only Mode parameter in Live mode
            elseif state.snapshot_player.mode == "pattern" then
                num_params = 5  -- Mode, Add, BPM, Morph, Duration
            elseif state.snapshot_player.mode == "euclidean" then
                num_params = 7  -- Mode, Pulses, Steps, Rotation, BPM, Morph, Duration
            else
                num_params = 4  -- Basic params: Mode, BPM, Morph, Duration
            end
            state.selected_param = util.wrap(state.selected_param + delta, 1, num_params)
        elseif n == 3 then
            if state.selected_param == 1 then
                -- Mode cycling
                local modes = {"live","sequential", "random", "pattern", "euclidean"}
                local current_idx = 1
                for i, m in ipairs(modes) do
                    if m == state.snapshot_player.mode then
                        current_idx = i
                        break
                    end
                end
                local next_idx = ((current_idx - 1 + delta) % 4) + 1
                state.snapshot_player.mode = modes[next_idx]
                save_snapshots_to_disk()
                
            -- Pattern mode params
            elseif state.selected_param == 2 and state.snapshot_player.mode == "pattern" then
                -- Pattern edit value (which snapshot to add)
                state.snapshot_player.pattern_edit_value = util.wrap(
                    state.snapshot_player.pattern_edit_value + delta, 1, 8
                )
                
            -- Euclidean mode params
            elseif state.selected_param == 2 and state.snapshot_player.mode == "euclidean" then
                -- Pulses
                state.snapshot_player.euclidean_pulses = util.clamp(
                    state.snapshot_player.euclidean_pulses + delta, 1, 
                    state.snapshot_player.euclidean_steps
                )
                state.snapshot_player.euclidean_pattern = generate_euclidean_pattern(
                    state.snapshot_player.euclidean_pulses,
                    state.snapshot_player.euclidean_steps,
                    state.snapshot_player.euclidean_rotation
                )
                save_snapshots_to_disk()
                
            elseif state.selected_param == 3 and state.snapshot_player.mode == "euclidean" then
                -- Steps
                state.snapshot_player.euclidean_steps = util.clamp(
                    state.snapshot_player.euclidean_steps + delta, 
                    state.snapshot_player.euclidean_pulses, 32
                )
                state.snapshot_player.euclidean_pattern = generate_euclidean_pattern(
                    state.snapshot_player.euclidean_pulses,
                    state.snapshot_player.euclidean_steps,
                    state.snapshot_player.euclidean_rotation
                )
                save_snapshots_to_disk()
                
            elseif state.selected_param == 4 and state.snapshot_player.mode == "euclidean" then
                -- Rotation
                state.snapshot_player.euclidean_rotation = util.clamp(
                    state.snapshot_player.euclidean_rotation + delta, 0, 
                    state.snapshot_player.euclidean_steps - 1
                )
                state.snapshot_player.euclidean_pattern = generate_euclidean_pattern(
                    state.snapshot_player.euclidean_pulses,
                    state.snapshot_player.euclidean_steps,
                    state.snapshot_player.euclidean_rotation
                )
                save_snapshots_to_disk()
                
            -- Common params (BPM, Morph, Duration) - adjust param numbers based on mode
            elseif (state.snapshot_player.mode == "pattern" and state.selected_param == 3) or
                   (state.snapshot_player.mode == "euclidean" and state.selected_param == 5) or
                   (state.selected_param == 2 and state.snapshot_player.mode ~= "pattern" and state.snapshot_player.mode ~= "euclidean") then
                -- BPM
                state.snapshot_player.bpm = util.clamp(
                    state.snapshot_player.bpm + delta, 30, 200
                )
                save_snapshots_to_disk()
                
            elseif (state.snapshot_player.mode == "pattern" and state.selected_param == 4) or
                   (state.snapshot_player.mode == "euclidean" and state.selected_param == 6) or
                   (state.selected_param == 3 and state.snapshot_player.mode ~= "pattern" and state.snapshot_player.mode ~= "euclidean") then
                -- Morph time
                state.morphing.duration = util.clamp(
                    state.morphing.duration + (delta * 0.1), 0.1, 10.0
                )
                
            elseif (state.snapshot_player.mode == "pattern" and state.selected_param == 5) or
                   (state.snapshot_player.mode == "euclidean" and state.selected_param == 7) or
                   (state.selected_param == 4 and state.snapshot_player.mode ~= "pattern" and state.snapshot_player.mode ~= "euclidean") then
                -- Duration in beats
                state.snapshot_player.duration_beats = util.clamp(
                    state.snapshot_player.duration_beats + delta, 1, 16
                )
                save_snapshots_to_disk()
            end
        end
    
    elseif state.current_page == 5 then
        -- ENVELOPE page
        if n == 2 then
            state.selected_param = util.wrap(state.selected_param + delta, 1, 5)
        elseif n == 3 then
            if state.selected_param == 1 then
                state.env_attack = util.clamp(state.env_attack + (delta * 0.01), 0.001, 2.0)
            elseif state.selected_param == 2 then
                state.env_decay = util.clamp(state.env_decay + (delta * 0.01), 0.01, 2.0)
            elseif state.selected_param == 3 then
                state.env_sustain = util.clamp(state.env_sustain + (delta * 0.05), 0, 1.0)
            elseif state.selected_param == 4 then
                state.env_release = util.clamp(state.env_release + (delta * 0.05), 0.01, 5.0)
            elseif state.selected_param == 5 then
                state.env_filter_mod = util.clamp(state.env_filter_mod + (delta * 0.01), 0.0, 1.0)
                engine.setEnvFilterMod(state.env_filter_mod)
            end

            -- Update envelope for ADSR parameters
            if state.selected_param <= 4 then
                for i = 0, state.num_faders - 1 do
                    engine.setVoiceEnvelope(i, state.env_attack, state.env_decay, state.env_sustain, state.env_release)
                end
            end
        end
        
    elseif state.current_page == 6 then
        -- SCALE page
        if n == 2 then
            state.selected_param = util.wrap(state.selected_param + delta, 1, 3)
        elseif n == 3 then
            if state.selected_param == 1 then
                state.current_scale = ScaleSystem.get_next_scale(state.current_scale, delta)
                update_all_notes()
            elseif state.selected_param == 2 then
                state.root_note = util.clamp(state.root_note + delta, 36, 84)
                update_all_notes()
            elseif state.selected_param == 3 then
                state.octave_offset = util.clamp(state.octave_offset + delta, -2, 2)
                update_all_notes()
            end
        end

    elseif state.current_page == 7 then
        -- FX page (reverb)
        if n == 2 then
            state.selected_param = util.wrap(state.selected_param + delta, 1, 8)
        elseif n == 3 then
            if state.selected_param == 1 then
                -- Reverb Mix (1% increments)
                state.reverb_mix = util.clamp(state.reverb_mix + (delta * 0.01), 0.0, 1.0)
                engine.setReverbMix(state.reverb_mix)
            elseif state.selected_param == 2 then
                -- Reverb Time
                state.reverb_time = util.clamp(state.reverb_time + (delta * 0.1), 0.1, 10.0)
                engine.setReverbTime(state.reverb_time)
            elseif state.selected_param == 3 then
                -- Reverb Size
                state.reverb_size = util.clamp(state.reverb_size + (delta * 0.1), 0.5, 5.0)
                engine.setReverbSize(state.reverb_size)
            elseif state.selected_param == 4 then
                -- Reverb Damping (1% increments)
                state.reverb_damping = util.clamp(state.reverb_damping + (delta * 0.01), 0.0, 1.0)
                engine.setReverbDamping(state.reverb_damping)
            elseif state.selected_param == 5 then
                -- Reverb Feedback (1% increments)
                state.reverb_feedback = util.clamp(state.reverb_feedback + (delta * 0.01), 0.0, 1.0)
                engine.setReverbFeedback(state.reverb_feedback)
            elseif state.selected_param == 6 then
                -- Reverb Diffusion (1% increments)
                state.reverb_diff = util.clamp(state.reverb_diff + (delta * 0.01), 0.0, 1.0)
                engine.setReverbDiff(state.reverb_diff)
            elseif state.selected_param == 7 then
                -- Reverb Mod Depth (1% increments)
                state.reverb_mod_depth = util.clamp(state.reverb_mod_depth + (delta * 0.01), 0.0, 1.0)
                engine.setReverbModDepth(state.reverb_mod_depth)
            elseif state.selected_param == 8 then
                -- Reverb Mod Freq
                state.reverb_mod_freq = util.clamp(state.reverb_mod_freq + (delta * 0.1), 0.1, 10.0)
                engine.setReverbModFreq(state.reverb_mod_freq)
            end
        end

    elseif state.current_page == 8 then
        -- MIDI settings page
        if n == 2 then
            state.selected_param = util.wrap(state.selected_param + delta, 1, 2)
        elseif n == 3 then
            if state.selected_param == 1 then
                local new_channel = util.clamp(MidiHandler.midi_channel + delta, 1, 16)
                MidiHandler.set_midi_channel(new_channel)
            elseif state.selected_param == 2 then
                local new_cc = util.clamp(MidiHandler.fader_cc_start + delta, 0, 111)
                MidiHandler.set_fader_cc_start(new_cc)
            end
        end

    elseif state.current_page == 9 then
        -- LFO page
        if n == 2 then
            -- E2: Select parameter
            local max_params = 7
            local lfo = state.lfos[state.lfo_selected]
            local dest = state.lfo_destinations[lfo.destination]
            if dest.has_param then
                max_params = 8  -- Show dest param row
            end
            state.lfo_selected_param = util.wrap(state.lfo_selected_param + delta, 1, max_params)
        elseif n == 3 then
            -- E3: Edit parameter value
            local lfo = state.lfos[state.lfo_selected]
            
            if state.lfo_selected_param == 1 then
                -- LFO select
                state.lfo_selected = util.wrap(state.lfo_selected + delta, 1, state.lfo_count)
            elseif state.lfo_selected_param == 2 then
                -- Enabled
                if delta ~= 0 then
                    lfo.enabled = not lfo.enabled
                end
            elseif state.lfo_selected_param == 3 then
                -- Shape
                lfo.shape = util.wrap(lfo.shape + delta, 1, 5)
            elseif state.lfo_selected_param == 4 then
                -- Rate mode
                if delta ~= 0 then
                    lfo.rate_mode = (lfo.rate_mode % 2) + 1
                end
            elseif state.lfo_selected_param == 5 then
                -- Rate value
                if lfo.rate_mode == 1 then
                    -- Hz mode with adaptive resolution
                    local increment
                    if lfo.rate_hz < 0.1 then
                        increment = 0.001  -- Very fine for < 0.1 Hz
                    elseif lfo.rate_hz < 1.0 then
                        increment = 0.01   -- Fine for < 1 Hz
                    elseif lfo.rate_hz < 5.0 then
                        increment = 0.1    -- Medium for < 5 Hz
                    else
                        increment = 0.5    -- Coarser for > 5 Hz
                    end
                    lfo.rate_hz = util.clamp(lfo.rate_hz + (delta * increment), 0.001, 20.0)
                else
                    -- BPM-sync mode
                    lfo.rate_bpm_div = util.wrap(lfo.rate_bpm_div + delta, 1, #state.lfo_bpm_divisions)
                end
            elseif state.lfo_selected_param == 6 then
                -- Depth
                lfo.depth = util.clamp(lfo.depth + (delta * 5), -100, 100)
            elseif state.lfo_selected_param == 7 then
                -- Destination
                lfo.destination = util.wrap(lfo.destination + delta, 1, #state.lfo_destinations)
                -- Reset dest_param when changing destination
                local dest = state.lfo_destinations[lfo.destination]
                lfo.dest_param = dest.has_param and dest.param_min or 0
            elseif state.lfo_selected_param == 8 then
                -- Dest param (if applicable)
                local dest = state.lfo_destinations[lfo.destination]
                if dest.has_param then
                    lfo.dest_param = util.wrap(lfo.dest_param + delta, dest.param_min, dest.param_max)
                end
            end
        end

    elseif state.current_page == 10 then
        -- SCENES page
        if n == 2 then
            state.scene_selected = util.wrap(state.scene_selected + delta, 1, 8)
        end
    end
end

-- Key input
function key(n, z)
    if n == 1 then
        state.k1_held = (z == 1)
    end
    
    if z == 1 then
    if n == 2 then
        if state.current_page == 1 then
            -- PLAY page: K1+K2 zero all, K2 save snapshot
            if state.k1_held then
                -- Zero all faders (force reset)
                for i = 0, 7 do
                    if state.faders[i].active then
                        release_note(i)
                    end
                    state.faders[i].position = 0
                    engine.setFaderPos(i, 0)
                end
                
                -- Stop morphing if active
                if state.morphing.active then
                    state.morphing.active = false
                end
                
                -- Stop sequencer if playing
                if state.snapshot_player.playing then
                    stop_snapshot_sequencer()
                end
                
                show_notification("ALL ZEROED", 1.5)
            else
                save_snapshot()
            end
            elseif state.current_page == 2 then
                -- SAMPLE page: Browse or Cancel
                if state.recording then
                    cancel_recording()
                else
                    fileselect.enter(_path.audio, load_file_callback)
                    selecting = true
                end
            elseif state.current_page == 3 then
                -- SNAPSHOTS page: K1+K2 load pack, K2 jump
                if state.k1_held then
                    load_snapshot_pack(state.snapshot_pack_selected)
                else
                    jump_to_snapshot(state.snapshot_selected)
                end
            elseif state.current_page == 4 then 
                -- SEQUENCER page
                if state.snapshot_player.mode == "pattern" then
                    pattern_add_snapshot()
                elseif state.snapshot_player.mode == "euclidean" then
                    if state.snapshot_player.euclidean_rest_behavior == "hold" then
                        state.snapshot_player.euclidean_rest_behavior = "fade"
                    else
                        state.snapshot_player.euclidean_rest_behavior = "hold"
                    end
                    show_notification("REST: " .. string.upper(state.snapshot_player.euclidean_rest_behavior), 1.5)
                    save_snapshots_to_disk()
                end
            elseif state.current_page == 9 then
                -- LFO page
                local lfo = state.lfos[state.lfo_selected]

                if state.lfo_selected_param == 1 then
                    lfo.enabled = not lfo.enabled
                elseif state.lfo_selected_param == 2 then
                    lfo.shape = (lfo.shape % 4) + 1
                elseif state.lfo_selected_param == 3 then
                    lfo.rate_mode = (lfo.rate_mode % 2) + 1
                elseif state.lfo_selected_param == 6 then
                    lfo.destination = (lfo.destination % #state.lfo_destinations) + 1
                    lfo.dest_param = state.lfo_destinations[lfo.destination].has_param and 1 or 0
                elseif state.lfo_selected_param == 7 then
                    local dest = state.lfo_destinations[lfo.destination]
                    if dest.has_param then
                        lfo.dest_param = util.wrap(lfo.dest_param + 1, dest.param_min, dest.param_max)
                    end
                end
            elseif state.current_page == 10 then
                -- SCENES page: Save scene
                save_scene(state.scene_selected)
            end
            
        elseif n == 3 then
            if state.current_page == 1 then
                -- PLAY page: Start/stop sequencer
                if state.snapshot_player.mode == "live" then
                    show_notification("LIVE MODE ACTIVE", 1.5)  
                elseif state.snapshot_player.playing then
                    stop_snapshot_sequencer()
                else
                    start_snapshot_sequencer()
                end
            elseif state.current_page == 2 then
                -- SAMPLE page: Record or Stop
                if state.recording then
                    stop_recording()
                else
                    start_recording()
                end
            elseif state.current_page == 3 then
                -- SNAPSHOTS page: K1+K3 clear, K3 toggle enable
                if state.k1_held then
                    clear_snapshot(state.snapshot_selected)
                else
                    toggle_snapshot_enabled(state.snapshot_selected)
                end
            elseif state.current_page == 4 then
                -- SEQUENCER page
                if state.snapshot_player.mode == "live" then
                    show_notification("LIVE MODE", 1.5)
                elseif state.snapshot_player.mode == "pattern" then
                    if state.k1_held then
                        pattern_clear()
                    else
                        pattern_remove_last()
                    end
                else
                    if state.snapshot_player.playing then
                        stop_snapshot_sequencer()
                    else
                        start_snapshot_sequencer()
                    end
                end
            elseif state.current_page == 10 then
                -- SCENES page
                if state.k1_held then
                    clear_scene(state.scene_selected)
                else
                    load_scene(state.scene_selected)
                end
            end
        end
    end
end

-- Draw UI
function redraw()
    if selecting then
        return
    end

    screen.clear()

    screen.level(15)
    screen.move(64, 8)
    local pages = {"PLAY", "SAMPLE", "SNAPSHOTS", "SEQUENCER", "ENVELOPE", "SCALE", "FX", "MIDI", "LFO", "SCENES"}
    screen.text_center(pages[state.current_page])

    if state.current_page == 1 then
        draw_play_page()
    elseif state.current_page == 2 then
        draw_sample_page()
    elseif state.current_page == 3 then
        draw_snapshots_page()
    elseif state.current_page == 4 then
        draw_sequencer_page()
    elseif state.current_page == 5 then
        draw_envelope_page()
    elseif state.current_page == 6 then
        draw_scale_page()
    elseif state.current_page == 7 then
        draw_fx_page()
    elseif state.current_page == 8 then
        draw_midi_page()
    elseif state.current_page == 9 then
        draw_lfo_page()
    elseif state.current_page == 10 then
        draw_scenes_page()
    end

    screen.update()
end

function draw_play_page()
    local fader_width = 12
    local fader_spacing = 15
    local fader_height = 35
    local start_x = 8
    local start_y = 20
    
    for i = 0, state.num_faders - 1 do
        local fader = state.faders[i]
        local x = start_x + (i * fader_spacing)
        
        screen.level(2)
        screen.rect(x, start_y, fader_width, fader_height)
        screen.stroke()
        
        local level = fader.active and 15 or 6
        screen.level(level)
        local pos_height = fader.position * fader_height
        screen.rect(x, start_y + (fader_height - pos_height), fader_width, pos_height)
        screen.fill()
    end
    
    screen.level(8)
    screen.move(4, 15)
    local oct_display = state.octave_mode == "random" and "R" or state.octave_offset
    if state.k1_held then
        -- Show filter type when K1 held
        local filter_types = {"LP", "HP", "BP"}
        screen.text("Filt: " .. filter_types[state.master_filter_type + 1])
    else
        screen.text("Oct: " .. oct_display)
    end
    
    local cutoff_display = state.master_filter_cutoff
    local filter_text
    if cutoff_display >= 1000 then
        filter_text = "F: " .. string.format("%.1fk", cutoff_display / 1000)
    else
        filter_text = "F: " .. math.floor(cutoff_display)
    end
    
    -- Add filter type indicator to the right side display
    local filter_types = {"LP", "HP", "BP"}
    filter_text = filter_text .. " Q: " .. string.format("%.2f", state.master_filter_resonance) 
        .. " " .. filter_types[state.master_filter_type + 1]
    
    screen.move(128, 15)
    screen.text_right(filter_text)
    
    screen.level(10)
    screen.move(4, 64)
    screen.text(state.current_scale .. " " .. ScaleSystem.get_root_name(state.root_note))
    
    -- Show morph progress in bottom right
    if state.morphing.active then
        screen.level(15)
        screen.move(128, 56)
        if state.snapshot_current == 0 then
            screen.text_right("→REST")
        else
            screen.text_right("→" .. state.snapshot_current)
        end
        
        -- Small progress bar
        local bar_width = 20
        local bar_x = 128 - bar_width
        local bar_y = 59
        screen.level(4)
        screen.rect(bar_x, bar_y, bar_width, 2)
        screen.stroke()
        screen.level(15)
        screen.rect(bar_x, bar_y, bar_width * state.morphing.progress, 2)
        screen.fill()
    end
    
    -- Show key legend in bottom right
    screen.level(6)
    screen.move(128, 64)
    if state.k1_held then
        screen.text_right("K2:ZERO")
    else
        screen.text_right(state.snapshot_player.playing and "K2:● K3:⏸" or "K2:● K3:▶")
    end
    
    -- Show notification as centered card
    if notification.active then
        local card_width = 100
        local card_height = 20
        local card_x = 64 - (card_width / 2)
        local card_y = 32 - (card_height / 2)
        
        -- Draw filled background (opaque)
        screen.level(0)
        screen.rect(card_x, card_y, card_width, card_height)
        screen.fill()
        
        -- Draw border
        screen.level(15)
        screen.rect(card_x, card_y, card_width, card_height)
        screen.stroke()
        
        -- Draw centered text
        screen.level(15)
        screen.move(64, 32 + 3)  -- +3 for vertical centering
        screen.text_center(notification.message)
    end

    
end

function draw_sample_page()
    if not state.recording then
        -- Only show filename when NOT recording
        screen.level(10)
        screen.move(4, 15)
        screen.text("Sample:")
        
        screen.level(15)
        screen.move(4, 23)
        local filename = string.match(state.sample_path, "([^/]+)$")
        if filename then
            screen.text(util.trim_string_to_width(filename, 120))
        else
            screen.level(6)
            screen.text("K2: Load / K3: Record")
        end
    end
    
    if state.recording then
        -- Calculate current time on every draw for smooth display
        local current_time = util.time() - state.recording_start_time
        
        screen.level(15)
        screen.move(64, 20)
        screen.text_center("RECORDING")
        screen.move(64, 30)
        screen.text_center(string.format("%.1fs / 30s", current_time))
        
        -- Time progress bar
        screen.level(4)
        screen.rect(20, 36, 88, 3)
        screen.stroke()
        screen.level(15)
        screen.rect(20, 36, 88 * (current_time / 30), 3)
        screen.fill()
        
        -- Level meters (L and R) - two lines, full width
        screen.level(10)
        screen.move(4, 48)
        screen.text("L")
        screen.move(4, 56)
        screen.text("R")
        
        local meter_x = 12
        local meter_width = 100
        
        -- Left channel meter
        local l_level = state.recording_level_l
        screen.level(l_level > 0.9 and 15 or 10)
        screen.rect(meter_x, 44, meter_width * l_level, 3)
        screen.fill()
        
        -- Right channel meter
        local r_level = state.recording_level_r
        screen.level(r_level > 0.9 and 15 or 10)
        screen.rect(meter_x, 52, meter_width * r_level, 3)
        screen.fill()
        
        -- Clip indicators
        if l_level > 0.9 then
            screen.level(15)
            screen.move(meter_x + meter_width + 4, 48)
            screen.text("!")
        end
        if r_level > 0.9 then
            screen.level(15)
            screen.move(meter_x + meter_width + 4, 56)
            screen.text("!")
        end
        
        -- Key legend - centered at bottom
        screen.level(6)
        screen.move(64, 64)
        screen.text_center("K2:Cancel  K3:Stop")
        
    else
        if #state.waveform > 0 then
            local wf_x = 4
            local wf_y = 26
            local wf_width = 120
            local wf_height = 16
            
            screen.level(4)
            for i = 1, #state.waveform do
                local x = wf_x + ((i - 1) / #state.waveform) * wf_width
                local h = state.waveform[i] * wf_height
                screen.move(x, wf_y + wf_height/2)
                screen.line(x, wf_y + wf_height/2 - h/2)
                screen.line(x, wf_y + wf_height/2 + h/2)
                screen.stroke()
            end
            
            local start_x = wf_x + (state.loop_start * wf_width)
            local end_x = wf_x + (calculate_loop_end() * wf_width)
            
            screen.level(15)
            screen.move(start_x, wf_y)
            screen.line(start_x, wf_y + wf_height)
            screen.stroke()
            
            screen.level(15)
            screen.move(end_x, wf_y)
            screen.line(end_x, wf_y + wf_height)
            screen.stroke()
        end
        
        local params = {"Start", "Length", "Speed", "Rev", "XFade", "Gain", "Mode"}  -- Added Mode
        local param_start_y = 46
        local param_spacing = 7
        local visible_params = 2
        
        local scroll_offset = 0
        if state.selected_param > visible_params then
            scroll_offset = -(state.selected_param - visible_params) * param_spacing
        end
        
        for i = 1, 7 do
            local y = param_start_y + (i * param_spacing) + scroll_offset
            
            if y > 44 and y < 64 then
                screen.level(state.selected_param == i and 15 or 6)
                screen.move(4, y)
                screen.text(params[i] .. ":")
                
                screen.move(50, y)
                if i == 1 then
                    local start_time = state.loop_start * state.sample_duration
                    if start_time >= 1.0 then
                        screen.text(string.format("%.2fs", start_time))
                    else
                        screen.text(string.format("%dms", math.floor(start_time * 1000)))
                    end
                elseif i == 2 then
                    if state.loop_length >= 1.0 then
                        screen.text(string.format("%.2fs", state.loop_length))
                    else
                        screen.text(string.format("%dms", math.floor(state.loop_length * 1000)))
                    end
                elseif i == 3 then
                    screen.text(string.format("%.2fx", state.speed))
                elseif i == 4 then
                    screen.text(state.reverse == 1 and "ON" or "OFF")
                elseif i == 5 then
                    screen.text(string.format("%dms", math.floor(state.xfade_time * 1000)))
                elseif i == 6 then
                    local gain_db = 20 * math.log(state.sample_gain, 10)
                    screen.text(string.format("%.1fdB", gain_db))
                elseif i == 7 then
                    screen.text(state.trigger_mode and "TRIG" or "GATE")
                end
            end
        end
        
        if state.selected_param > visible_params then
            screen.level(4)
            screen.move(124, 60)
            screen.text("▼")
        end
        if state.selected_param > 1 then
            screen.level(4)
            screen.move(124, 48)
            screen.text("▲")
        end
    end
end

function draw_snapshots_page()
    screen.level(10)
    
    -- Show pack browser if K1 held
    if state.k1_held then
        local pack = SnapshotPacks.packs[state.snapshot_pack_selected]

        screen.level(15)
        screen.move(64, 20)
        screen.text_center("PACK " .. state.snapshot_pack_selected .. "/" .. #SnapshotPacks.packs)
        
        screen.level(12)
        screen.move(64, 30)
        screen.text_center(pack.name)
        
        screen.level(8)
        screen.move(64, 40)
        screen.text_center(pack.description)
        
        -- Show chord names
        screen.level(6)
        for i = 1, math.min(4, #pack.chords) do
            screen.move(4, 46 + (i * 7))
            screen.text(i .. ":" .. pack.chords[i].name)
        end
        for i = 5, math.min(8, #pack.chords) do
            screen.move(68, 25 + (i * 7))
            screen.text(i .. ":" .. pack.chords[i].name)
        end
        
        -- Instructions
        screen.level(10)
        screen.move(64, 64)
        screen.text_center("K2:LOAD")
        
        return
    end
    
    -- Draw all 8 snapshots (4x2 grid layout)
    for i = 1, 8 do
        local snap = state.snapshots[i]
        local is_current = (i == state.snapshot_current and state.snapshot_current > 0)
        local is_selected = (i == state.snapshot_selected)
        
        -- Calculate position (2 columns, 4 rows)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        local x = 4 + (col * 64)
        local y = 15 + (row * 12)
        
        -- Draw snapshot number
        screen.level(is_selected and 15 or 8)
        screen.move(x, y)
        screen.text(i .. ":")
        
        -- Draw mini fader visualization
        if not snap.empty then
            local bar_x = x + 12
            local bar_height = 6
            
            for f = 0, 7 do
                local pos = snap.positions[f] or 0
                local fx = bar_x + (f * 5)
                
                -- Background
                screen.level(2)
                screen.rect(fx, y - 5, 4, bar_height)
                screen.stroke()
                
                -- Filled portion - brighter if enabled, dim if disabled
                local fill_height = pos * bar_height
                screen.level(snap.enabled and 10 or 4)
                screen.rect(fx, y - 5 + (bar_height - fill_height), 4, fill_height)
                screen.fill()
            end
            
            -- Current indicator
            if is_current then
                screen.level(15)
                screen.move(bar_x + 42, y)
                screen.text("*")
            end
        else
            screen.level(4)
            screen.move(x + 12, y)
            screen.text("---")
        end
    end
    
    -- Instructions at bottom
    screen.level(6)
    screen.move(4, 64)
    screen.text("K2:Jump  K3:En/Dis  K1+K3:Del")
end

function draw_sequencer_page()
    -- Status on same line as title
    screen.level(state.snapshot_player.playing and 15 or 6)
    screen.move(128, 8)
    screen.text_right(state.snapshot_player.playing and "K3:⏸" or "K3:▶")    
    screen.level(10)
    
    local y_offset = 18
    local line_height = 8
    local visible_lines = 4  -- How many parameter lines fit on screen (corrected)
    local scroll_offset = 0
    
    -- Calculate scroll offset to keep selected param visible
    if state.selected_param > visible_lines then
        scroll_offset = -(state.selected_param - visible_lines) * line_height
    end
    
    local current_line = 1
    local draw_y = y_offset + (current_line * line_height) + scroll_offset
    
    -- Mode (always param 1)
    if draw_y > 15 and draw_y < 60 then
        screen.level(state.selected_param == 1 and 15 or 6)
        screen.move(4, draw_y)
        local mode_names = {live = "Live", sequential = "Sequential", random = "Random", pattern = "Pattern", euclidean = "Euclidean"}
        screen.text("Mode: " .. mode_names[state.snapshot_player.mode])
    end
    current_line = current_line + 1
    
    -- Mode-specific params
    if state.snapshot_player.mode == "pattern" then
        -- Pattern edit (param 2)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == 2 and 15 or 6)
            screen.move(4, draw_y)
            screen.text("Add: " .. state.snapshot_player.pattern_edit_value)
        end
        current_line = current_line + 1
        
        -- Pattern display (non-selectable, don't count in current_line for params)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(8)
            screen.move(4, draw_y)
            if #state.snapshot_player.pattern > 0 then
                local pattern_str = ""
                for i, snap_idx in ipairs(state.snapshot_player.pattern) do
                    if i == state.snapshot_player.pattern_position and state.snapshot_player.playing then
                        pattern_str = pattern_str .. "[" .. snap_idx .. "]"
                    else
                        pattern_str = pattern_str .. snap_idx
                    end
                    if i < #state.snapshot_player.pattern then
                        pattern_str = pattern_str .. "-"
                    end
                end
                screen.text(util.trim_string_to_width(pattern_str, 120))
            else
                screen.level(4)
                screen.text("Pattern: (empty)")
            end
        end
        current_line = current_line + 1
        
    elseif state.snapshot_player.mode == "euclidean" then
        -- Pulses (param 2)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == 2 and 15 or 6)
            screen.move(4, draw_y)
            screen.text("Pulses: " .. state.snapshot_player.euclidean_pulses)
        end
        current_line = current_line + 1
        
        -- Steps (param 3)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == 3 and 15 or 6)
            screen.move(4, draw_y)
            screen.text("Steps: " .. state.snapshot_player.euclidean_steps)
        end
        current_line = current_line + 1
        
        -- Rotation (param 4)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == 4 and 15 or 6)
            screen.move(4, draw_y)
            screen.text("Rotate: " .. state.snapshot_player.euclidean_rotation)
        end
        current_line = current_line + 1
        
        -- Rest behavior (non-selectable)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(8)
            screen.move(4, draw_y)
            screen.text("Rest: " .. string.upper(state.snapshot_player.euclidean_rest_behavior) .. " (K2)")
        end
        current_line = current_line + 1
        
        -- Visual pattern (non-selectable)
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if #state.snapshot_player.euclidean_pattern > 0 and draw_y > 15 and draw_y < 60 then
            screen.level(8)
            screen.move(4, draw_y)
            local viz = ""
            for i, is_pulse in ipairs(state.snapshot_player.euclidean_pattern) do
                if i == state.snapshot_player.euclidean_position and state.snapshot_player.playing then
                    viz = viz .. (is_pulse and "[X]" or "[·]")
                else
                    viz = viz .. (is_pulse and "X" or "·")
                end
            end
            screen.text(util.trim_string_to_width(viz, 120))
        end
        current_line = current_line + 1
    end
    
    -- Common params (BPM, Morph, Duration) - only show if not in Live mode
    if state.snapshot_player.mode ~= "live" then
        local bpm_param = (state.snapshot_player.mode == "pattern" and 3) or 
                          (state.snapshot_player.mode == "euclidean" and 5) or 2
        local morph_param = (state.snapshot_player.mode == "pattern" and 4) or 
                            (state.snapshot_player.mode == "euclidean" and 6) or 3
        local duration_param = (state.snapshot_player.mode == "pattern" and 5) or 
                               (state.snapshot_player.mode == "euclidean" and 7) or 4
        
        -- BPM
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == bpm_param and 15 or 6)
            screen.move(4, draw_y)
            screen.text("BPM: " .. state.snapshot_player.bpm)
        end
        current_line = current_line + 1
        
        -- Morph
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == morph_param and 15 or 6)
            screen.move(4, draw_y)
            screen.text("Morph: " .. string.format("%.1fs", state.morphing.duration))
        end
        current_line = current_line + 1
        
        -- Duration
        draw_y = y_offset + (current_line * line_height) + scroll_offset
        if draw_y > 15 and draw_y < 60 then
            screen.level(state.selected_param == duration_param and 15 or 6)
            screen.move(4, draw_y)
            screen.text("Duration: " .. state.snapshot_player.duration_beats .. " beats")
        end
    end
    
    -- Scroll indicators
    if state.selected_param > visible_lines then
        screen.level(4)
        screen.move(124, 54)
        screen.text("▼")
    end
    if state.selected_param > 1 then
        screen.level(4)
        screen.move(124, 20)
        screen.text("▲")
    end
    
end

function draw_envelope_page()
    -- Draw envelope visualization (adjusted height to make room for 5th param)
    local env_x = 14
    local env_y = 45
    local env_width = 100
    local env_height = -25

    local total_time = state.env_attack + state.env_decay + 0.2 + state.env_release
    local a_width = (state.env_attack / total_time) * env_width
    local d_width = (state.env_decay / total_time) * env_width
    local s_width = (0.2 / total_time) * env_width
    local r_width = (state.env_release / total_time) * env_width

    screen.level(10)
    screen.move(env_x, env_y)
    screen.line(env_x + a_width, env_y + env_height)
    screen.line(env_x + a_width + d_width, env_y + (env_height * state.env_sustain))
    screen.line(env_x + a_width + d_width + s_width, env_y + (env_height * state.env_sustain))
    screen.line(env_x + a_width + d_width + s_width + r_width, env_y)
    screen.stroke()

    -- Draw ADSR parameters horizontally
    local params = {
        {label = "A", value = string.format("%.2fs", state.env_attack), x = 0},
        {label = "D", value = string.format("%.2fs", state.env_decay), x = 32},
        {label = "S", value = string.format("%.2f", state.env_sustain), x = 64},
        {label = "R", value = string.format("%.2fs", state.env_release), x = 94}
    }

    for i = 1, 4 do
        local param = params[i]
        local is_selected = (state.selected_param == i)

        screen.level(is_selected and 15 or 8)
        screen.move(param.x, 55)
        screen.text(param.label .. ": " .. param.value)

        -- Draw selection indicator (underline)
        if is_selected then
            screen.level(15)
            local text_width = #(param.label .. ": " .. param.value) * 4
            screen.move(param.x, 57)
            screen.line(param.x + text_width, 57)
            screen.stroke()
        end
    end

    -- Draw filter modulation parameter below ADSR
    local filter_mod_percent = math.floor(state.env_filter_mod * 100)
    local is_selected = (state.selected_param == 5)

    screen.level(is_selected and 15 or 8)
    screen.move(0, 63)
    screen.text("Filter Mod: " .. filter_mod_percent .. "%")

    if is_selected then
        screen.level(15)
        local text_width = #("Filter Mod: " .. filter_mod_percent .. "%") * 4
        screen.move(0, 65)
        screen.line(text_width, 65)
        screen.stroke()
    end
end

function draw_fx_page()
    -- Title
    screen.level(15)
    screen.move(4, 12)
    screen.text("REVERB")

    -- Dividing line
    screen.level(4)
    screen.move(4, 14)
    screen.line(124, 14)
    screen.stroke()

    -- Draw parameters with scrolling
    local params = {"Mix", "Time", "Size", "Damping", "Feedback", "Diffusion", "Mod Depth", "Mod Freq"}
    local param_start_y = 22
    local param_spacing = 7
    local visible_params = 5

    local scroll_offset = 0
    if state.selected_param > visible_params then
        scroll_offset = -(state.selected_param - visible_params) * param_spacing
    end

    for i = 1, 8 do
        local y = param_start_y + (i * param_spacing) + scroll_offset

        if y > 16 and y < 64 then
            screen.level(state.selected_param == i and 15 or 6)
            screen.move(4, y)
            screen.text(params[i] .. ":")

            screen.move(70, y)
            if i == 1 then
                screen.text(string.format("%d%%", math.floor(state.reverb_mix * 100)))
            elseif i == 2 then
                screen.text(string.format("%.1fs", state.reverb_time))
            elseif i == 3 then
                screen.text(string.format("%.1f", state.reverb_size))
            elseif i == 4 then
                screen.text(string.format("%d%%", math.floor(state.reverb_damping * 100)))
            elseif i == 5 then
                screen.text(string.format("%d%%", math.floor(state.reverb_feedback * 100)))
            elseif i == 6 then
                screen.text(string.format("%d%%", math.floor(state.reverb_diff * 100)))
            elseif i == 7 then
                screen.text(string.format("%d%%", math.floor(state.reverb_mod_depth * 100)))
            elseif i == 8 then
                screen.text(string.format("%.1fHz", state.reverb_mod_freq))
            end
        end
    end
end

function draw_scale_page()
    screen.level(10)
    
    local params = {"Scale", "Root", "Octave"}
    for i = 1, 3 do
        local y = 20 + (i * 10)
        screen.level(state.selected_param == i and 15 or 6)
        screen.move(4, y)
        screen.text(params[i] .. ":")
        
        screen.move(60, y)
        if i == 1 then
            screen.text(state.current_scale)
        elseif i == 2 then
            screen.text(ScaleSystem.get_root_name(state.root_note))
        elseif i == 3 then
            screen.text(state.octave_offset >= 0 and "+" .. state.octave_offset or tostring(state.octave_offset))
        end
    end
end

function draw_midi_page()
    screen.level(10)
    
    local params = {"MIDI Ch", "Fader CC"}
    for i = 1, 2 do
        local y = 20 + (i * 10)
        screen.level(state.selected_param == i and 15 or 6)
        screen.move(4, y)
        screen.text(params[i] .. ":")
        
        screen.move(80, y)
        if i == 1 then
            screen.text(MidiHandler.midi_channel)
        elseif i == 2 then
            screen.text(MidiHandler.fader_cc_start .. "-" .. (MidiHandler.fader_cc_start + 7))
        end
    end
end

function draw_lfo_page()
    local lfo = state.lfos[state.lfo_selected]
    local dest = state.lfo_destinations[lfo.destination]
    
    screen.level(10)
    
    -- Parameter list
    local params = {
        "LFO",
        "Enabled",
        "Shape",
        "Rate Mode",
        "Rate",
        "Depth",
        "Destination"
    }
    
    -- Add dest param if applicable
    if dest.has_param then
        table.insert(params, dest.param_name)
    end
    
    local y_start = 15
    local y_spacing = 7
    local visible_lines = 5
    local scroll_offset = 0
    
    -- Calculate scroll offset
    if state.lfo_selected_param > visible_lines then
        scroll_offset = -(state.lfo_selected_param - visible_lines)
    end
    
    for i = 1, #params do
        local y = y_start + ((i + scroll_offset) * y_spacing)
        
        if y > 10 and y < 58 then
            screen.level(state.lfo_selected_param == i and 15 or 6)
            screen.move(4, y)
            screen.text(params[i] .. ":")
            
            screen.move(70, y)
            if i == 1 then
                screen.text(state.lfo_selected)
            elseif i == 2 then
                screen.text(lfo.enabled and "ON" or "OFF")
            elseif i == 3 then
                screen.text(state.lfo_shape_names[lfo.shape])
            elseif i == 4 then
                screen.text(lfo.rate_mode == 1 and "Hz" or "BPM")
            elseif i == 5 then
                if lfo.rate_mode == 1 then
                    screen.text(string.format("%.2f Hz", lfo.rate_hz))
                else
                    screen.text(state.lfo_bpm_divisions[lfo.rate_bpm_div].name)
                end
            elseif i == 6 then
                screen.text(string.format("%+d%%", lfo.depth))
            elseif i == 7 then
                screen.text(dest.name)
            elseif i == 8 and dest.has_param then
                screen.text(lfo.dest_param)
            end
        end
    end
    
    -- Scroll indicators
    if state.lfo_selected_param > visible_lines then
        screen.level(4)
        screen.move(124, 54)
        screen.text("▼")
    end
    if state.lfo_selected_param > 1 then
        screen.level(4)
        screen.move(124, 16)
        screen.text("▲")
    end
    
    -- Show LFO value indicator if enabled
    if lfo.enabled then
        screen.level(15)
        screen.move(4, 64)
        screen.text("Value:")
        
        -- Visual bar
        local bar_x = 35
        local bar_y = 60
        local bar_width = 90
        local bar_height = 4
        
        -- Background (full width)
        screen.level(4)
        screen.rect(bar_x, bar_y, bar_width, bar_height)
        screen.stroke()
        
        -- Calculate scaled value based on depth
        local depth_scale = math.abs(lfo.depth) / 100.0
        local scaled_value = lfo.value * depth_scale
        
        -- Current value indicator (scaled by depth)
        local value_x = bar_x + ((scaled_value + 1) / 2) * bar_width
        screen.level(15)
        screen.move(value_x, bar_y)
        screen.line(value_x, bar_y + bar_height)
        screen.stroke()
        
        -- Center line
        screen.level(6)
        local center_x = bar_x + (bar_width / 2)
        screen.move(center_x, bar_y)
        screen.line(center_x, bar_y + bar_height)
        screen.stroke()
    end
end

function draw_scenes_page()
    screen.level(10)
    
    local visible_lines = 6
    local scroll_offset = 0
    
    -- Calculate scroll offset
    if state.scene_selected > visible_lines then
        scroll_offset = -(state.scene_selected - visible_lines)
    end
    
    for i = 1, 8 do
        local scene = state.scenes[i]
        local y = 15 + ((i + scroll_offset) * 8)
        
        if y > 10 and y < 58 then
            screen.level(state.scene_selected == i and 15 or 6)
            screen.move(4, y)
            
            -- Check if scene exists and is not empty
            if not scene or scene.empty then
                screen.text(i .. ": ---")
            else
                -- Format: "1: Major C  sample.wav"
                -- Use default values if fields are missing (for backwards compatibility)
                local scale = scene.current_scale or "Major"
                local root = scene.root_note or 60
                local scale_text = scale .. " " .. ScaleSystem.get_root_name(root)
                
                local sample_path = scene.sample_path or ""
                local filename = string.match(sample_path, "([^/]+)$") or "no sample"
                
                -- Truncate filename if needed
                local max_file_len = 20
                if #filename > max_file_len then
                    filename = string.sub(filename, 1, max_file_len - 3) .. "..."
                end
                
                screen.text(i .. ": " .. scale_text .. "  " .. filename)
            end
        end
    end
    
    -- Scroll indicators
    if state.scene_selected > visible_lines then
        screen.level(4)
        screen.move(124, 54)
        screen.text("▼")
    end
    if state.scene_selected > 1 then
        screen.level(4)
        screen.move(124, 16)
        screen.text("▲")
    end
    
    -- Instructions at bottom
    screen.level(6)
    screen.move(64, 64)
    screen.text_center("K2:Save  K3:Load  K1+K3:Clear")
end

function cleanup()
    MidiHandler.cleanup()
    save_snapshots_to_disk()
    save_scenes_to_disk()
end
