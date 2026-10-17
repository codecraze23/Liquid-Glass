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

// true karoge to nav bar/mini player me real refraction shader (experimental).
// false = stable blur glass (video jaisa look).
const bool kUseShader = false;

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
  Song('Kalyani (Remix)', 'ARJN, KDS', [Color(0xFFFF7043), Color(0xFF3E2723)]),
  Song('Neon Pulse', 'Vibe Lab', [Color(0xFF69F0AE), Color(0xFF004D40)]),
];

class GlassMusicApp extends StatelessWidget {
  const GlassMusicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: Colors.black),
        home: const Shell(),
      );
}

// ---------------- Glass ----------------
class GlassBox extends StatelessWidget {
  final double radius;
  final Widget child;
  final bool shader;
  final double tint;
  const GlassBox(
      {super.key, required this.radius, required this.child, this.shader = false, this.tint = .30});

  @override
  Widget build(BuildContext context) {
    if (shader && kUseShader) {
      return LiquidGlass.withOwnLayer(
        settings: const LiquidGlassSettings(
            thickness: 7, blur: 6, glassColor: Color(0x22000000)),
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        child: child,
      );
    }
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: CustomPaint(
          foregroundPainter: _RimPainter(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(.10),
                  Colors.black.withOpacity(tint),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Rim light: upar-left chamakdar, neeche halka (glass edge).
class _RimPainter extends CustomPainter {
  final double radius;
  _RimPainter(this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(.6), Radius.circular(radius));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(.55),
          Colors.white.withOpacity(.08),
          Colors.white.withOpacity(.30),
        ],
      ).createShader(rect);
    canvas.drawRRect(rr, p);
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) => old.radius != radius;
}

// ---------------- Squish (spring press) ----------------
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
  void _to(double t) => c.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 14), c.value, t, c.velocity));
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
              child: child),
          child: widget.child,
        ),
      );
}

// ---------------- Shell ----------------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0; // 0 home, 1 explore, 2 library, 3 search
  int current = 6;
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final pages = [
      HomePage(topPad: pad.top, onPick: _pick),
      ExplorePage(topPad: pad.top),
      LibraryPage(topPad: pad.top, onPick: _pick),
      SearchPage(topPad: pad.top, onPick: _pick),
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: pad.bottom + 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MiniPlayer(
                  song: songs[current],
                  playing: playing,
                  onToggle: () => setState(() => playing = !playing),
                  onNext: () => setState(() => current = (current + 1) % songs.length),
                  onOpen: () => Navigator.of(context).push(PageRouteBuilder(
                    opaque: false,
                    transitionDuration: const Duration(milliseconds: 450),
                    pageBuilder: (_, __, ___) => NowPlaying(song: songs[current]),
                    transitionsBuilder: (_, a, __, child) => SlideTransition(
                      position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  )),
                ),
                const SizedBox(height: 8),
                GlassNavBar(index: tab, onChanged: (i) => setState(() => tab = i)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pick(int i) => setState(() {
        current = i;
        playing = true;
      });
}

// ---------------- Nav bar (3 tabs + search circle) ----------------
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const GlassNavBar({super.key, required this.index, required this.onChanged});

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.grid_view_rounded, 'Explore'),
    (Icons.library_music_rounded, 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassBox(
            radius: 34,
            shader: true,
            child: SizedBox(
              height: 68,
              child: LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 10) / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      left: 5 + (index > 2 ? 0 : index) * w,
                      top: 5,
                      width: w,
                      height: 58,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: index > 2 ? 0 : 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.16),
                            borderRadius: BorderRadius.circular(29),
                            border: Border.all(color: Colors.white.withOpacity(.22), width: .8),
                          ),
                        ),
                      ),
                    ),
                    Row(children: [
                      const SizedBox(width: 5),
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
                                  scale: i == index ? 1.1 : 1,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  child: Icon(items[i].$1,
                                      size: 25, color: i == index ? Colors.white : Colors.white60),
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
                    ]),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Squish(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(3);
          },
          child: GlassBox(
            radius: 34,
            shader: true,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(Icons.search_rounded,
                  size: 28, color: index == 3 ? Colors.white : Colors.white70),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- Mini player ----------------
class MiniPlayer extends StatelessWidget {
  final Song song;
  final bool playing;
  final VoidCallback onToggle, onNext, onOpen;
  const MiniPlayer(
      {super.key,
      required this.song,
      required this.playing,
      required this.onToggle,
      required this.onNext,
      required this.onOpen});

  @override
  Widget build(BuildContext context) => Squish(
        amount: .025,
        onTap: onOpen,
        child: GlassBox(
          radius: 30,
          shader: true,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(children: [
              Art(song: song, size: 42, radius: 10),
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
                    padding: EdgeInsets.all(8), child: Icon(Icons.fast_forward_rounded, size: 28)),
              ),
            ]),
          ),
        ),
      );
}

// ---------------- Common widgets ----------------
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
        child: Icon(Icons.music_note_rounded, color: Colors.white54, size: size * .4),
      );
}

class GlassCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const GlassCircle({super.key, required this.icon, this.onTap, this.size = 44});
  @override
  Widget build(BuildContext context) => Squish(
        onTap: onTap,
        child: GlassBox(
          radius: size / 2,
          child: SizedBox(width: size, height: size, child: Icon(icon, size: size * .5)),
        ),
      );
}

class Header extends StatelessWidget {
  final String title;
  const Header(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800))),
        const GlassCircle(icon: Icons.person_rounded),
      ]);
}

class Shelf extends StatelessWidget {
  final String title, sub;
  final ValueChanged<int> onPick;
  final double size;
  const Shelf(
      {super.key, required this.title, this.sub = '', required this.onPick, this.size = 150});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(
                    color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: size + 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => Squish(
                amount: .05,
                onTap: () => onPick(i),
                child: SizedBox(
                  width: size,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Art(song: songs[i], size: size, radius: 16),
                    const SizedBox(height: 8),
                    Text(songs[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(songs[i].artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      );
}

// ---------------- Pages ----------------
const _bottomPad = 230.0;

class HomePage extends StatelessWidget {
  final double topPad;
  final ValueChanged<int> onPick;
  const HomePage({super.key, required this.topPad, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 40;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, _bottomPad),
      children: [
        const Header('Listen Now'),
        const SizedBox(height: 18),
        GlassBox(
          radius: 18,
          tint: .45,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: Text('Sign in to your account\nGet personalized recommendations',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Chip(label: Text('Sign in', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        const Text('Albums & singles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Squish(
          amount: .03,
          onTap: () => onPick(0),
          child: Stack(children: [
            Art(song: songs[0], size: w, radius: 24),
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(songs[0].title.toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const Text('Album • Chaar Diwaari', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 26),
        Shelf(title: "India's biggest hits", sub: "MUSIC THAT'S HOT AND HAPPENING!", onPick: onPick),
        const SizedBox(height: 18),
        Shelf(title: 'Made for you', onPick: onPick, size: 130),
      ],
    );
  }
}

class ExplorePage extends StatelessWidget {
  final double topPad;
  const ExplorePage({super.key, required this.topPad});
  static const cats = ['Sad', 'Sleep', 'Party', 'Workout', 'Romance', 'Focus', 'Desi Pop', 'Chill'];
  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, _bottomPad),
        children: [
          const Header('Explore'),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              for (int i = 0; i < cats.length; i++)
                Squish(
                  amount: .04,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(colors: songs[i % songs.length].colors),
                    ),
                    alignment: Alignment.bottomLeft,
                    child: Text(cats[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ],
      );
}

class LibraryPage extends StatelessWidget {
  final double topPad;
  final ValueChanged<int> onPick;
  const LibraryPage({super.key, required this.topPad, required this.onPick});
  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, _bottomPad),
        children: [
          const Header('Library'),
          const SizedBox(height: 18),
          for (final t in const [
            (Icons.download_rounded, 'Downloads'),
            (Icons.folder_rounded, 'Local Music'),
            (Icons.favorite_rounded, 'Liked Songs'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(t.$1),
                title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ),
            ),
          const SizedBox(height: 14),
          const Text('Playlists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (int i = 0; i < songs.length; i++) SongRow(index: i, onTap: () => onPick(i)),
        ],
      );
}

class SearchPage extends StatelessWidget {
  final double topPad;
  final ValueChanged<int> onPick;
  const SearchPage({super.key, required this.topPad, required this.onPick});
  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, _bottomPad),
        children: [
          const Header('Search'),
          const SizedBox(height: 18),
          GlassBox(
            radius: 24,
            tint: .45,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                Icon(Icons.search_rounded, color: Colors.white60),
                SizedBox(width: 10),
                Text('Songs, albums, artists', style: TextStyle(color: Colors.white54)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < songs.length; i++) SongRow(index: i, onTap: () => onPick(i)),
        ],
      );
}

class SongRow extends StatelessWidget {
  final int index;
  final VoidCallback onTap;
  const SongRow({super.key, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = songs[index];
    return Squish(
      amount: .03,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Art(song: s, size: 54, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Text(s.artist, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
          const Icon(Icons.more_horiz_rounded, color: Colors.white38),
        ]),
      ),
    );
  }
}

// ---------------- Now Playing ----------------
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.song.colors[0], widget.song.colors[1], Colors.black],
          ),
        ),
        padding: EdgeInsets.fromLTRB(28, pad.top + 12, 28, pad.bottom + 28),
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GlassCircle(
                icon: Icons.keyboard_arrow_down_rounded, onTap: () => Navigator.pop(context)),
          ),
          const Spacer(),
          Art(song: widget.song, size: MediaQuery.of(context).size.width - 90, radius: 32),
          const Spacer(),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.song.title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.song.artist,
                  style: const TextStyle(fontSize: 17, color: Colors.white70))),
          const SizedBox(height: 14),
          SliderTheme(
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
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GlassCircle(icon: Icons.skip_previous_rounded, size: 64, onTap: () {}),
            GlassCircle(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 84,
                onTap: () => setState(() => playing = !playing)),
            GlassCircle(icon: Icons.skip_next_rounded, size: 64, onTap: () {}),
          ]),
        ]),
      ),
    );
  }
}
