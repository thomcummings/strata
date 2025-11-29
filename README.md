# strata

A sophisticated 8-voice sampler for monome norns, inspired by the Vestax Faderboard.

## Overview

strata transforms norns into a performance sampler controlled by MIDI faders or the built-in encoders. Play samples chromatically across scales, morph between chord voicings, sequence harmonies, and shape sound with extensive modulation.

## Features

### Core Playback
- **8-voice polyphonic sampling** with individual ADSR envelopes
- **Scale-aware** - Major, Minor, Dorian, Phrygian, Lydian, Mixolydian, Locrian, Chromatic
- **Two trigger modes**: Gate (continuous envelope control) or Trigger (retrigger on each crossing)
- **Sample manipulation**: loop points, speed, reverse, crossfade time, gain
- **Master filter**: LP/HP/BP with cutoff, resonance, and envelope modulation
- **Recording**: 30-second stereo recording with waveform display

### Performance Tools
- **Snapshots** (8 slots): Save and recall fader positions instantly
- **Snapshot Sequencer**: Morph between snapshots with multiple modes:
  - Sequential, Random, Pattern (up to 16 steps), Euclidean rhythms, Live (safe performance mode)
  - Adjustable BPM, morph time, and duration
- **Snapshot Packs** (10 built-in): Load complete harmonic palettes instantly
  - Basic Triads, I-IV-V Simple, Jazz 7ths, Minor Harmony
  - Ambient Spread, Pentatonic Clusters, Suspended Dream, Open Fifths
  - Add9 Shimmer, Whole Tone Dream

### Modulation
- **3 LFO engines** with multiple shapes (Sine, Triangle, Square, Random)
- **Rate modes**: Hz or BPM-sync
- **12 modulation destinations**: Individual faders, filter, sample parameters, envelope, octave
- **Per-destination parameter selection** where applicable

### Organization
- **Scenes** (8 slots): Save/load complete instrument states including snapshots, sample, scale, all settings
- **Built-in sample browser**
- **Persistent storage** of snapshots and scenes

## Installation
;install https://github.com/thomcummings/strata

Requires SuperCollider engine (included).

## Quick Start

1. **Load a sample**: Navigate to SAMPLE page, press K2
2. **Choose a scale**: SCALE page → set scale type and root note
3. **Play**: Use MIDI faders (CC 34-41, channel 1 by default) or control via norns
4. **Save snapshot**: PLAY page → K2 saves current fader positions
5. **Load chord pack**: SNAPSHOTS page → K1+E2 browse, K1+K2 load
6. **Sequence**: SEQUENCER page → set mode/BPM, K3 to start

## Pages Overview

### PLAY (Page 1)
Main performance view with fader visualization.
- E2: Octave offset / K1+E2: Filter type (LP/HP/BP)
- E3: Filter cutoff / K1+E3: Filter resonance  
- K2: Save snapshot / K1+K2: Zero all faders
- K3: Start/stop sequencer (disabled in Live mode)

### SAMPLE (Page 2)
Sample loading and manipulation.
- E2: Select parameter / E3: Edit value
- Parameters: Start, Length, Speed, Reverse, XFade, Gain, Mode (Gate/Trigger)
- K2: Load sample / Cancel recording
- K3: Start/stop recording

### SNAPSHOTS (Page 3)
Snapshot library with 8 slots and pack browser.
- E2: Select slot / K1+E2: Browse snapshot packs
- K2: Jump to snapshot / K1+K2: Load snapshot pack
- K3: Toggle enable/disable / K1+K3: Delete snapshot

### SEQUENCER (Page 4)
Snapshot playback sequencer.
- Modes: Live, Sequential, Random, Pattern, Euclidean
- E2: Select parameter / E3: Edit value
- Parameters vary by mode (BPM, Morph time, Duration, Pattern, Euclidean settings)
- K2: Mode-specific (add to pattern, toggle rest behavior)
- K3: Start/stop (disabled in Live mode)

### ENVELOPE (Page 5)
ADSR envelope shaping with filter modulation.
- E2: Select parameter / E3: Edit value
- Parameters: Attack, Decay, Sustain, Release, Filter Mod
- Filter Mod: Envelope→filter tracking (0-10kHz)

### SCALE (Page 6)
Musical scale configuration.
- E2: Select parameter / E3: Edit value
- Parameters: Scale type, Root note, Octave offset

### MIDI (Page 7)
MIDI controller configuration.
- E2: Select parameter / E3: Edit value
- Parameters: MIDI channel (1-16), Fader CC start (default 34)

### LFO (Page 8)
Three independent LFO modulators.
- E2: Select parameter / E3: Edit value
- Parameters: LFO select, Enable, Shape, Rate Mode, Rate, Depth, Destination, Dest Param

### SCENES (Page 9)
Complete instrument state management.
- E2: Select scene slot
- K2: Save scene
- K3: Load scene / K1+K3: Clear scene

## Tips

- **Start simple**: Load a sample, load "I-IV-V Simple" pack, set sequencer to random
- **Live mode**: Use sequencer Live mode during performance to prevent accidental triggering
- **Filter tracking**: Try 2000-5000 Hz envelope→filter mod for classic synth movement
- **Euclidean patterns**: Create rhythmic variation with pulses/steps/rotation
- **Scene workflow**: Build your sound, save as scene, recall instantly later
- **Custom packs**: Edit `/lib/snapshot_packs.lua` to create your own chord palettes

## MIDI Setup

Default configuration:
- Channel: 1
- Fader CCs: 34-41 (8 faders)
- Optional: Filter cutoff, resonance, voice filter offsets (configurable in code)

Change in MIDI page or edit `lib/midi_handler.lua` for advanced routing.

## Recording

Recordings saved to: `/home/we/dust/audio/strata/`  
Format: `YYYYMMDD_HHMMSS_strata_rec.wav`  
Maximum duration: 30 seconds stereo

## Credits

Inspired by the Vestax Faderboard DJ sampler.  
Developed for monome norns.  
SuperCollider engine with custom sample looping and voice architecture.

## Links

- Documentation: [GitHub](https://github.com/thomcummings/strata)
- norns community: https://llllllll.co

---

strata v1.0
