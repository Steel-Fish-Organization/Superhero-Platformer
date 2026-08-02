#!/usr/bin/env python3
"""Placeholder chiptune SFX and music for Superhero Platformer.

    python tools/gen_audio.py

Writes 16-bit mono WAVs into assets/audio/sfx and assets/audio/music. AudioManager
looks sounds up by filename, so dropping a real recording in with the same name
replaces it with no code change. Names come from the play_sfx()/play_music()
calls across the project -- see docs/AUDIO.md.
"""

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 22050


# --------------------------------------------------------------------------
# oscillators & envelopes
# --------------------------------------------------------------------------
def square(t, freq, duty=0.5):
    if freq <= 0:
        return 0.0
    phase = (t * freq) % 1.0
    return 1.0 if phase < duty else -1.0


def triangle(t, freq):
    if freq <= 0:
        return 0.0
    phase = (t * freq) % 1.0
    return 4.0 * abs(phase - 0.5) - 1.0


def noise(_t, _freq=0.0):
    return random.uniform(-1.0, 1.0)


def env_ad(pos, attack=0.01, decay=1.0, power=1.0):
    """0..1 envelope: linear attack then exponential-ish decay."""
    if pos < attack:
        return pos / attack if attack > 0 else 1.0
    d = (pos - attack) / max(decay, 1e-6)
    return max(0.0, (1.0 - d)) ** power


def render(duration, fn, volume=0.5):
    n = int(RATE * duration)
    out = []
    for i in range(n):
        t = i / RATE
        out.append(max(-1.0, min(1.0, fn(t, i / max(n - 1, 1)) * volume)))
    return out


def save_wav(rel_path, samples):
    path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(s * 32000)) for s in samples)
        w.writeframes(frames)
    print("  wrote", rel_path, f"({len(samples)/RATE:.2f}s)")


# --------------------------------------------------------------------------
# sound effects
# --------------------------------------------------------------------------
def sweep(dur, f0, f1, wave_fn=square, duty=0.5, power=1.0, vol=0.45, attack=0.005):
    """Pitch-swept blip -- the workhorse for shots, jumps and menu beeps."""
    def fn(t, pos):
        freq = f0 + (f1 - f0) * pos
        amp = env_ad(pos, attack, 1.0, power)
        if wave_fn is square:
            return square(t, freq, duty) * amp
        return wave_fn(t, freq) * amp
    return render(dur, fn, vol)


def burst(dur, cutoff_start=1.0, vol=0.5, power=2.0):
    """Filtered-ish noise for explosions and landings."""
    state = [0.0]

    def fn(_t, pos):
        raw = noise(0)
        # cheap one-pole low pass that closes over time
        k = cutoff_start * (1.0 - pos * 0.85)
        state[0] += (raw - state[0]) * max(k, 0.02)
        return state[0] * env_ad(pos, 0.002, 1.0, power)
    return render(dur, fn, vol)


def chord(dur, freqs, vol=0.35, duty=0.5, power=1.4):
    def fn(t, pos):
        acc = 0.0
        for f in freqs:
            acc += square(t, f, duty)
        return (acc / len(freqs)) * env_ad(pos, 0.01, 1.0, power)
    return render(dur, fn, vol)


def sequence(notes, note_len=0.08, vol=0.4, duty=0.5, wave_fn=square):
    """notes: list of frequencies (0 = rest)."""
    out = []
    for f in notes:
        out.extend(render(note_len, lambda t, pos, f=f: (
            0.0 if f <= 0 else wave_fn(t, f, duty) if wave_fn is square else wave_fn(t, f)
        ) * env_ad(pos, 0.005, 1.0, 0.8), vol))
    return out


SFX = {}


def build_sfx():
    # --- weapons ---------------------------------------------------------
    SFX["shoot"] = sweep(0.10, 1200, 420, duty=0.25, power=1.6, vol=0.35)
    SFX["shoot_mid"] = sweep(0.16, 900, 260, duty=0.35, power=1.4, vol=0.42)
    SFX["shoot_full"] = sweep(0.28, 700, 140, duty=0.5, power=1.2, vol=0.5)
    SFX["enemy_shoot"] = sweep(0.12, 500, 220, duty=0.5, power=1.5, vol=0.3)
    SFX["charge_loop"] = sweep(0.18, 300, 620, duty=0.25, power=0.6, vol=0.22)
    SFX["charge_ready"] = sweep(0.16, 620, 980, duty=0.25, power=0.6, vol=0.28)

    # --- impacts ---------------------------------------------------------
    SFX["hit"] = burst(0.09, 0.9, vol=0.35, power=2.5)
    SFX["hit_big"] = burst(0.16, 0.7, vol=0.45, power=2.0)
    SFX["deflect"] = sweep(0.07, 1800, 900, duty=0.5, power=3.0, vol=0.3)
    SFX["explode"] = burst(0.42, 0.55, vol=0.55, power=1.6)

    # --- player ----------------------------------------------------------
    SFX["jump"] = sweep(0.13, 380, 900, duty=0.25, power=1.2, vol=0.32)
    SFX["land"] = burst(0.07, 0.4, vol=0.3, power=3.0)
    SFX["slide"] = burst(0.22, 0.85, vol=0.28, power=1.2)
    SFX["hurt"] = sweep(0.28, 520, 120, duty=0.5, power=1.0, vol=0.45)
    SFX["player_death"] = sweep(0.55, 900, 60, duty=0.5, power=0.9, vol=0.5)
    SFX["hop"] = sweep(0.09, 300, 640, duty=0.25, power=1.5, vol=0.25)

    # --- items & ui ------------------------------------------------------
    SFX["pickup"] = sequence([1046, 1568], 0.045, vol=0.32, duty=0.25)
    SFX["heal"] = sequence([784, 988, 1318], 0.05, vol=0.3, duty=0.25)
    SFX["one_up"] = sequence([523, 659, 784, 1046, 1318], 0.06, vol=0.35, duty=0.25)
    SFX["denied"] = sweep(0.14, 220, 160, duty=0.5, power=1.6, vol=0.35)
    SFX["menu_move"] = sweep(0.05, 900, 1200, duty=0.25, power=2.0, vol=0.25)
    SFX["menu_confirm"] = sequence([880, 1318], 0.06, vol=0.35, duty=0.25)
    SFX["pause"] = sweep(0.09, 1400, 700, duty=0.25, power=1.8, vol=0.3)
    SFX["bar_fill"] = sweep(0.035, 1500, 1500, duty=0.25, power=2.5, vol=0.22)
    SFX["door"] = burst(0.3, 0.3, vol=0.35, power=1.2)

    # --- boss ------------------------------------------------------------
    SFX["boss_appear"] = sweep(0.5, 120, 480, duty=0.5, power=0.8, vol=0.45)
    SFX["boss_jump"] = sweep(0.18, 260, 700, duty=0.5, power=1.2, vol=0.4)
    SFX["boss_slam"] = burst(0.35, 0.35, vol=0.6, power=1.4)
    SFX["boss_enrage"] = sweep(0.4, 700, 250, duty=0.5, power=0.9, vol=0.45)

    # --- stingers --------------------------------------------------------
    SFX["stage_clear"] = sequence([523, 659, 784, 1046, 784, 1046, 1318], 0.11,
                                  vol=0.38, duty=0.25)
    SFX["game_over"] = sequence([440, 415, 392, 370, 349, 0, 262], 0.16,
                                vol=0.38, duty=0.5)

    for name, samples in SFX.items():
        save_wav(f"assets/audio/sfx/{name}.wav", samples)


# --------------------------------------------------------------------------
# music -- short loops built from a bass line and a lead arpeggio
# --------------------------------------------------------------------------
NOTE = {
    "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
    "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}


def hz(name, octave):
    return 440.0 * (2.0 ** ((NOTE[name] + (octave - 4) * 12 - 9) / 12.0))


def track(bass, lead, bpm=140, bars=4, vol=0.30):
    """bass/lead are lists of (note, octave) or None, one entry per 1/8 note."""
    step = 60.0 / bpm / 2.0
    total = step * len(lead) * bars
    n = int(RATE * total)
    out = [0.0] * n

    def place(seq, wave_fn, duty, amp, decay_power):
        for repeat in range(bars):
            for i, note in enumerate(seq):
                if note is None:
                    continue
                start = (repeat * len(seq) + i) * step
                freq = hz(note[0], note[1])
                length = step * 0.92
                s0 = int(start * RATE)
                for k in range(int(length * RATE)):
                    if s0 + k >= n:
                        break
                    t = (s0 + k) / RATE
                    pos = k / (length * RATE)
                    e = env_ad(pos, 0.01, 1.0, decay_power)
                    if wave_fn is square:
                        out[s0 + k] += square(t, freq, duty) * e * amp
                    else:
                        out[s0 + k] += wave_fn(t, freq) * e * amp

    place(bass, triangle, 0.5, 0.55, 0.8)
    place(lead, square, 0.25, 0.32, 1.2)
    return [max(-1.0, min(1.0, s * vol)) for s in out]


def build_music():
    # driving stage theme
    bass = [("A", 2), None, ("A", 2), None, ("E", 2), None, ("G", 2), None,
            ("F", 2), None, ("F", 2), None, ("C", 3), None, ("E", 2), None]
    lead = [("A", 4), ("C", 5), ("E", 5), ("C", 5), ("A", 4), ("E", 5), ("G", 5), ("E", 5),
            ("F", 4), ("A", 4), ("C", 5), ("A", 4), ("G", 4), ("B", 4), ("D", 5), ("B", 4)]
    save_wav("assets/audio/music/stage.wav", track(bass, lead, bpm=150, bars=4))

    # tense boss theme
    b2 = [("D", 2), ("D", 2), ("D", 2), None, ("A#", 1), None, ("C", 2), None,
          ("D", 2), ("D", 2), ("F", 2), None, ("E", 2), None, ("A", 1), None]
    l2 = [("D", 5), ("F", 5), ("A", 5), ("F", 5), ("D", 5), ("A#", 4), ("D", 5), ("F", 5),
          ("E", 5), ("G", 5), ("A#", 5), ("G", 5), ("E", 5), ("C", 5), ("A", 4), None]
    save_wav("assets/audio/music/boss.wav", track(b2, l2, bpm=168, bars=4, vol=0.32))

    # heroic title
    b3 = [("C", 2), None, None, None, ("G", 2), None, None, None,
          ("A", 2), None, None, None, ("F", 2), None, None, None]
    l3 = [("C", 5), None, ("E", 5), None, ("G", 5), None, ("E", 5), None,
          ("A", 4), None, ("C", 5), None, ("F", 4), None, ("A", 4), None]
    save_wav("assets/audio/music/title.wav", track(b3, l3, bpm=112, bars=4, vol=0.28))

    # calm select screen
    b4 = [("F", 2), None, ("C", 3), None, ("D", 2), None, ("A", 2), None,
          ("A#", 2), None, ("F", 2), None, ("C", 3), None, ("G", 2), None]
    l4 = [("F", 4), ("A", 4), ("C", 5), ("A", 4), ("D", 5), ("A", 4), ("F", 4), ("A", 4),
          ("A#", 4), ("D", 5), ("F", 5), ("D", 5), ("C", 5), ("G", 4), ("E", 4), None]
    save_wav("assets/audio/music/stage_select.wav", track(b4, l4, bpm=124, bars=4, vol=0.26))

    # ending
    b5 = [("C", 2), None, None, None, ("A", 2), None, None, None,
          ("F", 2), None, None, None, ("G", 2), None, None, None]
    l5 = [("E", 5), None, ("D", 5), None, ("C", 5), None, ("E", 5), None,
          ("F", 5), None, ("E", 5), None, ("D", 5), None, ("G", 4), None]
    save_wav("assets/audio/music/ending.wav", track(b5, l5, bpm=96, bars=4, vol=0.26))


def main():
    random.seed(7)
    print("Generating placeholder audio ...")
    build_sfx()
    build_music()
    print("Done.")


if __name__ == "__main__":
    main()
