// Engine_Strata.sc
// SuperCollider engine for strata norns script by thomcummings

Engine_Strata : CroneEngine {
    var <synths;
    var <buffer;
    var <voiceGroup;
    var <filterGroup;
    var <masterGroup;
    var <lfos;
    var <monitorSynth;
    var <reverbSynth;
    var voiceBus;
    var filterBus;
    var peakBusL;  // Control bus for left peak
    var peakBusR;  // Control bus for right peak
    
    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }
    
    alloc {
        // Allocate audio buses for signal routing
        voiceBus = Bus.audio(context.server, 2);    // voices → filter
        filterBus = Bus.audio(context.server, 2);   // filter → reverb

        // Allocate control buses for recording level monitoring
        peakBusL = Bus.control(context.server, 1);
        peakBusR = Bus.control(context.server, 1);

        // Allocate buffer for sample (30 seconds stereo at 48kHz)
        buffer = Buffer.alloc(context.server, 48000 * 30, 2);

        // Create synth groups for proper ordering
        voiceGroup = Group.new(context.server);
        filterGroup = Group.after(voiceGroup);
        masterGroup = Group.after(filterGroup);

        // Initialize synths array
        synths = Array.newClear(8);

        // Initialize LFOs array
        lfos = Array.newClear(3);

        // Load SynthDefs
        this.loadSynthDefs;

        // Wait for SynthDefs to load
        context.server.sync;

        // Create 8 voice synths
        8.do({ arg i;
            synths[i] = Synth(\faderVoice, [
                \out, voiceBus,
                \bufnum, buffer.bufnum,
                \voiceId, i,
                \xfadeTime, 0.1
            ], voiceGroup);
        });

        // Create master filter synth (voices → filter)
        Synth(\masterFilter, [
            \in, voiceBus,
            \out, filterBus
        ], filterGroup);

        // Create reverb synth (filter → reverb → output)
        reverbSynth = Synth(\greyhole, [
            \in, filterBus,
            \out, context.out_b,
            \delayTime, 0.2,      // Initial delay time (will be set by Lua)
            \damping, 0.5,         // Initial damping
            \size, 2.0,            // Larger room size for better quality
            \diff, 0.7,            // Good diffusion
            \feedback, 0.9,        // High feedback for long decay
            \modDepth, 0.2,        // Moderate modulation depth
            \modFreq, 0.5,         // Slow modulation for smooth sound
            \mix, 0.0              // Start completely dry
        ], masterGroup);

        // Create 3 LFO synths
        3.do({ arg i;
            lfos[i] = Synth(\lfo, [
                \rate, 1,
                \depth, 0
            ], masterGroup);
        });

        // Add engine commands
        this.addCommands;

        postln("strata engine initialized");
    }
    
    loadSynthDefs {
        // Voice SynthDef - plays pitched sample with gating
        SynthDef(\faderVoice, {
            arg out=0, bufnum=0,
                gate=0, freq=440, amp=0.8, pan=0,
                loopStart=0, loopEnd=1, speed=1.0, reverse=0,
                faderPos=0,
                filterCutoff=20000, filterRes=0.1, filterOffset=0,
                attack=0.001, decay=0.1, sustain=0.7, release=0.2,
                envFilterMod=0,
                xfadeTime=0.1;
            
            var sig, env, playhead, startFrame, endFrame, bufFrames, playRate;
            var filterFreq, localFilter;
            var loopLength, xfadeFrames, normPhase, window;
            
            bufFrames = BufFrames.kr(bufnum);

            // Calculate start and end frames
            startFrame = loopStart * bufFrames;
            endFrame = loopEnd * bufFrames;
            loopLength = endFrame - startFrame;

            // Crossfade: fixed at 5% of loop length or 20ms, whichever is smaller
            xfadeFrames = min(loopLength * 0.05, SampleRate.ir * 0.02);

            // Playback rate combines pitch shift, speed, and reverse
            // reverse: 0 = forward (1), 1 = backward (-1)
            playRate = BufRateScale.kr(bufnum) * (freq / 440.0) * speed * (1 - (2 * reverse));
            
            // Envelope: ADSR with minimum values to prevent clicks
            env = EnvGen.kr(
                Env.adsr(max(attack, 0.01), decay, sustain, max(release, 0.02)),
                gate,
                doneAction: 0
            );
            
            // Phasor for loop playback
            playhead = Phasor.ar(
                0,
                playRate,
                startFrame,
                endFrame,
                startFrame
            );

            // Read from buffer with cubic interpolation
            // Handle both mono and stereo samples
            sig = if(BufChannels.ir(bufnum) == 1, {
                // Mono buffer: read one channel and create pseudo-stereo
                var mono = BufRd.ar(1, bufnum, playhead, 1, 4);
                var delayed = DelayC.ar(mono, 0.02, 0.010);  // 10ms delay on right
                [mono, delayed]
            }, {
                // Stereo buffer: read both channels normally
                BufRd.ar(2, bufnum, playhead, 1, 4)
            });
            
            // Apply simple window at loop boundaries to smooth discontinuities
            // Normalized phase within loop (0 to 1)
            normPhase = (playhead - startFrame) / loopLength;
            
            // Create fade window: fade in at start, fade out at end
            window = min(
                (normPhase * loopLength / xfadeFrames).clip(0, 1), // Fade in
                ((1 - normPhase) * loopLength / xfadeFrames).clip(0, 1) // Fade out
            );
            
            sig = sig * window;
            
            // Apply envelope, fader position, and amp
            sig = sig * env * amp * faderPos.lag(0.002);
            
            // Per-voice filter with envelope modulation
            filterFreq = (filterCutoff + filterOffset + (env * envFilterMod)).clip(20, 20000);
            localFilter = RLPF.ar(sig, filterFreq, filterRes.linlin(0, 1, 1, 0.1));
            
            // Pan
            sig = Balance2.ar(localFilter[0], localFilter[1], pan);
            
            // DC blocker
            sig = LeakDC.ar(sig, 0.995);
            
            Out.ar(out, sig);
        }).add;
        
        // Master Filter SynthDef
        SynthDef(\masterFilter, {
            arg in=0, out=0,
                cutoff=20000, resonance=0.1, filterType=0,
                drive=1.0;

            var sig, filtered;

            sig = In.ar(in, 2);

            // Apply drive/saturation
            sig = (sig * drive).tanh;

            // Select filter type: 0=LP, 1=HP, 2=BP
            filtered = Select.ar(filterType, [
                RLPF.ar(sig, cutoff.clip(20, 20000), resonance.linlin(0, 1, 1, 0.1)),
                RHPF.ar(sig, cutoff.clip(20, 20000), resonance.linlin(0, 1, 1, 0.1)),
                BPF.ar(sig, cutoff.clip(20, 20000), resonance.linlin(0, 1, 0.5, 0.05))
            ]);

            Out.ar(out, filtered);
        }).add;

        // Greyhole Reverb SynthDef (mi-engines)
        SynthDef(\greyhole, {
            arg in=0, out=0,
                delayTime=0.1, damping=0.5, size=1.0, diff=0.707,
                feedback=0.9, modDepth=0.1, modFreq=2.0, mix=0.0, amp=1.0;

            var sig, verb, wet, dry;

            // Read input
            sig = In.ar(in, 2);
            dry = sig;

            // Greyhole reverb (mi-engines - high quality)
            // Greyhole expects: delayTime, damping, size, diff, feedback, modDepth, modFreq
            verb = Greyhole.ar(
                sig,
                delayTime.clip(0.001, 2.0),   // delay time (0.001-2.0)
                damping.clip(0, 1),            // damping (0-1)
                size.clip(0.5, 5.0),           // size (0.5-5.0)
                diff.clip(0, 1),               // diffusion (0-1)
                feedback.clip(0, 1),           // feedback (0-1)
                modDepth.clip(0, 1),           // modulation depth (0-1)
                modFreq.clip(0.1, 10)          // modulation freq (0.1-10)
            );

            // Mix wet/dry using crossfade
            sig = XFade2.ar(dry, verb, mix.clip(0, 1) * 2 - 1);

            // Apply master amp (for muting during recording)
            sig = sig * amp.clip(0, 1);

            Out.ar(out, sig);
        }).add;
        
        // LFO SynthDef
        SynthDef(\lfo, {
            arg bus=0, rate=1, depth=0.5, shape=0;
            var lfo;
            
            // Select LFO shape: 0=sine, 1=tri, 2=random
            lfo = Select.kr(shape, [
                SinOsc.kr(rate),
                LFTri.kr(rate),
                LFNoise0.kr(rate)
            ]);
            
            // Scale by depth
            lfo = lfo * depth;
            
            Out.kr(bus, lfo);
        }).add;
        
        // Input monitoring SynthDef for recording level tracking
        SynthDef(\inputMonitor, {
            arg peakBusL=0, peakBusR=1;
            var input, peakL, peakR;

            // Read stereo input
            input = SoundIn.ar([0, 1]);

            // Track peak levels with fast attack, slow decay
            // Peak.kr will hold the peak value until reset
            peakL = Peak.kr(Amplitude.kr(input[0], 0.01, 0.1), Impulse.kr(0));
            peakR = Peak.kr(Amplitude.kr(input[1], 0.01, 0.1), Impulse.kr(0));

            // Write peaks to control buses
            Out.kr(peakBusL, peakL);
            Out.kr(peakBusR, peakR);
        }).add;
    }
    
    addCommands {
        // Voice control commands
        this.addCommand(\noteOn, "if", { arg msg;
            var voice = msg[1].asInteger;
            var freq = msg[2].asFloat;
            postln("Engine noteOn: voice=" ++ voice ++ " freq=" ++ freq);
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\gate, 1, \freq, freq);
            });
        });
        
        this.addCommand(\noteOff, "i", { arg msg;
            var voice = msg[1].asInteger;
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\gate, 0);
            });
        });
        
        this.addCommand(\setFaderPos, "if", { arg msg;
            var voice = msg[1].asInteger;
            var pos = msg[2].asFloat;
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\faderPos, pos);
            });
        });
        
        // Sample loading with mono-to-stereo conversion
        this.addCommand(\loadSample, "s", { arg msg;
            var path = msg[1].asString;
            var soundFile, oldBuffer;

            postln("Engine loading sample: " ++ path);

            // Check file info first to detect mono vs stereo
            soundFile = SoundFile.new;
            if(soundFile.openRead(path), {
                var numChannels = soundFile.numChannels;
                var numFrames = soundFile.numFrames;
                var duration;

                soundFile.close;

                postln("Sample info: " ++ numChannels ++ " channels, " ++ numFrames ++ " frames, " ++ (numFrames / context.server.sampleRate) ++ "s");

                // Keep reference to old buffer (don't free yet - voices still using it)
                oldBuffer = buffer;

                // Handle mono files: read mono channel into both buffer channels
                if(numChannels == 1, {
                    postln("Loading mono file (will be converted to stereo during playback)...");

                    // Use Buffer.readChannel class method to allocate and read in one operation
                    // channels: [0, 0] means read source channel 0 into both dest channels 0 and 1
                    buffer = Buffer.readChannel(context.server, path, 0, -1, [0, 0], { arg buf;
                        duration = buf.numFrames / context.server.sampleRate;
                        postln("Mono sample loaded: " ++ path);
                        postln("Buffer frames=" ++ buf.numFrames ++ " channels=" ++ buf.numChannels ++ " Duration=" ++ duration ++ "s");

                        // Update all voice synths with new buffer number
                        8.do({ arg i;
                            synths[i].set(\bufnum, buf.bufnum);
                        });

                        // Now safe to free old buffer (voices updated to new buffer)
                        oldBuffer.free;

                        // Send duration to Lua via OSC (use NetAddr for norns)
                        NetAddr("localhost", 10111).sendMsg("/sample_duration", duration);

                        // Trigger waveform generation
                        this.generateWaveform(buf);
                    });
                }, {
                    // Stereo file: read normally
                    postln("Loading stereo file...");
                    buffer = Buffer.read(context.server, path, action: { arg buf;
                        duration = buf.numFrames / context.server.sampleRate;
                        postln("Stereo sample loaded: " ++ path);
                        postln("Buffer frames=" ++ buf.numFrames ++ " channels=" ++ buf.numChannels ++ " Duration=" ++ duration ++ "s");

                        // Update all voice synths with new buffer number
                        8.do({ arg i;
                            synths[i].set(\bufnum, buf.bufnum);
                        });

                        // Now safe to free old buffer (voices updated to new buffer)
                        oldBuffer.free;

                        // Send duration to Lua via OSC (use NetAddr for norns)
                        NetAddr("localhost", 10111).sendMsg("/sample_duration", duration);

                        // Trigger waveform generation
                        this.generateWaveform(buf);
                    });
                });
            }, {
                postln("ERROR: Could not open file: " ++ path);
            });
        });
        
        // Sample parameters
        this.addCommand(\setLoopPoints, "ff", { arg msg;
            var loopStart = msg[1].asFloat;
            var loopEnd = msg[2].asFloat;
            8.do({ arg i;
                synths[i].set(\loopStart, loopStart, \loopEnd, loopEnd);
            });
        });
        
        this.addCommand(\setSpeed, "f", { arg msg;
            var speed = msg[1].asFloat;
            8.do({ arg i;
                synths[i].set(\speed, speed);
            });
        });
        
        this.addCommand(\setReverse, "i", { arg msg;
            var reverse = msg[1].asInteger;
            8.do({ arg i;
                synths[i].set(\reverse, reverse);
            });
        });
        
        // Per-voice filter
        this.addCommand(\setVoiceFilterOffset, "if", { arg msg;
            var voice = msg[1].asInteger;
            var offset = msg[2].asFloat;
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\filterOffset, offset);
            });
        });
        
        // Master filter
        this.addCommand(\setMasterFilter, "ffi", { arg msg;
            var cutoff = msg[1].asFloat;
            var resonance = msg[2].asFloat;
            var filterType = msg[3].asInteger;
            filterGroup.set(\cutoff, cutoff, \resonance, resonance, \filterType, filterType);
        });
        
        this.addCommand(\setFilterDrive, "f", { arg msg;
            var drive = msg[1].asFloat;
            filterGroup.set(\drive, drive);
        });
        
        // LFO control
        this.addCommand(\setLFO, "ifff", { arg msg;
            var lfoNum = msg[1].asInteger;
            var rate = msg[2].asFloat;
            var depth = msg[3].asFloat;
            var shape = msg[4].asFloat;
            if(lfoNum >= 0 and: { lfoNum < 3 }, {
                lfos[lfoNum].set(\rate, rate, \depth, depth, \shape, shape);
            });
        });

        // Reverb control
        this.addCommand(\setReverbMix, "f", { arg msg;
            var mix = msg[1].asFloat.clip(0.0, 1.0);
            reverbSynth.set(\mix, mix);
        });

        this.addCommand(\setReverbTime, "f", { arg msg;
            var time = msg[1].asFloat.clip(0.1, 10.0);
            // Map time (0.1-10s) to delayTime parameter (0.001-2.0)
            // Use exponential mapping for more natural control
            var delayTime = time.linexp(0.1, 10.0, 0.01, 2.0);
            reverbSynth.set(\delayTime, delayTime);
        });

        this.addCommand(\setReverbSize, "f", { arg msg;
            var size = msg[1].asFloat.clip(0.5, 5.0);
            reverbSynth.set(\size, size);
        });

        this.addCommand(\setReverbDamping, "f", { arg msg;
            var damping = msg[1].asFloat.clip(0.0, 1.0);
            reverbSynth.set(\damping, damping);
        });

        this.addCommand(\setReverbFeedback, "f", { arg msg;
            var feedback = msg[1].asFloat.clip(0.0, 1.0);
            reverbSynth.set(\feedback, feedback);
        });

        this.addCommand(\setReverbDiff, "f", { arg msg;
            var diff = msg[1].asFloat.clip(0.0, 1.0);
            reverbSynth.set(\diff, diff);
        });

        this.addCommand(\setReverbModDepth, "f", { arg msg;
            var modDepth = msg[1].asFloat.clip(0.0, 1.0);
            reverbSynth.set(\modDepth, modDepth);
        });

        this.addCommand(\setReverbModFreq, "f", { arg msg;
            var modFreq = msg[1].asFloat.clip(0.1, 10.0);
            reverbSynth.set(\modFreq, modFreq);
        });

        this.addCommand(\setMasterAmp, "f", { arg msg;
            var amp = msg[1].asFloat.clip(0.0, 1.0);
            reverbSynth.set(\amp, amp);
        });

        // Voice parameters
        this.addCommand(\setVoiceAmp, "if", { arg msg;
            var voice = msg[1].asInteger;
            var amp = msg[2].asFloat;
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\amp, amp);
            });
        });
        
        this.addCommand(\setVoicePan, "if", { arg msg;
            var voice = msg[1].asInteger;
            var pan = msg[2].asFloat;
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\pan, pan);
            });
        });
        
        // Voice envelope control
        this.addCommand(\setVoiceEnvelope, "iffff", { arg msg;
            var voice = msg[1].asInteger;
            var attack = msg[2].asFloat;
            var decay = msg[3].asFloat;
            var sustain = msg[4].asFloat;
            var release = msg[5].asFloat;
            if(voice >= 0 and: { voice < 8 }, {
                synths[voice].set(\attack, attack, \decay, decay, \sustain, sustain, \release, release);
            });
        });

        // Envelope to filter modulation
        this.addCommand(\setEnvFilterMod, "f", { arg msg;
            var envFilterMod = msg[1].asFloat.clip(0.0, 1.0);
            // Apply to all voices
            8.do({ arg i;
                synths[i].set(\envFilterMod, envFilterMod * 10000);  // 0-10kHz range
            });
        });
        
        // Crossfade time control
        this.addCommand(\setXfadeTime, "f", { arg msg;
            var xfadeTime = msg[1].asFloat;
            8.do({ arg i;
                synths[i].set(\xfadeTime, xfadeTime);
            });
        });
        
        // Recording commands (placeholder - softcut would be better for actual implementation)
        this.addCommand(\startRecording, "s", { arg msg;
            var path = msg[1].asString;
            postln("Recording start requested: " ++ path);
            // TODO: Implement with softcut or RecordBuf
        });
        
        this.addCommand(\stopRecording, "", { arg msg;
            postln("Recording stop requested");
            // TODO: Implement recording stop
        });
        
        // Input monitoring commands
        this.addCommand(\startInputMonitor, "", { arg msg;
            // Stop existing monitor if any
            if(monitorSynth.notNil, {
                monitorSynth.free;
            });

            // Reset peak buses to zero
            peakBusL.set(0);
            peakBusR.set(0);

            // Start monitoring synth with peak tracking
            monitorSynth = Synth(\inputMonitor, [
                \peakBusL, peakBusL.index,
                \peakBusR, peakBusR.index
            ], masterGroup);

            postln("Input monitoring started (peak tracking)");
        });

        this.addCommand(\stopInputMonitor, "", { arg msg;
            // Free monitor synth
            if(monitorSynth.notNil, {
                monitorSynth.free;
                monitorSynth = nil;
            });
            postln("Input monitoring stopped");
        });

        // Get accumulated recording levels
        this.addCommand(\getRecordingLevels, "", { arg msg;
            // Read peak values from control buses
            peakBusL.get({ arg peakL;
                peakBusR.get({ arg peakR;
                    postln("Recording peaks: L=" ++ peakL ++ " R=" ++ peakR);

                    // Send levels to Lua via OSC
                    NetAddr("localhost", 10111).sendMsg("/recording_levels", peakL, peakR);
                });
            });
        });
    }
    
    // Generate waveform data for display (method defined OUTSIDE addCommands)
    // Pass optional numFrames to use actual file size instead of buffer size
    generateWaveform { arg buf, numFrames;
        var numSamples = 128; // Display resolution
        var step, peaks, framesToUse;

        // Use provided numFrames or fall back to buffer size
        framesToUse = numFrames ?? buf.numFrames;

        if(framesToUse > 0, {
            step = framesToUse / numSamples;
            
            // Read buffer and find peaks for each display segment
            buf.loadToFloatArray(action: { arg array;
                var waveform, maxPeak, normalizedWaveform;
                
                // Calculate raw peaks for each segment
                waveform = Array.fill(numSamples, { arg i;
                    var startIdx = (i * step).asInteger;
                    var endIdx = ((i + 1) * step).asInteger.min(array.size - 1);
                    var segment = array[startIdx..endIdx];
                    var peak = segment.abs.maxItem ? 0;
                    peak;
                });
                
                // Find maximum peak across all segments
                maxPeak = waveform.maxItem;
                
                // Normalize to 0-1 range (avoid divide by zero)
                if(maxPeak > 0, {
                    normalizedWaveform = waveform / maxPeak;
                }, {
                    normalizedWaveform = waveform;  // Silent sample, keep as-is
                });
                
                // Send normalized waveform data to Lua via OSC
                NetAddr("localhost", 10111).sendMsg('/waveform', *normalizedWaveform);
                postln("Waveform data sent: " ++ numSamples ++ " points (peak: " ++ maxPeak ++ ")");
            });
        });
    }
    
    free {
        synths.do(_.free);
        lfos.do(_.free);
        if(monitorSynth.notNil, { monitorSynth.free; });
        reverbSynth.free;
        voiceGroup.free;
        filterGroup.free;
        masterGroup.free;
        buffer.free;
        voiceBus.free;
        filterBus.free;
        peakBusL.free;
        peakBusR.free;
    }
}
