class_name Sfx
extends RefCounted
## Procedural sound synthesis for Oh Captain.
##
## Every sound in the game is generated here at startup as an AudioStreamWAV,
## so the project ships no audio binaries and a sound stays readable code: a
## ping is a falling sine with an exponential tail, a coin is two short sines.
## Buffers are 16-bit mono PCM, built by hand in a PackedByteArray.
##
## Each generator returns one AudioStreamWAV. They are generated once and
## cached by AudioDirector; never call these per playback.

const MIX_RATE := 44100

## Seeded so a given build always sounds identical run to run.
const SEED := 20260906


## Wraps a float buffer in a 16-bit mono AudioStreamWAV, optionally looping.
##
## `ceiling` is a safety net, not a normaliser: layers that sum past it (the
## ping's body plus its echo, a reef impact's noise plus its ring) get scaled
## down to fit rather than hard clipping, while anything already quieter keeps
## its level, so the relative balance survives.
static func make(samples: PackedFloat32Array, loop: bool = false, ceiling := 0.88) -> AudioStreamWAV:
	var peak := 0.0
	for i in samples.size():
		peak = maxf(peak, absf(samples[i]))
	if peak > ceiling:
		var gain := ceiling / peak
		for i in samples.size():
			samples[i] *= gain

	var stream := AudioStreamWAV.new()
	stream.mix_rate = MIX_RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false

	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		# Manual clamp then two's complement: encode_s16 wraps silently, and a
		# wrapped sample is a loud click rather than a quiet clip.
		var v := int(roundf(samples[i] * 32767.0))
		v = clampi(v, -32768, 32767)
		if v < 0:
			v += 65536
		bytes.encode_s16(i * 2, v)
	stream.data = bytes

	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	return buf


static func rng(seed_offset: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = SEED + seed_offset
	return r


## Exponential decay with a short click-free attack, so nothing starts on a
## discontinuity.
static func env(t: float, attack: float, tau: float) -> float:
	var a := 1.0
	if attack > 0.0 and t < attack:
		a = t / attack
	return a * exp(-t / tau)


## One-pole lowpass, run in place. Cheap, and enough to take the fizz off noise.
static func lowpass(buf: PackedFloat32Array, cutoff: float) -> void:
	var dt := 1.0 / float(MIX_RATE)
	var rc := 1.0 / (TAU * maxf(cutoff, 1.0))
	var alpha := dt / (rc + dt)
	var y := 0.0
	for i in buf.size():
		y += (buf[i] - y) * alpha
		buf[i] = y


# --- Sonar -------------------------------------------------------------------

## The ping: a bright falling tone with a long tail, plus a quieter repeat
## offset in time to suggest the echo travelling back.
static func ping() -> AudioStreamWAV:
	var seconds := 1.2
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var echo := PackedFloat32Array()
	echo.resize(n)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		# Exponential glide reads as falling; a linear one sounds like a slide
		# whistle.
		var freq := 420.0 + 1080.0 * exp(-t * 5.5)
		buf[i] = sin(TAU * freq * t) * env(t, 0.004, 0.30)
		# Second harmonic keeps it from sounding like a test tone.
		buf[i] += sin(TAU * freq * 2.0 * t) * env(t, 0.004, 0.20) * 0.30

	lowpass(buf, 5200.0)

	# Echo: the same sweep again, quieter and later.
	var delay := int(0.16 * MIX_RATE)
	for i in range(delay, n):
		var t := float(i - delay) / float(MIX_RATE)
		echo[i] = sin(TAU * (420.0 + 1080.0 * exp(-t * 5.5)) * t) \
			* env(t, 0.004, 0.34) * 0.22
	lowpass(echo, 2600.0)

	for i in n:
		buf[i] = clampf(buf[i] + echo[i], -1.0, 1.0)
	return make(buf)


# --- Contact blips -----------------------------------------------------------

## Blips are keyed to species and state so a returning contact is identifiable
## without looking: high and soft for a drifting fish, low and urgent for an
## angry crab.
static func contact_blip(voice: Species.Profile, state: int) -> AudioStreamWAV:
	var seconds := 0.26
	var n := buffer(seconds).size()
	var buf := buffer(seconds)

	var base := voice.blip_hz
	var rise := 0.0
	var dur := 0.09
	var amp := 0.55
	var harmonic := 0.15
	var cutoff := 4200.0
	match state:
		1:
			# Alerted: rising chirp, repeated.
			rise = 420.0
			dur = 0.11
			amp = 0.5
			harmonic = 0.2
		2:
			# Hostile: lower, harder, with an odd partial for grit.
			base *= voice.blip_hostile_scale
			dur = 0.15
			amp = 0.6
			harmonic = 0.4
		3:
			# Fleeing: falls away and quietens, so a contact on the retreat
			# sounds like it is leaving rather than closing.
			rise = -240.0
			dur = 0.17
			amp = 0.4
			harmonic = 0.1
			cutoff = 2800.0

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := base + rise * t
		var s := sin(TAU * freq * t) + sin(TAU * freq * 3.0 * t) * harmonic
		buf[i] = s * env(t, 0.002, dur) * amp

	if state == 1:
		# Second, higher tap so an alert blip is audibly not a passive one.
		var offset := int(0.11 * MIX_RATE)
		for i in range(offset, n):
			var t := float(i - offset) / float(MIX_RATE)
			buf[i] += sin(TAU * (base + rise * t + 260.0) * t) \
				* env(t, 0.002, 0.07) * 0.4
		lowpass(buf, 6000.0)
	else:
		lowpass(buf, cutoff)
	return make(buf)


# --- Torpedo -----------------------------------------------------------------

## Launch: a hiss with a falling body under it, like air moving past the hull.
static func torpedo_launch() -> AudioStreamWAV:
	var seconds := 0.45
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(1)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var noise := r.randf() * 2.0 - 1.0
		var body := sin(TAU * (760.0 - 520.0 * t / seconds) * t)
		buf[i] = (noise * 0.5 + body * 0.35) * env(t, 0.012, 0.16)
	lowpass(buf, 2400.0)
	lowpass(buf, 2400.0)
	return make(buf)


## Impact on flesh: a wet low thump, almost no high end.
static func torpedo_hit_flesh() -> AudioStreamWAV:
	var seconds := 0.3
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(2)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var noise := r.randf() * 2.0 - 1.0
		var thump := sin(TAU * (150.0 - 70.0 * t / seconds) * t)
		buf[i] = (thump * 0.8 + noise * 0.35) * env(t, 0.003, 0.09)
	lowpass(buf, 700.0)
	return make(buf)


## Impact on rock: brighter, harder, shorter. Must not be mistakable for a hit.
static func torpedo_hit_reef() -> AudioStreamWAV:
	var seconds := 0.24
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(3)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var noise := r.randf() * 2.0 - 1.0
		var ring := sin(TAU * 1450.0 * t) + sin(TAU * 2130.0 * t) * 0.5
		buf[i] = (noise * 0.55 + ring * 0.4) * env(t, 0.001, 0.055)
	return make(buf)


# --- Hull --------------------------------------------------------------------

## Damage: a dull crunch with a downward slide, deliberately not a spike, since
## it can fire several times in quick succession.
static func damage() -> AudioStreamWAV:
	var seconds := 0.4
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(4)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var noise := r.randf() * 2.0 - 1.0
		var groan := sin(TAU * (190.0 - 120.0 * t / seconds) * t)
		buf[i] = (groan * 0.7 + noise * 0.5) * env(t, 0.004, 0.13)
	lowpass(buf, 1100.0)
	return make(buf)


# --- Enemies -----------------------------------------------------------------

## Swimming: a soft filtered swell. Quiet enough to sit under the mix as
## texture, loud enough to be the only warning that something is nearby.
static func swim() -> AudioStreamWAV:
	var seconds := 0.55
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(5)

	for i in n:
		buf[i] = r.randf() * 2.0 - 1.0
	# One pole smooths into a wash; a second shapes it into a body of water.
	lowpass(buf, 900.0)
	lowpass(buf, 500.0)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var swell := sin(PI * clampf(t / seconds, 0.0, 1.0))
		buf[i] *= swell * swell * 0.5
	return make(buf)


## The cry when something realises the hull is there. Rising and questioning,
## so it reads as "where did that come from" rather than an attack.
static func cry_alert(voice: Species.Profile) -> AudioStreamWAV:
	var seconds := 0.34
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var base := voice.cry_alert_hz

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := base * (1.0 + 0.85 * t / seconds)
		buf[i] = (sin(TAU * freq * t) + sin(TAU * freq * 2.0 * t) * 0.25) \
			* env(t, 0.01, 0.11)
	lowpass(buf, 5200.0)
	return make(buf)


## The cry when it has actually seen you. Descending and harsh. A crab's is an
## octave and a half down and slower, which is what makes it read as heavier
## from across the map.
static func cry_hostile(voice: Species.Profile) -> AudioStreamWAV:
	var seconds := 0.5
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(6)
	var base := voice.cry_hostile_hz
	var sweep := voice.cry_hostile_sweep

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := base * (1.0 - sweep * t / seconds)
		var grit := r.randf() * 2.0 - 1.0
		var tone := sin(TAU * freq * t) + sin(TAU * freq * 2.7 * t) * 0.4
		buf[i] = (tone * 0.65 + grit * 0.2) * env(t, 0.006, 0.16)
	lowpass(buf, 7000.0)
	return make(buf)


# --- Pickups -----------------------------------------------------------------

## Gold: two rising notes, so collecting several makes a small arpeggio rather
## than one flat blip repeated.
static func gold() -> AudioStreamWAV:
	var seconds := 0.16
	var n := buffer(seconds).size()
	var buf := buffer(seconds)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		buf[i] = sin(TAU * 1320.0 * t) * env(t, 0.002, 0.035)
		buf[i] += sin(TAU * 1980.0 * t) * env(t, 0.055, 0.040) * 0.8
	return make(buf)


## Ammo crate: a lower, flatter double clunk. Deliberately the opposite shape to
## the coin's rising pair, so the two are distinguishable when they are collected
## in the same pass over a wreck.
static func ammo() -> AudioStreamWAV:
	var seconds := 0.18
	var n := buffer(seconds).size()
	var buf := buffer(seconds)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		buf[i] = sin(TAU * 520.0 * t) * env(t, 0.002, 0.038)
		buf[i] += sin(TAU * 392.0 * t) * env(t, 0.062, 0.045) * 0.9
	lowpass(buf, 2600.0)
	return make(buf)


# --- End of run --------------------------------------------------------------

static func game_over() -> AudioStreamWAV:
	var seconds := 1.8
	var n := buffer(seconds).size()
	var buf := buffer(seconds)

	for i in n:
		var t := float(i) / float(MIX_RATE)
		var freq := 380.0 - 300.0 * (t / seconds)
		buf[i] = (sin(TAU * freq * t) + sin(TAU * freq * 1.5 * t) * 0.3) \
			* env(t, 0.02, 0.75)
	lowpass(buf, 1400.0)
	return make(buf)


# --- Ambience ----------------------------------------------------------------

## A deep loop. Every partial is an exact multiple of the buffer's own
## frequency, so each one completes a whole number of cycles and the loop point
## is inaudible. Adding anything not on that grid would click once per cycle.
static func ambient() -> AudioStreamWAV:
	var seconds := 4.0
	var n := buffer(seconds).size()
	var buf := buffer(seconds)
	var r := rng(7)
	var step := 1.0 / seconds

	# Partial index -> weight. Low, slightly detuned drone with a thin shimmer
	# far up top so it does not feel like one sine.
	var partials := [
		[160, 0.55], [216, 0.30], [288, 0.22], [320, 0.16],
		[432, 0.12], [481, 0.09], [742, 0.05], [1290, 0.03],
	]

	for p in partials:
		var hz := float(p[0]) * step
		var amp: float = float(p[1])
		var phase := r.randf() * TAU
		# Slow swell, also locked to the loop grid (4 cycles per buffer).
		var lfo_hz := step * float(r.randi_range(2, 5))
		var lfo_phase := r.randf() * TAU
		for i in n:
			var t := float(i) / float(MIX_RATE)
			var swell := 0.72 + 0.28 * sin(TAU * lfo_hz * t + lfo_phase)
			buf[i] += sin(TAU * hz * t + phase) * amp * swell

	# Fade the very edges so even if a partial were slightly off-grid the
	# discontinuity is inaudible.
	var fade := int(0.02 * MIX_RATE)
	for i in fade:
		var k := float(i) / float(fade)
		buf[i] *= k
		buf[n - 1 - i] *= k

	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	if peak > 0.0:
		var scale := 0.42 / peak
		for i in n:
			buf[i] *= scale
	return make(buf, true)
