-- snapshot_packs.lua
-- Chord and harmony presets for strata snapshots
-- 
-- Each pack contains 8 chord voicings
-- Each chord has 8 fader positions (0.0 - 1.0) representing scale degrees 0-7
-- Fader 1 = degree 0 (root of scale)
-- Fader 2 = degree 1 (second)
-- ... and so on

local SnapshotPacks = {}

SnapshotPacks.packs = {
    {
        name = "Basic Triads",
        description = "Diatonic triads I-vii",
        chords = {
            -- I: root, third, fifth, octave (C-E-G-C in C major)
            {name = "I",    faders = {0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.60}},
            -- ii: second, fourth, sixth, octave (D-F-A-D in C major)
            {name = "ii",   faders = {0.00, 0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00}},
            -- iii: third, fifth, seventh, octave (E-G-B-E in C major)
            {name = "iii",  faders = {0.00, 0.00, 0.90, 0.00, 0.65, 0.00, 0.75, 0.00}},
            -- IV: fourth, sixth, root, octave (F-A-C-F in C major)
            {name = "IV",   faders = {0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00, 0.00}},
            -- V: fifth, seventh, second, octave (G-B-D-G in C major)
            {name = "V",    faders = {0.00, 0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00}},
            -- vi: sixth, root, third, octave (A-C-E-A in C major)
            {name = "vi",   faders = {0.65, 0.00, 0.75, 0.00, 0.00, 0.90, 0.00, 0.00}},
            -- vii°: seventh, second, fourth (B-D-F in C major)
            {name = "vii°", faders = {0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.90, 0.00}},
            -- I octave up: emphasize higher register
            {name = "I↑",   faders = {0.60, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.90}}
        }
    },
    {
        name = "I-IV-V Simple",
        description = "Three chord progressions",
        chords = {
            {name = "I",  faders = {0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.60}},
            {name = "I",  faders = {0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.60}},
            {name = "IV", faders = {0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00, 0.00}},
            {name = "IV", faders = {0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00, 0.00}},
            {name = "V",  faders = {0.00, 0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00}},
            {name = "V",  faders = {0.00, 0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00}},
            {name = "vi", faders = {0.65, 0.00, 0.75, 0.00, 0.00, 0.90, 0.00, 0.00}},
            {name = "I",  faders = {0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.60}}
        }
    },
    {
        name = "Jazz 7ths",
        description = "Diatonic seventh chords",
        chords = {
            -- IMaj7: C-E-G-B
            {name = "IMaj7",  faders = {0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.50, 0.00}},
            -- iim7: D-F-A-C
            {name = "iim7",   faders = {0.50, 0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00}},
            -- iiim7: E-G-B-D
            {name = "iiim7",  faders = {0.00, 0.50, 0.90, 0.00, 0.65, 0.00, 0.75, 0.00}},
            -- IVMaj7: F-A-C-E
            {name = "IVMaj7", faders = {0.65, 0.00, 0.50, 0.90, 0.00, 0.75, 0.00, 0.00}},
            -- V7: G-B-D-F
            {name = "V7",     faders = {0.00, 0.65, 0.00, 0.50, 0.90, 0.00, 0.75, 0.00}},
            -- vim7: A-C-E-G
            {name = "vim7",   faders = {0.65, 0.00, 0.75, 0.00, 0.50, 0.90, 0.00, 0.00}},
            -- viim7b5: B-D-F-A
            {name = "viim7b5",faders = {0.00, 0.65, 0.00, 0.75, 0.00, 0.50, 0.90, 0.00}},
            -- IMaj7 upper voicing
            {name = "IMaj7↑", faders = {0.60, 0.00, 0.65, 0.00, 0.75, 0.00, 0.55, 0.00}}
        }
    },
    {
        name = "Minor Harmony",
        description = "Natural minor chords",
        chords = {
            -- i minor: root, b3, 5
            {name = "i",   faders = {0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.60}},
            -- ii dim: 2, 4, b6
            {name = "ii°", faders = {0.00, 0.90, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00}},
            -- III: b3, 5, 7
            {name = "III", faders = {0.00, 0.00, 0.90, 0.00, 0.65, 0.00, 0.75, 0.00}},
            -- iv minor: 4, b6, root
            {name = "iv",  faders = {0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00, 0.00}},
            -- v minor: 5, b7, 2
            {name = "v",   faders = {0.00, 0.65, 0.00, 0.00, 0.90, 0.00, 0.75, 0.00}},
            -- VI: b6, root, 3
            {name = "VI",  faders = {0.65, 0.00, 0.75, 0.00, 0.00, 0.90, 0.00, 0.00}},
            -- VII: b7, 2, 4
            {name = "VII", faders = {0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.90, 0.00}},
            -- i upper
            {name = "i↑",  faders = {0.60, 0.00, 0.65, 0.00, 0.75, 0.00, 0.00, 0.90}}
        }
    },
    {
        name = "Ambient Spread",
        description = "Wide fourths voicings",
        chords = {
            -- Stacks of fourths for ethereal sound
            {name = "I",   faders = {0.70, 0.00, 0.00, 0.55, 0.00, 0.00, 0.40, 0.00}},
            {name = "ii",  faders = {0.00, 0.70, 0.00, 0.00, 0.55, 0.00, 0.00, 0.40}},
            {name = "iii", faders = {0.40, 0.00, 0.70, 0.00, 0.00, 0.55, 0.00, 0.00}},
            {name = "IV",  faders = {0.00, 0.40, 0.00, 0.70, 0.00, 0.00, 0.55, 0.00}},
            {name = "V",   faders = {0.00, 0.00, 0.40, 0.00, 0.70, 0.00, 0.00, 0.55}},
            {name = "vi",  faders = {0.55, 0.00, 0.00, 0.40, 0.00, 0.70, 0.00, 0.00}},
            {name = "vii", faders = {0.00, 0.55, 0.00, 0.00, 0.40, 0.00, 0.70, 0.00}},
            {name = "I↑",  faders = {0.50, 0.00, 0.00, 0.60, 0.00, 0.00, 0.70, 0.00}}
        }
    },
    {
        name = "Pentatonic Clusters",
        description = "Pentatonic scale harmony",
        chords = {
            -- Root pentatonic cluster (C-D-E-G-A)
            {name = "1", faders = {0.85, 0.70, 0.75, 0.00, 0.80, 0.65, 0.00, 0.50}},
            -- Second pentatonic (D-E-G-A-C)
            {name = "2", faders = {0.65, 0.85, 0.75, 0.00, 0.80, 0.70, 0.00, 0.00}},
            -- Third pentatonic (E-G-A-C-D)
            {name = "3", faders = {0.70, 0.65, 0.85, 0.00, 0.80, 0.75, 0.00, 0.00}},
            -- Fourth (using pentatonic tones)
            {name = "4", faders = {0.75, 0.70, 0.00, 0.00, 0.85, 0.80, 0.00, 0.50}},
            -- Fifth pentatonic
            {name = "5", faders = {0.80, 0.75, 0.00, 0.00, 0.85, 0.70, 0.00, 0.65}},
            -- Sixth pentatonic
            {name = "6", faders = {0.70, 0.80, 0.75, 0.00, 0.65, 0.85, 0.00, 0.00}},
            -- Higher cluster
            {name = "7", faders = {0.50, 0.65, 0.70, 0.00, 0.75, 0.80, 0.00, 0.85}},
            -- Top cluster
            {name = "8", faders = {0.00, 0.50, 0.65, 0.00, 0.70, 0.75, 0.00, 0.85}}
        }
    },
    {
        name = "Suspended Dream",
        description = "Sus2 & sus4 harmonies",
        chords = {
            -- sus2: C-D-G (root, 2nd, 5th)
            {name = "sus2-I",  faders = {0.85, 0.70, 0.00, 0.00, 0.75, 0.00, 0.00, 0.50}},
            -- sus4: C-F-G (root, 4th, 5th)
            {name = "sus4-I",  faders = {0.85, 0.00, 0.00, 0.70, 0.75, 0.00, 0.00, 0.50}},
            -- sus2 on ii
            {name = "sus2-ii", faders = {0.50, 0.85, 0.70, 0.00, 0.00, 0.75, 0.00, 0.00}},
            -- sus4 on ii
            {name = "sus4-ii", faders = {0.70, 0.85, 0.00, 0.00, 0.00, 0.75, 0.00, 0.00}},
            -- sus2 on V
            {name = "sus2-V",  faders = {0.00, 0.00, 0.00, 0.00, 0.85, 0.70, 0.00, 0.75}},
            -- sus4 on V
            {name = "sus4-V",  faders = {0.70, 0.00, 0.00, 0.00, 0.85, 0.00, 0.00, 0.75}},
            -- sus2 on vi
            {name = "sus2-vi", faders = {0.00, 0.00, 0.75, 0.00, 0.00, 0.85, 0.70, 0.00}},
            -- sus4 on vi
            {name = "sus4-vi", faders = {0.70, 0.00, 0.00, 0.00, 0.00, 0.85, 0.00, 0.75}}
        }
    },
    {
        name = "Open Fifths",
        description = "Root + fifth only",
        chords = {
            -- C + G (power chord on root)
            {name = "1", faders = {0.90, 0.00, 0.00, 0.00, 0.85, 0.00, 0.00, 0.70}},
            -- D + A
            {name = "2", faders = {0.00, 0.90, 0.00, 0.00, 0.00, 0.85, 0.00, 0.00}},
            -- E + B
            {name = "3", faders = {0.00, 0.00, 0.90, 0.00, 0.00, 0.00, 0.85, 0.00}},
            -- F + C
            {name = "4", faders = {0.70, 0.00, 0.00, 0.90, 0.00, 0.00, 0.00, 0.85}},
            -- G + D
            {name = "5", faders = {0.00, 0.85, 0.00, 0.00, 0.90, 0.00, 0.00, 0.00}},
            -- A + E
            {name = "6", faders = {0.00, 0.00, 0.85, 0.00, 0.00, 0.90, 0.00, 0.00}},
            -- B + F
            {name = "7", faders = {0.00, 0.00, 0.00, 0.85, 0.00, 0.00, 0.90, 0.00}},
            -- C + G (upper register)
            {name = "8", faders = {0.75, 0.00, 0.00, 0.00, 0.80, 0.00, 0.00, 0.90}}
        }
    },
    {
        name = "Add9 Shimmer",
        description = "Triads with added 9th",
        chords = {
            -- C-E-G with D (9th): C-D-E-G
            {name = "Iadd9",  faders = {0.85, 0.55, 0.65, 0.00, 0.75, 0.00, 0.00, 0.50}},
            -- D-F-A with E (9th)
            {name = "iiadd9", faders = {0.00, 0.85, 0.55, 0.65, 0.00, 0.75, 0.00, 0.00}},
            -- E-G-B with F# (9th)
            {name = "iiiadd9",faders = {0.00, 0.00, 0.85, 0.55, 0.65, 0.00, 0.75, 0.00}},
            -- F-A-C with G (9th)
            {name = "IVadd9", faders = {0.65, 0.00, 0.00, 0.85, 0.55, 0.75, 0.00, 0.00}},
            -- G-B-D with A (9th)
            {name = "Vadd9",  faders = {0.00, 0.65, 0.00, 0.00, 0.85, 0.55, 0.75, 0.00}},
            -- A-C-E with B (9th)
            {name = "viadd9", faders = {0.65, 0.00, 0.75, 0.00, 0.00, 0.85, 0.55, 0.00}},
            -- B-D-F with C (9th)
            {name = "viiadd9",faders = {0.55, 0.65, 0.00, 0.75, 0.00, 0.00, 0.85, 0.00}},
            -- Upper add9
            {name = "Iadd9↑", faders = {0.60, 0.50, 0.65, 0.00, 0.75, 0.00, 0.00, 0.85}}
        }
    },
    {
        name = "Whole Tone Dream",
        description = "All whole steps",
        chords = {
            -- Whole tone: C-D-E-F#-G#-A# (use all even degrees)
            {name = "1", faders = {0.75, 0.00, 0.70, 0.00, 0.65, 0.00, 0.60, 0.00}},
            {name = "2", faders = {0.00, 0.75, 0.00, 0.70, 0.00, 0.65, 0.00, 0.60}},
            {name = "3", faders = {0.60, 0.00, 0.75, 0.00, 0.70, 0.00, 0.65, 0.00}},
            {name = "4", faders = {0.00, 0.60, 0.00, 0.75, 0.00, 0.70, 0.00, 0.65}},
            {name = "5", faders = {0.65, 0.00, 0.60, 0.00, 0.75, 0.00, 0.70, 0.00}},
            {name = "6", faders = {0.00, 0.65, 0.00, 0.60, 0.00, 0.75, 0.00, 0.70}},
            {name = "1↑",faders = {0.70, 0.00, 0.65, 0.00, 0.60, 0.00, 0.75, 0.00}},
            {name = "2↑",faders = {0.00, 0.70, 0.00, 0.65, 0.00, 0.60, 0.00, 0.75}}
        }
    }
}

return SnapshotPacks
