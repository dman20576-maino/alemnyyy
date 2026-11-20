import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'facts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AlemnyApp(prefs: prefs));
}

class AlemnyApp extends StatefulWidget {
  final SharedPreferences prefs;
  const AlemnyApp({super.key, required this.prefs});

  @override
  State<AlemnyApp> createState() => _AlemnyAppState();
}

class _AlemnyAppState extends State<AlemnyApp> {
  late bool dark = widget.prefs.getBool('dark') ?? false;
  late Set<int> favs = (widget.prefs.getStringList('favs') ?? [])
      .map((e) => int.tryParse(e))
      .whereType<int>()
      .toSet();

  void toggleDark() {
    setState(() => dark = !dark);
    widget.prefs.setBool('dark', dark);
  }

  void toggleFav(int id) {
    setState(() {
      if (favs.contains(id)) {
        favs.remove(id);
      } else {
        favs.add(id);
      }
    });
    widget.prefs.setStringList('favs', favs.map((e) => e.toString()).toList());
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF111A2C) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'علمني',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: Shell(
        dark: dark,
        favs: favs,
        onToggleDark: toggleDark,
        onToggleFav: toggleFav,
      ),
    );
  }
}

class Shell extends StatefulWidget {
  final bool dark;
  final Set<int> favs;
  final VoidCallback onToggleDark;
  final void Function(int) onToggleFav;

  const Shell({
    super.key,
    required this.dark,
    required this.favs,
    required this.onToggleDark,
    required this.onToggleFav,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(favs: widget.favs, onFav: widget.onToggleFav),
      BrowsePage(favs: widget.favs, onFav: widget.onToggleFav),
      FavoritesPage(favs: widget.favs, onFav: widget.onToggleFav),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'علمني',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: widget.dark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleDark,
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'معلومة اليوم',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'تصفح (365)',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: widget.favs.length,
              isLabelVisible: widget.favs.isNotEmpty,
              child: const Icon(Icons.favorite_border),
            ),
            selectedIcon: const Icon(Icons.favorite),
            label: 'المفضلة',
          ),
        ],
      ),
    );
  }
}

class TodayPage extends StatefulWidget {
  final Set<int> favs;
  final void Function(int) onFav;

  const TodayPage({super.key, required this.favs, required this.onFav});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late int currentDayOffset = 0;
  final _random = Random();

  int _todayIndex() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final baseIndex = _todayIndex();
    final idx = (baseIndex + currentDayOffset) % facts.length;
    final fact = facts[idx < 0 ? idx + facts.length : idx];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentDayOffset == 0 ? 'معلومة اليوم' : 'استعراض معلومة أخرى',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'معلومة رقم ${fact.id} من ${facts.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () => setState(() {
                currentDayOffset = _random.nextInt(facts.length);
              }),
              icon: const Icon(Icons.shuffle, size: 18),
              label: const Text('عشوائي'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FactCard(
          fact: fact,
          isFav: widget.favs.contains(fact.id),
          onFav: () => widget.onFav(fact.id),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => currentDayOffset--),
                icon: const Icon(Icons.chevron_right),
                label: const Text('السابقة'),
              ),
            ),
            const SizedBox(width: 8),
            if (currentDayOffset != 0)
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => currentDayOffset = 0),
                  child: const Text('معلومة اليوم'),
                ),
              ),
            if (currentDayOffset != 0) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => currentDayOffset++),
                icon: const Icon(Icons.chevron_left),
                label: const Text('التالية'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BrowsePage extends StatefulWidget {
  final Set<int> favs;
  final void Function(int) onFav;

  const BrowsePage({super.key, required this.favs, required this.onFav});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  String query = '';
  String? selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = facts.where((f) {
      final matchesCat =
          selectedCategory == null || f.category == selectedCategory;
      final q = query.toLowerCase();
      final matchesQuery = q.isEmpty ||
          f.title.toLowerCase().contains(q) ||
          f.body.toLowerCase().contains(q) ||
          f.explanation.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => query = '');
                          },
                        )
                      : null,
                  hintText: 'ابحث في الـ 365 معلومة...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (v) => setState(() => query = v.trim()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text('الكل (${facts.length})'),
                        selected: selectedCategory == null,
                        onSelected: (_) =>
                            setState(() => selectedCategory = null),
                      ),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(c),
                          selected: selectedCategory == c,
                          onSelected: (_) => setState(() {
                            selectedCategory =
                                selectedCategory == c ? null : c;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'النتائج: ${filtered.length} معلومة',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('مفيش معلومات مطابقة لبحثك'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final f = filtered[i];
                    return FactCard(
                      fact: f,
                      isFav: widget.favs.contains(f.id),
                      onFav: () => widget.onFav(f.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final Set<int> favs;
  final void Function(int) onFav;

  const FavoritesPage({super.key, required this.favs, required this.onFav});

  @override
  Widget build(BuildContext context) {
    final list = facts.where((f) => favs.contains(f.id)).toList();
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لسه ما حفظتش معلومات في المفضلة.\nاضغط على أيقونة القلب في أي معلومة لحفظها هنا.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final f = list[i];
        return FactCard(
          fact: f,
          isFav: true,
          onFav: () => onFav(f.id),
        );
      },
    );
  }
}

class FactCard extends StatelessWidget {
  final Fact fact;
  final bool isFav;
  final VoidCallback onFav;

  const FactCard({
    super.key,
    required this.fact,
    required this.isFav,
    required this.onFav,
  });

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.parse(fact.url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح رابط المصدر')),
      );
    }
  }

  void _copyFact(BuildContext context) {
    Clipboard.setData(
      ClipboardData(
        text: '${fact.title}\n\n${fact.body}\n\nالشرح: ${fact.explanation}\nالمصدر: ${fact.url}',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ المعلومة بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${fact.category} · #${fact.id}',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'نسخ المعلومة',
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  onPressed: () => _copyFact(context),
                ),
                IconButton(
                  tooltip: isFav ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.redAccent : null,
                  ),
                  onPressed: onFav,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              fact.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fact.body,
              style: textTheme.bodyLarge?.copyWith(height: 1.65),
            ),
            const Divider(height: 24),
            Text(
              'الشرح المبسط',
              style: textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fact.explanation,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _openSource(context),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('اقرأ الشرح الكامل في ${fact.sourceName}'),
            ),
          ],
        ),
      ),
    );
  }
}
