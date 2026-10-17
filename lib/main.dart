import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const GlassMusicApp());
}

// ---------------- Dummy data ----------------
class Song {
  final String title, artist;
  final List<Color> colors;
  const Song(this.title, this.artist, this.colors);
}

const songs = <Song>[
  Song('Aashiqana', 'Chaar Diwaari', [Color(0xFFE53935), Color(0xFF4A148C)]),
  Song('Midnight Drive', 'Neon Roads', [Color(0xFF00B4DB), Color(0xFF0D1B4C)]),
  Song('Golden Hour', 'Sunday Bloom', [Color(0xFFFFB74D), Color(0xFFD81B60)]),
  Song('Lo-Fi Rain', 'Chill Hop', [Color(0xFF4DB6AC), Color(0xFF1A237E)]),
  Song('Tripple OG', 'Banda Beats', [Color(0xFFFFEB3B), Color(0xFF1B5E20)]),
  Song('Aurora', 'Nova', [Color(0xFFAB47BC), Color(0xFF00E5FF)]),
];

// ---------------- App ----------------
class GlassMusicApp extends StatelessWidget {
  const GlassMusicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const Shell(),
      );
}

// Agar shader glass me glitch aaye to false kar do: poora UI frosted glass ban jayega.
const bool kUseShader = true;

/// iOS-style glass. Chhote/zyada elements ke liye frosted (BackdropFilter),
/// sirf nav bar + mini player pe real refraction shader.
class GlassBox extends StatelessWidget {
  final double radius;
  final Widget child;
  final bool shader;
  const GlassBox({super.key, required this.radius, required this.child, this.shader = false});

  @override
  Widget build(BuildContext context) {
    if (shader && kUseShader) {
      return LiquidGlass.withOwnLayer(
        settings: const LiquidGlassSettings(
          thickness: 7,
          blur: 4,
          glassColor: Color(0x0FFFFFFF),
        ),
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        child: child,
      );
    }
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(.22),
                Colors.white.withOpacity(.06),
                Colors.white.withOpacity(.12),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(.30), width: .9),
          ),
          child: child,
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  int current = 0;
  bool playing = true;
  double progress = 0.35;

  @override
  Widget build(BuildContext context) {
    final song = songs[current];
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // animated colourful background (glass refracts this)
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [song.colors[0].withOpacity(.85), song.colors[1], Colors.black],
              ),
            ),
          ),
          // pages
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(
                key: ValueKey(tab),
                child: tab == 0
                    ? HomePage(
                        topPad: pad.top,
                        current: current,
                        onPick: (i) => setState(() {
                          current = i;
                          playing = true;
                          progress = 0;
                        }),
                      )
                    : tab == 1
                        ? LibraryPage(topPad: pad.top, onPick: (i) => setState(() => current = i))
                        : SettingsPage(topPad: pad.top),
              ),
            ),
          ),
          // mini player + nav bar
          Positioned(
            left: 14,
            right: 14,
            bottom: pad.bottom + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiniPlayer(
                  song: song,
                  playing: playing,
                  progress: progress,
                  onToggle: () => setState(() => playing = !playing),
                  onNext: () => setState(() {
                    current = (current + 1) % songs.length;
                    progress = 0;
                  }),
                  onOpen: () => showNowPlaying(context, song, playing),
                ),
                const SizedBox(height: 10),
                GlassNavBar(index: tab, onChanged: (i) => setState(() => tab = i)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showNowPlaying(BuildContext context, Song song, bool playing) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => NowPlaying(song: song),
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(c),
          child: child,
        );
      },
    ));
  }
}

// ---------------- Squish (iOS-style spring on press) ----------------
class Squish extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double amount;
  const Squish({super.key, required this.child, this.onTap, this.amount = .08});
  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController.unbounded(vsync: this, value: 0);

  void _to(double target) {
    c.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 14),
      c.value,
      target,
      c.velocity,
    ));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _to(1),
        onTapUp: (_) {
          _to(0);
          widget.onTap?.call();
        },
        onTapCancel: () => _to(0),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, child) => Transform.scale(
            scaleX: 1 + widget.amount * c.value,
            scaleY: 1 - widget.amount * .6 * c.value,
            child: child,
          ),
          child: widget.child,
        ),
      );
}

// ---------------- Glass nav bar with sliding blob ----------------
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const GlassNavBar({super.key, required this.index, required this.onChanged});

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassBox(radius: 34, shader: true, child: SizedBox(
        height: 68,
        child: LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 12) / items.length;
          return Stack(
            children: [
              // sliding selection blob with overshoot spring
              AnimatedPositioned(
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                left: 6 + index * w,
                top: 6,
                width: w,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.18),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(.25), width: .8),
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 6),
                  for (int i = 0; i < items.length; i++)
                    SizedBox(
                      width: w,
                      height: 68,
                      child: Squish(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(i);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: i == index ? 1.12 : 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              child: Icon(items[i].$1,
                                  size: 26,
                                  color: i == index ? Colors.white : Colors.white60),
                            ),
                            const SizedBox(height: 2),
                            Text(items[i].$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: i == index ? Colors.white : Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------- Mini player ----------------
class MiniPlayer extends StatelessWidget {
  final Song song;
  final bool playing;
  final double progress;
  final VoidCallback onToggle, onNext, onOpen;
  const MiniPlayer({
    super.key,
    required this.song,
    required this.playing,
    required this.progress,
    required this.onToggle,
    required this.onNext,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Squish(
      amount: .03,
      onTap: onOpen,
      child: GlassBox(radius: 30, shader: true, child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Art(song: song, size: 44, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              Squish(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        key: ValueKey(playing), size: 32),
                  ),
                ),
              ),
              Squish(
                onTap: onNext,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.fast_forward_rounded, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Album art ----------------
class Art extends StatelessWidget {
  final Song song;
  final double size, radius;
  const Art({super.key, required this.song, required this.size, required this.radius});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: song.colors),
        ),
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: size * .45),
      );
}

// ---------------- Glass pill button ----------------
class GlassCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const GlassCircle({super.key, required this.icon, this.onTap, this.size = 48});
  @override
  Widget build(BuildContext context) => Squish(
        onTap: onTap,
        child: GlassBox(radius: size / 2, child: SizedBox(width: size, height: size, child: Icon(icon, size: size * .5)),
        ),
      );
}

// ---------------- Home ----------------
class HomePage extends StatelessWidget {
  final double topPad;
  final int current;
  final ValueChanged<int> onPick;
  const HomePage({super.key, required this.topPad, required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 220),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Good evening',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            ),
            GlassCircle(icon: Icons.mic_rounded, onTap: () {}),
            const SizedBox(width: 10),
            GlassCircle(icon: Icons.shuffle_rounded, onTap: () {}),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Recently Played',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => Squish(
              amount: .05,
              onTap: () => onPick(i),
              child: Stack(
                children: [
                  Art(song: songs[i], size: 170, radius: 26),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: GlassBox(radius: 16, child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(songs[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Made for you',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (int i = 0; i < songs.length; i++) SongTile(index: i, onTap: () => onPick(i)),
      ],
    );
  }
}

class SongTile extends StatelessWidget {
  final int index;
  final VoidCallback onTap;
  const SongTile({super.key, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = songs[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Squish(
        amount: .03,
        onTap: onTap,
        child: GlassBox(radius: 24, child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Art(song: s, size: 52, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(s.artist,
                          style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: Colors.white54),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Library ----------------
class LibraryPage extends StatelessWidget {
  final double topPad;
  final ValueChanged<int> onPick;
  const LibraryPage({super.key, required this.topPad, required this.onPick});
  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 220),
        children: [
          const Text('Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          for (final t in const ['Playlists', 'Albums', 'Artists', 'Downloaded'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Squish(
                amount: .03,
                onTap: () {},
                child: GlassBox(radius: 24, child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          for (int i = 0; i < songs.length; i++) SongTile(index: i, onTap: () => onPick(i)),
        ],
      );
}

// ---------------- Settings ----------------
class SettingsPage extends StatefulWidget {
  final double topPad;
  const SettingsPage({super.key, required this.topPad});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Map<String, bool> on = {'Crossfade': true, 'Normalize volume': false, 'Lossless audio': true};
  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(20, widget.topPad + 16, 20, 220),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          for (final e in on.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassBox(radius: 24, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(children: [
                    Text(e.key, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GlassSwitch(
                        value: e.value, onChanged: (v) => setState(() => on[e.key] = v)),
                  ]),
                ),
              ),
            ),
        ],
      );
}

// iOS-style switch with squishy thumb
class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const GlassSwitch({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          width: 58,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: value ? const Color(0xFF34C759) : Colors.white24,
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          ),
        ),
      );
}

// ---------------- Now Playing (full screen) ----------------
class NowPlaying extends StatefulWidget {
  final Song song;
  const NowPlaying({super.key, required this.song});
  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  bool playing = true;
  double pos = .3;
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [widget.song.colors[0], widget.song.colors[1], Colors.black],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, pad.top + 12, 28, pad.bottom + 28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassCircle(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onTap: () => Navigator.pop(context)),
                ),
                const Spacer(),
                Hero(
                  tag: 'art',
                  child: Art(
                      song: widget.song,
                      size: MediaQuery.of(context).size.width - 90,
                      radius: 36),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.song.title,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.song.artist,
                      style: const TextStyle(fontSize: 17, color: Colors.white70)),
                ),
                const SizedBox(height: 18),
                // glass progress slider
                GlassBox(radius: 20, child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(value: pos, onChanged: (v) => setState(() => pos = v)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GlassCircle(icon: Icons.skip_previous_rounded, size: 64, onTap: () {}),
                    GlassCircle(
                        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 84,
                        onTap: () => setState(() => playing = !playing)),
                    GlassCircle(icon: Icons.skip_next_rounded, size: 64, onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
