#!/usr/bin/env python3
"""Volume (LUFS) de chaque effet sonore et gain qui le ramène au volume commun.
1. godot --headless --path . res://tools/export_sfx.tscn -- out=/tmp/sfx_wav   (effets synthétisés -> .wav)
2. python3 tools/sfx_levels.py /tmp/sfx_wav   (+ les fichiers de assets/sounds)
Les gains proposés se reportent dans Sound.SFX_GAIN_DB (clé = nom du son, « swing|épée », « spell|feu »…)."""
import re, subprocess, sys, glob, os, statistics

def lufs(path):
    # le son est prolongé par du silence jusqu'à 1 s : la mesure EBU R128 exige au moins 400 ms
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', path, '-af', 'apad=whole_dur=1,ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True)
    m = re.findall(r'I:\s+(-?[\d.]+) LUFS', r.stderr)
    pk = re.findall(r'Peak:\s+(-?[\d.]+) dBFS', r.stderr)
    return (float(m[-1]), float(pk[-1])) if m and pk else None

def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sfx_wav'
    here = os.path.dirname(os.path.abspath(__file__))
    files = sorted(glob.glob(os.path.join(folder, '*.wav'))) + sorted(glob.glob(os.path.join(here, '..', 'assets', 'sounds', '*.ogg')))
    rows = []
    for f in files:
        r = lufs(f)
        if r is not None:
            rows.append((os.path.splitext(os.path.basename(f))[0], r[0], r[1]))
    synth = [v for n, v, p in rows if not os.path.exists(os.path.join(here, '..', 'assets', 'sounds', n + '.ogg'))]
    target = float(sys.argv[2]) if len(sys.argv) > 2 else round(statistics.median(synth), 1)
    print('Volume commun visé : %.1f LUFS (gain borné à -15 / +12 dB, crête finale <= -1 dBFS)' % target)
    for n, v, p in rows:
        g = max(-15.0, min(12.0, target - v))
        g = min(g, -1.0 - p)                 # jamais de saturation
        g = round(g * 2) / 2                 # par demi-décibel
        print('%-18s %6.1f LUFS  crête %5.1f dBFS   gain %+5.1f dB' % (n, v, p, g))

main()
