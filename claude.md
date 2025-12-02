# Claude Development Guide - strata

## Quick Context
**strata** is an 8-voice performance sampler for monome norns. Built with Lua (UI/control) + SuperCollider (audio engine).

📖 **For architecture & design philosophy, read `dev_log.md` first.**

This guide is for rapid development with Claude Code.

---

## Critical Constraints

### Real-Time Audio
- **No blocking operations** in audio callbacks
- **Buffer timing is critical** - recent fixes in `claude/fix-mono-stereo-playback-*` branches
- **SuperCollider changes require norns restart** - can't hot-reload the engine
- Target: 60 FPS UI, 60 Hz LFO updates, zero audio dropouts

### Hardware Platform
- **norns-specific APIs**: softcut, engine, params, screen, etc.
- **Testing requires norns device or norns shield** (can't fully emulate)
- **Data persists to `/home/we/dust/data/strata/`**
- **Recordings save to `/home/we/dust/audio/strata/`**

---

## File Map (Where to Look)

| Task | File | Key Functions/Sections |
|------|------|------------------------|
| **Add UI element** | `strata.lua` | `draw_*_page()` functions |
| **Add modulation target** | `strata.lua` | `apply_lfo_modulation()` (~line 800) |
| **New snapshot preset** | `lib/snapshot_packs.lua` | Add to `PACKS` table |
| **MIDI mapping** | `lib/midi_handler.lua` | `cc_handlers` table |
| **Audio engine changes** | `lib/Engine_Strata.sc` | SuperCollider synth definitions |
| **Scale/pitch logic** | `lib/scale_system.lua` | Pitch calculations, scale patterns |
| **State persistence** | `strata.lua` | `load_scene()`, `save_scene()` |

---

## Common Development Tasks

### 1. Adding a New LFO Modulation Target
```lua
-- In apply_lfo_modulation() function:
elseif dest == "new_target" then
  local base = get_base_value()  -- Your parameter
  local modulated = base + (lfo_value * depth)
  set_parameter(modulated)
end
```
**Then:** Add to LFO dest encoder menu on Page 5

### 2. Creating a New Snapshot Pack
```lua
-- In lib/snapshot_packs.lua:
PACKS.my_new_pack = {
  name = "My Pack Name",
  snapshots = {
    {rate = 1.0, start = 0.1, length = 0.5, filter = 800, ...},
    -- 8 total snapshots
  }
}
```
**Then:** Add to `snapshot_pack_list` array

### 3. Adding a UI Page
1. Add page number to `PAGES` table
2. Create `draw_my_page()` function
3. Create `key_my_page(n, z)` and `enc_my_page(n, d)` handlers
4. Add navigation in `key()` function
5. Update `draw()` to route to your page

### 4. Fixing Audio Issues
- **Check buffer allocation** in `Engine_Strata.sc` - see PR #42 for mono→stereo timing issues
- **Verify voice management** - voices 1-8 indexed consistently between Lua/SC
- **Test with both mono and stereo samples** - recent bug fixes for buffer.read edge cases
- **Monitor norns console** for SuperCollider errors (`UGen:new` warnings, etc.)

---

## Testing Workflow

**No automated tests exist.** Use this manual checklist:

### Quick Smoke Test (5 min)
- [ ] Load any sample - plays without errors
- [ ] Navigate all 9 pages - no crashes
- [ ] Save/load a snapshot
- [ ] MIDI faders respond
- [ ] Recording produces valid file

### Full Regression (15 min)
- [ ] Load mono sample - stereo playback works
- [ ] Load stereo sample - plays correctly
- [ ] Morph between snapshots (Page 3)
- [ ] Save/load scene (Page 9)
- [ ] All LFO destinations modulate (Page 5)
- [ ] Sequencer plays patterns (Page 8)
- [ ] Filter sweep responds (Page 2)
- [ ] Rate/pitch/pan controls work (Page 2)

### Performance Check
- Run with `norns.debug.show_cpu = true`
- CPU should stay < 50% during normal use
- No "late" warnings in SuperCollider console

---

## Known Gotchas

### SuperCollider Engine
- **Changes require norns restart** - no hot reload
- **Buffer numbers must match** between SC and Lua (see voice_synths table)
- **VU meters don't work** - OSC sync issue, non-critical, don't spend time on this

### Audio Buffers
- **softcut limited to 30 seconds** recording - hardware constraint
- **Mono samples need stereo conversion** - see `Engine_Strata.sc:199-206`
- **Buffer timing on load is critical** - must wait for buffer allocation before playback

### State Management
- **Scenes use tab.save/load** - must serialize all state
- **PSET params auto-saved** - but snapshots/scenes are manual
- **Sample paths are absolute** - consider portability if sharing scenes

---

## Development Workflow

### Branch Strategy
- `main` - Stable releases only
- `dev` - Active development
- `claude/*` - Claude Code feature branches (auto-generated)
- Always PR to `dev`, not `main`

### Making Changes
1. **Read existing code first** - don't propose blind changes
2. **Test on actual norns** - emulation has limits
3. **Check dev_log.md** - may explain "why" for non-obvious code
4. **Commit with clear messages** - describe the "why", not just "what"
5. **Push to claude/* branch** - follows Claude Code convention

### When SuperCollider Changes
```bash
# On norns:
;restart  # In maiden REPL, or:
systemctl restart norns
```
Lua changes hot-reload via maiden, but SC engine does not.

---

## Code Style (from dev_log.md)

- **Descriptive names**: `filter_cutoff`, not `fc`
- **Early returns**: Avoid deep nesting
- **Comments for non-obvious logic**: Why, not what
- **Separate functions**: Each does one thing
- **External data files**: Snapshot packs, scales in /lib

---

## Recent Issues Fixed (Context for Claude)

- **PR #42-43**: Fixed mono→stereo buffer timing - `UGen:new` errors during sample load
- **Branch `claude/fix-mono-stereo-playback-*`**: Corrected buffer number sync between SC and Lua
- These were subtle race conditions - be careful with buffer allocation timing

---

## For New Features

**Before implementing:**
1. Check if it conflicts with "performance-ready" philosophy
2. Consider CPU impact (norns has limited resources)
3. Will it require SC engine changes? (Restart friction for users)
4. Does it fit within 9-page UI paradigm?

**If unsure:** Refer to design philosophy in `dev_log.md` - "musical utility over technical showcase"

---

## Resources

- **Full architecture**: Read `dev_log.md`
- **norns docs**: https://monome.org/docs/norns/
- **SuperCollider for norns**: https://monome.org/docs/norns/engine/
- **norns community**: https://llllllll.co/
