# strata - Development Overview

## Project History

**Origin**: Emulation of the Vestax Faderboard, a unique DJ sampler from the early 2000s that used 8 crossfaders to gate/trigger samples with creative performance techniques.

**Goal**: Recreate the core concept on norns while expanding into a sophisticated harmonic performance instrument with scale awareness, morphing, sequencing, and deep modulation.

**Development Period**: Evolved through iterative sessions focusing on musical workflow over technical complexity.

## Architecture

### Core Components

**File Structure**:
```
strata/
├── strata.lua                          # Main script
├── lib/
│   ├── Engine_Strata.sc               # SuperCollider audio engine
│   ├── scale_system.lua               # Scale/pitch calculations
│   ├── midi_handler.lua               # MIDI CC mapping
│   └── snapshot_packs.lua             # Chord/harmony presets
└── data/
    ├── snapshots.data                 # Saved snapshot library
    └── scenes.data                    # Saved scene presets
```

**Audio Engine (SuperCollider)**:
- 8-voice polyphonic SynthDef with independent envelopes
- Custom loop playback using Phasor with crossfade windows
- Per-voice filtering + master filter chain
- Real-time parameter control via OSC
- Waveform generation for visualization
- Input monitoring for recording VU meters

**Control Flow**:
1. MIDI/UI input → Lua state
2. Fader position → threshold detection → gate/trigger logic
3. Scale system calculates frequencies
4. Engine commands sent to SuperCollider
5. Audio output + OSC feedback (waveform, levels)

### Key Design Decisions

**Musical-first parameters**:
- Sample loop controls use **time** (seconds/ms) not normalized 0-1 values
- More intuitive for musical timing and editing

**Trigger vs Gate modes**:
- Gate: Smooth envelope control (pads, melodic)
- Trigger: Discrete attacks (drums, percussion)
- Addresses different musical use cases with one instrument

**Voice-weighted snapshot packs**:
- Roots emphasized (0.85-0.90)
- Fifths strong (0.75)
- Color tones balanced (0.50-0.70)
- Creates natural, professional voicings automatically

**Live mode protection**:
- Sequencer "Live" mode prevents accidental morphing during performance
- Learned from user feedback about performance anxiety

**Scene vs Snapshot separation**:
- Snapshots: Quick recall of fader positions (performance tool)
- Scenes: Complete instrument state (sound design preset)
- Different workflows, both essential

## Feature Development History

### Phase 1: Core Sampler (Foundation)
- 8-voice sample playback engine
- ADSR envelope per voice
- Basic loop point control
- MIDI fader input (CC 34-41)
- Gate threshold triggering

### Phase 2: Musicality (Scale System)
- Scale system (8 modes + chromatic)
- Frequency calculation per fader/scale degree
- Root note and octave control
- Octave offset (including random mode)

### Phase 3: Sound Shaping (Filtering & LFOs)
- Master filter (LP/HP/BP types)
- Filter cutoff, resonance, drive
- 3 independent LFO engines
- 12 modulation destinations
- Hz and BPM-sync rate modes
- Envelope→filter tracking

### Phase 4: Performance Tools (Snapshots)
- 8-slot snapshot library
- Snapshot morphing with adjustable duration
- Sequencer (Sequential, Random, Pattern, Euclidean, Live modes)
- BPM-sync'd morphing
- Manual override during morphing

### Phase 5: Organization (Scenes & Packs)
- Scene system (8 slots, complete state)
- 10 built-in snapshot packs
- Voice-weighted chord generation
- Custom pack support via external file

### Phase 6: Recording & Refinement
- 30-second stereo recording via softcut
- Real-time VU meters with input monitoring
- Waveform normalization for display
- Timestamp-first filename sorting
- Sample gain parameter
- Trigger mode implementation
- Filter mode cycling (LP/HP/BP)

## Current State (v1.0)

**Stable Features**:
- All 9 pages functional
- Snapshot packs working with proper voice weighting
- Recording with VU meters
- Complete scene save/load
- LFO system with all destinations
- MIDI integration

**Known Limitations**:
- VU meters don't currently display (OSC communication issue, non-critical)
- Recording limited to 30 seconds (softcut buffer limit)
- No multi-sample support (single sample per instance)
- No per-voice sample assignment

**Performance**:
- Stable at 60 FPS UI refresh
- LFO update at 60 Hz
- Sequencer timing accurate
- No audio glitches reported

## Technical Notes

### SuperCollider Engine Details

**Loop Crossfading**:
- Uses 5% of loop length or 20ms (whichever smaller)
- Prevents clicks at loop boundaries
- Window function applied at edges

**Envelope Implementation**:
- `doneAction: 0` (don't free on release)
- Voices persist, gates control envelope
- Minimum attack/release (0.01s/0.02s) prevents clicks

**Filter Tracking**:
- Envelope multiplied by `envFilterMod` parameter
- Added to base filter cutoff
- Creates classic synth "filter opens with note" behavior

### State Management

**Morphing System**:
- Tracks `from_positions`, `to_positions`, `target_positions`
- `manual_override` flags per fader
- 60 FPS interpolation clock
- Progress 0-1 calculated from `util.time()`

**LFO System**:
- Phase accumulation (0-1 wrap)
- Shape calculation separate from rate
- Modulation applied every frame before engine updates
- Depth scaling (-100 to +100%)

**File I/O**:
- Snapshots/scenes use `tab.save/tab.load`
- Persistent across sessions
- Automatic save on modification

## Future Possibilities

**High Priority**:
- Multi-sample layers (stack up to 4 samples)
- Per-voice sample assignment (different sample per fader)
- Reverb integration (Greyhole engine already loaded but not exposed)
- MIDI keyboard support (play any note, not just 8 faders)
- Randomization features (randomize fader positions, sequence)

**Medium Priority**:
- External modulation inputs (crow CV)
- Grid integration (8x8 grid = direct fader control)
- More snapshot pack slots (expandable beyond 10)
- Export snapshots as MIDI files
- Probability per sequencer step

**Low Priority / Experimental**:
- Granular mode (alternative to loop mode)
- FFT freeze/spectral effects
- Per-voice panning
- Automation recording/playback
- Alternative tuning systems (just intonation, etc)

**Community Requests to Consider**:
- Sample slicing/chopping
- Integration with other norns scripts
- OSC control for external apps
- Grid-based pattern editor

## Development Workflow (Claude Code + GitHub)

**Branching Strategy**:
- `main`: Stable releases
- `dev`: Active development
- Feature branches for major additions

**Testing Checklist**:
- [ ] All 9 pages navigable
- [ ] Sample loads and plays
- [ ] Snapshots save/load/morph
- [ ] Scenes preserve all settings
- [ ] Recording produces valid audio files
- [ ] LFOs modulate correctly
- [ ] MIDI input responsive
- [ ] No audio glitches during normal use

**Key Files for Common Changes**:
- Add modulation destination: `apply_lfo_modulation()` in main script
- New snapshot pack: `/lib/snapshot_packs.lua`
- Engine changes: `/lib/Engine_Strata.sc` (requires norns restart)
- MIDI routing: `/lib/midi_handler.lua`
- UI layout: `draw_*_page()` functions in main script

## Design Philosophy

**Principles**:
1. Musical utility over technical showcase
2. Performance-ready out of the box
3. Deep but discoverable (progressive complexity)
4. Respect muscle memory (consistent controls)
5. Fail gracefully (no crashes, sensible defaults)

**User Experience Goals**:
- "Load sample → load pack → play" workflow in <30 seconds
- Live mode prevents performance accidents
- Visual feedback for all parameters
- Notifications for state changes
- Scrollable lists for > 2-3 parameters

**Code Style**:
- Descriptive variable names
- Comments for non-obvious logic
- Separate functions for distinct responsibilities
- Minimal nesting (early returns)
- External data files for editability

---

strata v1.0 - Development context for Claude Code
