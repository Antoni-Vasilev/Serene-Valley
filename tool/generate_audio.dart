// ignore_for_file: avoid_print
// Synthesises the game's music, ambience and sound effects as WAV files in
// assets/audio, in the style of an 8-bit console.
//
// Run from the project root with:
//   dart run tool/generate_audio.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const rate = 22050;
const outDir = 'assets/audio';

// -----------------------------------------------------------------------------
// Waves, notes and envelopes

typedef Wave = double Function(double phase);

Wave square(double duty) => (p) => (p % 1) < duty ? 1.0 : -1.0;

double triangle(double p) {
  final x = p % 1;
  return x < 0.5 ? 4 * x - 1 : 3 - 4 * x;
}

double sine(double p) => sin(2 * pi * p);

final Float64List _noise = () {
  final r = Random(1);
  return Float64List.fromList([for (var i = 0; i < rate * 4; i++) r.nextDouble() * 2 - 1]);
}();

double noiseAt(int i) => _noise[i % _noise.length];

/// The frequency of a note like "C5", "F#3" or "Bb4".
double hz(String note) {
  const names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2};
  var semitones = names[note[0]]!;
  var i = 1;
  if (note[i] == '#') {
    semitones++;
    i++;
  } else if (note[i] == 'b') {
    semitones--;
    i++;
  }
  semitones += (int.parse(note.substring(i)) - 4) * 12;
  return 440.0 * pow(2, semitones / 12);
}

class Envelope {
  final double attack, decay, sustain, release;

  const Envelope(this.attack, this.decay, this.sustain, this.release);

  /// A quick hit that fades out over [decay] seconds.
  const Envelope.hit(double decay) : this(0.001, decay, 0, 0.005);

  double _level(double t) {
    if (t < attack) return t / attack;
    if (t < attack + decay) return 1 - (1 - sustain) * (t - attack) / decay;
    return sustain;
  }

  /// The level [t] seconds into a note held for [held] seconds.
  double at(double t, double held) {
    if (t < held) return _level(t);
    if (release <= 0) return 0;
    final r = (t - held) / release;
    return r >= 1 ? 0 : _level(held) * (1 - r);
  }
}

/// A mono track of samples in -1..1. In a looping track, sounds that run
/// past the end continue from the start, so the loop is seamless.
class Track {
  final Float64List samples;
  final bool loops;

  Track(double seconds, {this.loops = false}) : samples = Float64List((seconds * rate).round());

  int get length => samples.length;

  void add(int i, double v) {
    if (loops) {
      samples[i % length] += v;
    } else if (i >= 0 && i < length) {
      samples[i] += v;
    }
  }

  /// A note starting at [start] seconds, held for [held] seconds.
  void note(
    double start,
    double held,
    double freq,
    Wave wave,
    Envelope env,
    double volume, {
    double endFreq = 0,
    double vibrato = 0,
    double vibratoRate = 5.5,
  }) {
    final total = held + env.release;
    final n = (total * rate).round();
    final first = (start * rate).round();
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      var f = endFreq > 0 ? freq + (endFreq - freq) * min(1.0, t / total) : freq;
      // Vibrato eases in, like a singer's.
      if (vibrato > 0) f *= 1 + vibrato * sin(2 * pi * vibratoRate * t) * min(1.0, t / 0.2);
      phase += f / rate;
      add(first + i, wave(phase) * env.at(t, held) * volume);
    }
  }

  /// A burst of low-passed noise, or high-passed with [highPass].
  void noise(
    double start,
    double held,
    Envelope env,
    double volume, {
    double cutoff = 4000,
    double? endCutoff,
    bool highPass = false,
    int seed = 0,
  }) {
    final total = held + env.release;
    final n = (total * rate).round();
    final first = (start * rate).round();
    var low = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      final fc = endCutoff == null ? cutoff : cutoff + (endCutoff - cutoff) * (t / total);
      final x = noiseAt(seed * 7919 + first + i);
      low += (1 - exp(-2 * pi * fc / rate)) * (x - low);
      add(first + i, (highPass ? x - low : low) * env.at(t, held) * volume);
    }
  }

  /// Softens the track with a gentle low-pass filter.
  void lowPass(double cutoff) {
    final a = 1 - exp(-2 * pi * cutoff / rate);
    var y = 0.0;
    // Settle the filter on the end of a loop first, so the seam is smooth.
    if (loops) {
      for (final x in samples) {
        y += a * (x - y);
      }
    }
    for (var i = 0; i < length; i++) {
      y += a * (samples[i] - y);
      samples[i] = y;
    }
  }

  /// Scales the track so its loudest sample reaches [peak].
  void normalize(double peak) {
    var loudest = 0.0;
    for (final s in samples) {
      loudest = max(loudest, s.abs());
    }
    if (loudest == 0) return;
    for (var i = 0; i < length; i++) {
      samples[i] *= peak / loudest;
    }
  }
}

/// Plays a line like "E5.2 G5.2 r.2": each token is a note, or r for a rest,
/// and its length in eighth notes. Bar lines (|) are ignored.
void melody(String line, double eighth, void Function(double start, double length, String note) play) {
  var time = 0.0;
  for (final token in line.split(RegExp(r'\s+'))) {
    if (token.isEmpty || token == '|') continue;
    final [note, count] = token.split('.');
    final length = int.parse(count) * eighth;
    if (note != 'r') play(time, length, note);
    time += length;
  }
}

const chordNotes = {
  'C': ['C4', 'E4', 'G4'],
  'Am': ['A3', 'C4', 'E4'],
  'F': ['F3', 'A3', 'C4'],
  'G': ['G3', 'B3', 'D4'],
  'Em': ['E3', 'G3', 'B3'],
  'Dm': ['D3', 'F3', 'A3'],
  'E': ['E3', 'G#3', 'B3'],
  'A': ['A3', 'C#4', 'E4'],
  'Bb': ['Bb3', 'D4', 'F4'],
};
const bassRoot = {'C': 'C3', 'Am': 'A2', 'F': 'F2', 'G': 'G2', 'Em': 'E2', 'Dm': 'D3', 'E': 'E2', 'A': 'A2', 'Bb': 'Bb2'};
const bassFifth = {'C': 'G2', 'Am': 'E2', 'F': 'C3', 'G': 'D3', 'Em': 'B2', 'Dm': 'A2', 'E': 'B2', 'A': 'E2', 'Bb': 'F2'};

// -----------------------------------------------------------------------------
// Music

const dayLead = 'E5.2 G5.2 C6.3 B5.1 | A5.4 E5.2 G5.2 | F5.2 A5.2 C6.2 A5.2 | G5.6 r.2 | '
    'E5.2 G5.2 C6.2 D6.2 | E6.3 D6.1 B5.4 | A5.2 C6.2 B5.2 A5.2 | G5.6 r.2 | '
    'C6.2 B5.2 A5.2 E5.2 | F5.3 G5.1 A5.4 | G5.2 E5.2 C5.2 E5.2 | D5.6 r.2 | '
    'A5.2 G5.2 F5.2 A5.2 | G5.2 F5.2 E5.2 D5.2 | E5.3 D5.1 C5.4 | C5.4 r.4';
const dayBpm = 84.0;

/// A gentle tune in C major for daytime, about 46 seconds long.
Track dayMusic() {
  const eighth = 60 / dayBpm / 2;
  const bar = eighth * 8;
  const chords = ['C', 'Am', 'F', 'G', 'C', 'Em', 'F', 'G', 'Am', 'F', 'C', 'G', 'F', 'G', 'C', 'C'];
  final track = Track(bar * chords.length, loops: true);

  final lead = square(0.25);
  melody(dayLead, eighth, (start, length, note) {
    track.note(start, length * 0.9, hz(note), lead, const Envelope(0.01, 0.12, 0.6, 0.12), 0.17, vibrato: 0.006);
  });
  // A quiet echo of the tune gives it some space.
  final echo = square(0.125);
  melody(dayLead, eighth, (start, length, note) {
    track.note(start + eighth * 1.5, length * 0.8, hz(note), echo, const Envelope(0.01, 0.1, 0.5, 0.1), 0.045);
  });

  final arp = square(0.125);
  for (var b = 0; b < chords.length; b++) {
    final start = b * bar;
    final chord = chords[b];
    track.note(start, bar / 2 * 0.95, hz(bassRoot[chord]!), triangle, const Envelope(0.005, 0.1, 0.8, 0.06), 0.32);
    track.note(start + bar / 2, bar / 2 * 0.95, hz(bassFifth[chord]!), triangle, const Envelope(0.005, 0.1, 0.8, 0.06), 0.28);
    const pattern = [0, 1, 2, 1, 0, 1, 2, 1];
    for (var i = 0; i < 8; i++) {
      track.note(start + i * eighth, eighth * 0.55, hz(chordNotes[chord]![pattern[i]]), arp,
          const Envelope(0.003, 0.08, 0.25, 0.04), 0.045);
    }
    // A soft shaker on the off-beats.
    for (var i = 1; i < 8; i += 2) {
      track.noise(start + i * eighth, 0.012, const Envelope.hit(0.035), 0.06,
          cutoff: 6000, highPass: true, seed: b * 8 + i);
    }
  }
  track.lowPass(7000);
  track.normalize(0.7);
  return track;
}

const nightLead = 'E5.4 A4.2 C5.2 | A4.6 r.2 | G4.2 C5.2 E5.4 | D5.6 r.2 | '
    'E5.4 G5.2 E5.2 | F5.4 E5.2 C5.2 | D5.4 A4.4 | B4.6 r.2 | '
    'A4.2 C5.2 E5.2 A5.2 | G5.4 F5.2 E5.2 | E5.4 D5.2 C5.2 | D5.6 r.2 | '
    'F5.4 E5.2 D5.2 | E5.4 G#4.4 | A4.8 | r.8';
const nightBpm = 66.0;

/// A quiet lullaby in A minor for the night, about 58 seconds long.
Track nightMusic() {
  const eighth = 60 / nightBpm / 2;
  const bar = eighth * 8;
  const chords = ['Am', 'F', 'C', 'G', 'Am', 'F', 'Dm', 'E', 'Am', 'F', 'C', 'G', 'Dm', 'E', 'Am', 'Am'];
  final track = Track(bar * chords.length, loops: true);

  melody(nightLead, eighth, (start, length, note) {
    final f = hz(note);
    track.note(start, length * 0.92, f, triangle, const Envelope(0.03, 0.25, 0.55, 0.35), 0.26, vibrato: 0.004);
    track.note(start, length * 0.8, f * 2, sine, const Envelope(0.03, 0.2, 0.3, 0.3), 0.035);
  });

  for (var b = 0; b < chords.length; b++) {
    final start = b * bar;
    final notes = chordNotes[chords[b]]!;
    // A soft pad of the chord.
    for (final n in notes) {
      track.note(start, bar * 0.92, hz(n), sine, const Envelope(0.5, 0.3, 0.7, 0.6), 0.05);
    }
    track.note(start, bar * 0.95, hz(bassRoot[chords[b]]!), triangle, const Envelope(0.02, 0.2, 0.7, 0.3), 0.24);
    // A music box picking out the chord on beats one and three.
    for (final (beat, tone) in [(0, 0), (4, 2)]) {
      track.note(start + beat * eighth, 0.05, hz(notes[tone]) * 4, sine, const Envelope(0.002, 0.6, 0, 0.05), 0.06);
    }
  }
  track.lowPass(5000);
  track.normalize(0.62);
  return track;
}

const mineLead = 'D5.4 r.2 A4.2 | F5.4 E5.2 D5.2 | C5.6 r.2 | A4.8 | '
    'D5.4 r.2 F5.2 | G5.4 A5.2 G5.2 | F5.6 r.2 | E5.8 | '
    'F5.4 r.2 E5.2 | D5.4 C5.2 A4.2 | Bb4.4 C5.4 | D5.8';
const mineBpm = 66.0;

/// A slow, echoing tune in D minor for the old mine, about 44 seconds long.
Track mineMusic() {
  const eighth = 60 / mineBpm / 2;
  const bar = eighth * 8;
  const chords = ['Dm', 'Dm', 'C', 'Am', 'Dm', 'C', 'F', 'A', 'Dm', 'F', 'Bb', 'Dm'];
  final track = Track(bar * chords.length, loops: true);

  // The tune, with two fading echoes off the tunnel walls.
  melody(mineLead, eighth, (start, length, note) {
    final f = hz(note);
    track.note(start, length * 0.85, f, triangle, const Envelope(0.02, 0.3, 0.45, 0.4), 0.24, vibrato: 0.003);
    for (final (delay, volume) in const [(0.36, 0.07), (0.72, 0.03)]) {
      track.note(start + delay, length * 0.6, f, triangle, const Envelope(0.02, 0.2, 0.3, 0.3), volume);
    }
  });

  final r = Random(23);
  for (var b = 0; b < chords.length; b++) {
    final start = b * bar;
    final notes = chordNotes[chords[b]]!;
    // A low drone of the chord, swelling slowly.
    track.note(start, bar * 0.96, hz(bassRoot[chords[b]]!), sine, const Envelope(0.6, 0.4, 0.8, 0.8), 0.3);
    track.note(start, bar * 0.9, hz(bassFifth[chords[b]]!) * 2, sine, const Envelope(0.8, 0.4, 0.6, 0.8), 0.06);
    for (final n in notes) {
      track.note(start, bar * 0.92, hz(n), sine, const Envelope(0.8, 0.3, 0.6, 0.7), 0.035);
    }
    // Water dripping in tune, here and there.
    for (var i = 0; i < 2; i++) {
      final at = start + r.nextInt(8) * eighth + eighth / 2;
      final f = hz(notes[r.nextInt(notes.length)]) * 4;
      track.note(at, 0.03, f, sine, const Envelope(0.002, 0.35, 0, 0.05), 0.05, endFreq: f * 0.97);
      track.note(at + 0.3, 0.03, f, sine, const Envelope(0.002, 0.3, 0, 0.05), 0.02, endFreq: f * 0.97);
    }
  }
  track.lowPass(3500);
  track.normalize(0.6);
  return track;
}

// -----------------------------------------------------------------------------
// Ambience

/// Wind as slowly swelling, low-passed noise; the swell repeats every
/// [period] seconds, which must divide the track's length.
void wind(Track t, double volume, {double cutoff = 350, double period = 12}) {
  var low = 0.0;
  final a = 1 - exp(-2 * pi * cutoff / rate);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < t.length; i++) {
      low += a * (noiseAt(i + 50000) - low);
      if (pass == 1) {
        final swell = 0.65 + 0.35 * sin(2 * pi * i / (period * rate));
        t.samples[i] += low * swell * volume;
      }
    }
  }
}

Track dayAmbience() {
  final t = Track(24, loops: true);
  final r = Random(7);
  wind(t, 0.5);
  // Birdsong: little runs of rising chirps.
  for (var i = 0; i < 14; i++) {
    final start = r.nextDouble() * 24;
    final base = 2300 + r.nextDouble() * 1200;
    final chirps = 2 + r.nextInt(3);
    final volume = 0.10 + r.nextDouble() * 0.05;
    for (var c = 0; c < chirps; c++) {
      final f = base * (0.9 + r.nextDouble() * 0.2);
      t.note(start + c * (0.09 + r.nextDouble() * 0.04), 0.05, f, sine, const Envelope(0.005, 0.03, 0.4, 0.03), volume,
          endFreq: f * 1.35, vibrato: 0.03, vibratoRate: 30);
    }
  }
  t.normalize(0.5);
  return t;
}

Track nightAmbience() {
  final t = Track(24, loops: true);
  final r = Random(11);
  wind(t, 0.25, period: 8);
  // Crickets chirping in threes.
  for (var voice = 0; voice < 3; voice++) {
    final pitch = 4200 + voice * 230.0;
    var time = r.nextDouble();
    while (time < 24) {
      for (var p = 0; p < 3; p++) {
        t.note(time + p * 0.045, 0.012, pitch, sine, const Envelope(0.002, 0.008, 0.6, 0.006), 0.05);
      }
      time += 0.8 + r.nextDouble() * 0.5;
    }
  }
  // An owl, twice.
  for (final start in const [6.0, 17.0]) {
    t.note(start, 0.3, 370, sine, const Envelope(0.05, 0.1, 0.7, 0.15), 0.12);
    t.note(start + 0.55, 0.45, 330, sine, const Envelope(0.05, 0.1, 0.7, 0.2), 0.12);
  }
  t.normalize(0.45);
  return t;
}

Track mineAmbience() {
  final t = Track(24, loops: true);
  final r = Random(29);
  // A low hum of air moving through the tunnels.
  wind(t, 0.35, cutoff: 140, period: 12);
  // Drips, echoing off the walls.
  for (var i = 0; i < 26; i++) {
    final at = r.nextDouble() * 24;
    final f = 900 + r.nextDouble() * 1300;
    final volume = 0.12 + r.nextDouble() * 0.1;
    for (final (delay, fade) in const [(0.0, 1.0), (0.14, 0.35), (0.29, 0.12)]) {
      t.note(at + delay, 0.02, f, sine, const Envelope(0.001, 0.06, 0, 0.02), volume * fade, endFreq: f * 0.6);
    }
  }
  // Now and then a pebble skitters down somewhere far off.
  for (final at in const [7.5, 18.0]) {
    for (var i = 0; i < 4; i++) {
      t.noise(at + i * 0.09 + r.nextDouble() * 0.04, 0.003, const Envelope.hit(0.03), 0.25 - i * 0.04,
          cutoff: 1800, seed: 600 + i);
    }
  }
  t.normalize(0.5);
  return t;
}

Track river() {
  final t = Track(8, loops: true);
  final r = Random(13);
  var low = 0.0, lower = 0.0;
  final a = 1 - exp(-2 * pi * 1200 / rate);
  final b = 1 - exp(-2 * pi * 200 / rate);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < t.length; i++) {
      low += a * (noiseAt(i + 90000) - low);
      lower += b * (low - lower);
      if (pass == 1) {
        final swell = 0.75 + 0.15 * sin(2 * pi * i / (4 * rate)) + 0.1 * sin(2 * pi * i / (8 * rate));
        t.samples[i] += (low - lower) * swell;
      }
    }
  }
  // Bubbles.
  for (var i = 0; i < 30; i++) {
    final f = 700 + r.nextDouble() * 600;
    t.note(r.nextDouble() * 8, 0.02, f, sine, const Envelope.hit(0.03), 0.06, endFreq: f * 1.5);
  }
  t.normalize(0.5);
  return t;
}

Track fire() {
  final t = Track(6, loops: true);
  final r = Random(17);
  var low = 0.0;
  final a = 1 - exp(-2 * pi * 180 / rate);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < t.length; i++) {
      low += a * (noiseAt(i + 30000) - low);
      if (pass == 1) t.samples[i] += low * 1.5;
    }
  }
  // Crackles and the odd pop.
  for (var i = 0; i < 150; i++) {
    t.noise(r.nextDouble() * 6, 0.001, Envelope.hit(0.002 + r.nextDouble() * 0.004), 0.2 + r.nextDouble() * 0.6,
        cutoff: 2500, highPass: true, seed: i);
  }
  for (var i = 0; i < 6; i++) {
    t.noise(r.nextDouble() * 6, 0.002, const Envelope.hit(0.012), 1.0, cutoff: 1500, seed: 400 + i);
  }
  t.normalize(0.55);
  return t;
}

// -----------------------------------------------------------------------------
// Sound effects

Track sfx(double seconds, void Function(Track t) draw, {double peak = 0.7}) {
  final t = Track(seconds);
  draw(t);
  t.normalize(peak);
  return t;
}

void notes(Track t, List<String> names, double step, Wave wave, double volume, {double last = 0}) {
  for (var i = 0; i < names.length; i++) {
    final held = i == names.length - 1 && last > 0 ? last : step * 0.9;
    t.note(i * step, held, hz(names[i]), wave, const Envelope(0.002, 0.04, 0.5, 0.03), volume);
  }
}

Map<String, Track> effects() => {
      'chop': sfx(0.22, (t) {
        t.note(0, 0.12, 240, triangle, const Envelope.hit(0.12), 0.9, endFreq: 70);
        t.noise(0, 0.01, const Envelope.hit(0.06), 0.7, cutoff: 1800);
        t.note(0, 0.03, 120, square(0.5), const Envelope.hit(0.03), 0.25);
      }, peak: 0.8),
      'mine': sfx(0.22, (t) {
        t.note(0, 0.09, 1250, square(0.5), const Envelope.hit(0.09), 0.4);
        t.note(0, 0.07, 1880, square(0.5), const Envelope.hit(0.07), 0.25);
        t.noise(0, 0.005, const Envelope.hit(0.02), 0.5, cutoff: 3000, highPass: true);
        t.note(0.06, 0.06, 1500, square(0.5), const Envelope.hit(0.06), 0.2);
      }, peak: 0.6),
      'pickup': sfx(0.25, (t) => notes(t, ['C6', 'E6', 'G6'], 0.05, square(0.25), 0.5, last: 0.09), peak: 0.5),
      'splash': sfx(0.45, (t) {
        t.noise(0, 0.25, const Envelope(0.003, 0.25, 0.2, 0.1), 0.9, cutoff: 5000, endCutoff: 400);
        t.note(0, 0.1, 600, sine, const Envelope.hit(0.1), 0.4, endFreq: 250);
      }, peak: 0.7),
      'nibble': sfx(0.3, (t) {
        t.note(0, 0.12, 340, sine, const Envelope.hit(0.12), 0.6, endFreq: 260);
        t.note(0.12, 0.12, 300, sine, const Envelope.hit(0.12), 0.5, endFreq: 220);
      }, peak: 0.45),
      'pick': sfx(0.12, (t) {
        t.note(0, 0.07, 520, sine, const Envelope.hit(0.07), 0.8, endFreq: 980);
        t.noise(0, 0.002, const Envelope.hit(0.01), 0.2, cutoff: 4000, highPass: true);
      }, peak: 0.6),
      'eat': sfx(0.35, (t) {
        for (var i = 0; i < 3; i++) {
          t.noise(i * 0.1, 0.01, const Envelope.hit(0.05), 0.8, cutoff: 1400, seed: i);
          t.note(i * 0.1, 0.04, 180, triangle, const Envelope.hit(0.04), 0.4, endFreq: 120);
        }
      }, peak: 0.6),
      'step': sfx(0.07, (t) => t.noise(0, 0.005, const Envelope.hit(0.045), 1, cutoff: 900), peak: 0.35),
      'step_wood': sfx(0.08, (t) {
        t.note(0, 0.05, 170, triangle, const Envelope.hit(0.05), 0.8, endFreq: 110);
        t.noise(0, 0.003, const Envelope.hit(0.015), 0.4, cutoff: 2500);
      }, peak: 0.4),
      'open': sfx(0.1, (t) => notes(t, ['E5', 'B5'], 0.04, square(0.5), 0.5), peak: 0.3),
      'close': sfx(0.1, (t) => notes(t, ['B5', 'E5'], 0.04, square(0.5), 0.5), peak: 0.3),
      'blip_low': sfx(0.05, (t) => t.note(0, 0.03, 300, square(0.5), const Envelope(0.002, 0.025, 0.4, 0.015), 1),
          peak: 0.22),
      'blip_mid': sfx(0.05, (t) => t.note(0, 0.03, 450, square(0.5), const Envelope(0.002, 0.025, 0.4, 0.015), 1),
          peak: 0.2),
      'blip_high': sfx(0.05, (t) => t.note(0, 0.03, 680, square(0.5), const Envelope(0.002, 0.025, 0.4, 0.015), 1),
          peak: 0.18),
      'accept': sfx(0.5, (t) {
        t.note(0, 0.08, hz('G5'), square(0.25), const Envelope(0.005, 0.1, 0.6, 0.05), 0.5);
        t.note(0.1, 0.25, hz('C6'), square(0.25), const Envelope(0.005, 0.1, 0.6, 0.12), 0.5);
        t.note(0.1, 0.25, hz('C4'), triangle, const Envelope(0.005, 0.1, 0.7, 0.12), 0.45);
      }, peak: 0.6),
      'quest': sfx(1.1, (t) {
        notes(t, ['C5', 'E5', 'G5'], 0.07, square(0.25), 0.5);
        for (final (n, w) in [('C6', 0.25), ('E6', 0.125), ('G6', 0.125)]) {
          t.note(0.21, 0.45, hz(n), square(w), const Envelope(0.01, 0.2, 0.6, 0.3), 0.3);
        }
        t.note(0.21, 0.5, hz('C4'), triangle, const Envelope(0.01, 0.2, 0.7, 0.3), 0.5);
      }, peak: 0.7),
      'levelup': sfx(0.7, (t) {
        notes(t, ['C5', 'E5', 'G5', 'C6', 'E6', 'G6'], 0.05, square(0.25), 0.45);
        t.note(0.3, 0.2, hz('C7'), square(0.125), const Envelope(0.005, 0.1, 0.5, 0.15), 0.35, vibrato: 0.01, vibratoRate: 9);
      }, peak: 0.6),
      'craft': sfx(0.5, (t) {
        for (final at in const [0.0, 0.13]) {
          t.note(at, 0.06, 900, square(0.5), const Envelope.hit(0.06), 0.4);
          t.noise(at, 0.003, const Envelope.hit(0.02), 0.4, cutoff: 3000, highPass: true);
        }
        t.note(0.28, 0.05, hz('G5'), square(0.25), const Envelope(0.002, 0.04, 0.5, 0.03), 0.4);
        t.note(0.34, 0.1, hz('C6'), square(0.25), const Envelope(0.002, 0.04, 0.5, 0.05), 0.4);
      }, peak: 0.6),
      'place': sfx(0.5, (t) {
        t.noise(0, 0.15, const Envelope(0.005, 0.15, 0.3, 0.1), 0.9, cutoff: 900, endCutoff: 200);
        t.note(0, 0.2, 140, triangle, const Envelope.hit(0.2), 0.6, endFreq: 55);
        final r = Random(3);
        for (var i = 0; i < 8; i++) {
          t.noise(0.1 + r.nextDouble() * 0.3, 0.001, const Envelope.hit(0.004), 0.5,
              cutoff: 2500, highPass: true, seed: 50 + i);
        }
      }, peak: 0.7),
      'sizzle': sfx(0.5, (t) {
        final r = Random(5);
        for (var i = 0; i < 22; i++) {
          final at = i * 0.02;
          t.noise(at, 0.01, const Envelope.hit(0.02), (0.4 + r.nextDouble() * 0.6) * (1 - at / 0.5),
              cutoff: 2500, highPass: true, seed: 80 + i);
        }
      }, peak: 0.45),
      'water': sfx(0.45, (t) {
        t.noise(0, 0.25, const Envelope(0.01, 0.2, 0.5, 0.1), 0.7, cutoff: 3000);
        final r = Random(9);
        for (var i = 0; i < 4; i++) {
          final f = 1300 + r.nextDouble() * 600;
          t.note(0.05 + r.nextDouble() * 0.3, 0.03, f, sine, const Envelope.hit(0.03), 0.4, endFreq: f * 1.4);
        }
      }, peak: 0.5),
      'plant': sfx(0.15, (t) {
        t.note(0, 0.08, 150, triangle, const Envelope.hit(0.08), 0.8, endFreq: 95);
        t.noise(0, 0.005, const Envelope.hit(0.05), 0.5, cutoff: 1200);
      }, peak: 0.5),
      'sleep': sfx(1.6, (t) {
        for (final (i, n) in ['G5', 'E5', 'C5', 'G4'].indexed) {
          t.note(i * 0.3, 0.25, hz(n), triangle, const Envelope(0.02, 0.2, 0.5, 0.3), 0.6);
          t.note(i * 0.3, 0.2, hz(n) * 2, sine, const Envelope(0.02, 0.15, 0.3, 0.2), 0.1);
        }
      }, peak: 0.5),
      'deny': sfx(0.25, (t) {
        for (final at in const [0.0, 0.1]) {
          t.note(at, 0.07, 150, square(0.5), const Envelope(0.002, 0.05, 0.6, 0.02), 0.5);
        }
      }, peak: 0.35),
      'torch': sfx(0.5, (t) {
        t.noise(0, 0.22, const Envelope(0.02, 0.22, 0.3, 0.12), 1.0, cutoff: 300, endCutoff: 2600);
        t.note(0, 0.12, 120, triangle, const Envelope.hit(0.14), 0.5, endFreq: 70);
        final r = Random(31);
        for (var i = 0; i < 6; i++) {
          t.noise(0.15 + r.nextDouble() * 0.3, 0.001, const Envelope.hit(0.004), 0.5,
              cutoff: 2500, highPass: true, seed: 700 + i);
        }
      }, peak: 0.6),
      'fizzle': sfx(0.6, (t) {
        t.noise(0, 0.45, const Envelope(0.005, 0.45, 0.15, 0.1), 0.9, cutoff: 5000, endCutoff: 600, highPass: true);
        t.note(0.05, 0.2, 300, sine, const Envelope.hit(0.25), 0.25, endFreq: 120);
      }, peak: 0.45),
      'swish': sfx(0.22, (t) {
        t.noise(0, 0.12, const Envelope(0.015, 0.1, 0.3, 0.05), 1.0, cutoff: 1200, endCutoff: 6000, highPass: true);
        t.note(0.02, 0.08, 900, sine, const Envelope.hit(0.1), 0.15, endFreq: 1800);
      }, peak: 0.55),
      'crumble': sfx(0.9, (t) {
        t.noise(0, 0.5, const Envelope(0.01, 0.5, 0.3, 0.25), 1.0, cutoff: 400, endCutoff: 120);
        t.note(0, 0.3, 90, triangle, const Envelope.hit(0.35), 0.6, endFreq: 45);
        final r = Random(37);
        for (var i = 0; i < 9; i++) {
          final f = 500 + r.nextDouble() * 900;
          t.note(0.05 + r.nextDouble() * 0.6, 0.02, f, square(0.5), const Envelope.hit(0.03), 0.2, endFreq: f * 0.7);
        }
      }, peak: 0.75),
      'smelt': sfx(0.9, (t) {
        // A ringing clang, then the hiss of hot iron.
        for (final (f, v) in const [(820.0, 0.5), (1290.0, 0.3), (2110.0, 0.18)]) {
          t.note(0, 0.5, f, sine, const Envelope(0.001, 0.5, 0, 0.1), v);
        }
        t.noise(0, 0.004, const Envelope.hit(0.02), 0.6, cutoff: 3000, highPass: true);
        t.noise(0.18, 0.5, const Envelope(0.02, 0.5, 0.2, 0.15), 0.35,
            cutoff: 6000, endCutoff: 2500, highPass: true, seed: 3);
      }, peak: 0.6),
      'chime': sfx(1.1, (t) {
        for (final (i, n) in const ['E6', 'B6', 'E7'].indexed) {
          t.note(i * 0.07, 0.6, hz(n), sine, const Envelope(0.002, 0.8, 0, 0.1), 0.45 - i * 0.1);
        }
      }, peak: 0.5),
      'climb': sfx(0.55, (t) {
        for (final (i, at) in const [0.0, 0.17, 0.34].indexed) {
          t.note(at, 0.05, 190 - i * 15.0, triangle, const Envelope.hit(0.06), 0.8, endFreq: 120);
          t.noise(at, 0.003, const Envelope.hit(0.02), 0.35, cutoff: 2200, seed: 800 + i);
        }
      }, peak: 0.45),
      'fanfare': sfx(2.4, (t) {
        const eighth = 60 / 140 / 2;
        melody('C5.1 E5.1 G5.1 C6.3 | B5.1 G5.1 D6.2 | C6.6', eighth, (start, length, note) {
          t.note(start, length * 0.9, hz(note), square(0.25), const Envelope(0.005, 0.1, 0.6, 0.2), 0.45, vibrato: 0.006);
        });
        melody('C3.6 G2.4 C3.6', eighth, (start, length, note) {
          t.note(start, length * 0.9, hz(note), triangle, const Envelope(0.005, 0.1, 0.8, 0.2), 0.5);
        });
        melody('E4.6 D4.4 E4.6', eighth, (start, length, note) {
          t.note(start, length * 0.9, hz(note), square(0.125), const Envelope(0.005, 0.1, 0.5, 0.2), 0.2);
        });
      }, peak: 0.7),
    };

// -----------------------------------------------------------------------------
// Output and checks

void writeWav(String path, Float64List samples) {
  final data = ByteData(44 + samples.length * 2);
  void tag(int offset, String s) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

/// How strongly [freq] sounds in [n] samples from [start] (Goertzel).
double power(Float64List s, int start, int n, double freq) {
  final k = 2 * cos(2 * pi * freq / rate);
  var a = 0.0, b = 0.0;
  for (var i = 0; i < n; i++) {
    final c = s[(start + i) % s.length] + k * a - b;
    b = a;
    a = c;
  }
  return a * a + b * b - k * a * b;
}

/// Checks that each note of [line] really sounds at its pitch: louder than
/// the semitones either side of it.
int checkPitches(Track track, String line, double bpm) {
  final eighth = 60 / bpm / 2;
  var wrong = 0;
  melody(line, eighth, (start, length, note) {
    final f = hz(note);
    final at = ((start + 0.03) * rate).round();
    final n = (min(0.08, length * 0.8) * rate).round();
    final here = power(track.samples, at, n, f);
    final below = power(track.samples, at, n, f / pow(2, 1 / 12));
    final above = power(track.samples, at, n, f * pow(2, 1 / 12));
    if (here <= below || here <= above) wrong++;
  });
  return wrong;
}

void main() {
  final tracks = <String, Track>{
    'music_day': dayMusic(),
    'music_night': nightMusic(),
    'music_mine': mineMusic(),
    'ambience_day': dayAmbience(),
    'ambience_night': nightAmbience(),
    'ambience_mine': mineAmbience(),
    'river': river(),
    'fire': fire(),
    ...effects(),
  };
  var bytes = 0;
  for (final MapEntry(key: name, value: track) in tracks.entries) {
    writeWav('$outDir/$name.wav', track.samples);
    bytes += 44 + track.length * 2;
    var sumSquares = 0.0;
    for (final s in track.samples) {
      sumSquares += s * s;
    }
    final rms = sqrt(sumSquares / track.length);
    print('${name.padRight(15)} ${(track.length / rate).toStringAsFixed(2).padLeft(6)} s   rms ${rms.toStringAsFixed(3)}');
  }
  print('${tracks.length} files, ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB');

  final dayWrong = checkPitches(tracks['music_day']!, dayLead, dayBpm);
  final nightWrong = checkPitches(tracks['music_night']!, nightLead, nightBpm);
  final mineWrong = checkPitches(tracks['music_mine']!, mineLead, mineBpm);
  print('Melody notes off pitch: day $dayWrong, night $nightWrong, mine $mineWrong');
  if (dayWrong + nightWrong + mineWrong > 0) exitCode = 1;
}
