-- lib/midi_handler.lua
-- MIDI input processing and management

local MidiHandler = {}

MidiHandler.devices = {}
MidiHandler.midi_channel = 1
MidiHandler.fader_cc_start = 0  -- CC 0-7 for 8 faders by default
MidiHandler.num_faders = 8

-- CC assignments for filter control
MidiHandler.master_filter_cutoff_cc = 16
MidiHandler.master_filter_res_cc = 17
MidiHandler.voice_filter_offset_cc_start = 20  -- CC 20-27 for 8 voices

-- Callback functions (set by main script)
MidiHandler.on_fader = nil
MidiHandler.on_filter_cutoff = nil
MidiHandler.on_filter_resonance = nil
MidiHandler.on_voice_filter_offset = nil
MidiHandler.on_note_on = nil
MidiHandler.on_note_off = nil

function MidiHandler.init()
    -- Connect to all MIDI devices
    for i = 1, 16 do
        MidiHandler.devices[i] = midi.connect(i)
        MidiHandler.devices[i].event = function(data)
            MidiHandler.process_midi(data)
        end
    end
    
    -- Report connected devices
    for i = 1, 16 do
        if MidiHandler.devices[i].name ~= "none" then
            print("MIDI device " .. i .. ": " .. MidiHandler.devices[i].name)
        end
    end
end

function MidiHandler.process_midi(data)
    local msg = midi.to_msg(data)

    -- Only process messages on our channel
    if msg.ch ~= MidiHandler.midi_channel then
        return
    end

    if msg.type == "cc" then
        MidiHandler.process_cc(msg.cc, msg.val)
    elseif msg.type == "note_on" then
        if MidiHandler.on_note_on then
            MidiHandler.on_note_on(msg.note, msg.vel)
        end
    elseif msg.type == "note_off" then
        if MidiHandler.on_note_off then
            MidiHandler.on_note_off(msg.note, msg.vel)
        end
    end
end

function MidiHandler.process_cc(cc_num, cc_val)
    -- Check if this is a fader CC
    if cc_num >= MidiHandler.fader_cc_start and 
       cc_num < (MidiHandler.fader_cc_start + MidiHandler.num_faders) then
        local fader_idx = cc_num - MidiHandler.fader_cc_start
        local position = cc_val / 127.0
        
        if MidiHandler.on_fader then
            MidiHandler.on_fader(fader_idx, position)
        end
        
    -- Check if this is master filter cutoff
    elseif cc_num == MidiHandler.master_filter_cutoff_cc then
        local cutoff = util.linlin(0, 127, 20, 20000, cc_val)
        if MidiHandler.on_filter_cutoff then
            MidiHandler.on_filter_cutoff(cutoff)
        end
        
    -- Check if this is master filter resonance
    elseif cc_num == MidiHandler.master_filter_res_cc then
        local resonance = cc_val / 127.0
        if MidiHandler.on_filter_resonance then
            MidiHandler.on_filter_resonance(resonance)
        end
        
    -- Check if this is a voice filter offset CC
    elseif cc_num >= MidiHandler.voice_filter_offset_cc_start and
           cc_num < (MidiHandler.voice_filter_offset_cc_start + MidiHandler.num_faders) then
        local voice_idx = cc_num - MidiHandler.voice_filter_offset_cc_start
        -- Map CC to +/- 5000 Hz offset
        local offset = util.linlin(0, 127, -5000, 5000, cc_val)
        
        if MidiHandler.on_voice_filter_offset then
            MidiHandler.on_voice_filter_offset(voice_idx, offset)
        end
    end
end

function MidiHandler.set_midi_channel(channel)
    MidiHandler.midi_channel = util.clamp(channel, 1, 16)
end

function MidiHandler.set_fader_cc_start(cc_start)
    MidiHandler.fader_cc_start = util.clamp(cc_start, 0, 119)
end

function MidiHandler.set_num_faders(num)
    MidiHandler.num_faders = util.clamp(num, 1, 16)
end

function MidiHandler.cleanup()
    -- MIDI devices are automatically cleaned up by Norns
end

return MidiHandler
