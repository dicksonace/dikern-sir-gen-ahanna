import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/linked_file.dart';
import '../../widgets/hold_builder.dart';
import '../../widgets/tab_focus.dart';
import '../shared/account_profile.dart';
import '../shared/question_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> with WidgetsBindingObserver {
  int index = 0;
  final visited = <int>{0};
  final pages = const [
    _StudentHome(),
    _TutorsTab(),
    _QuestionsTab(),
    AccountProfile(),
  ];
  List<LearningTrack> tracks = [];
  LearningTrack? selected;
  bool tracksReady = false;
  List<Subject> areas = [];
  Subject? area;
  bool areasReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthState>().user;
      context.read<ApiClient>().warm(division: user?.division, law: user?.isLaw ?? false);
      _loadTracks();
      _loadAreas();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<AuthState>().refreshIfStale();
    final api = context.read<ApiClient>();
    api.forget('questions');
    api.forget('lessons');
    api.bump();
  }

  Future<void> _loadTracks() async {
    final law = context.read<AuthState>().user?.isLaw ?? false;
    if (!mounted || law) return;
    try {
      final list = await context.read<ApiClient>().tracks(division: 'tutor');
      if (!mounted) return;
      setState(() {
        tracks = list;
        selected ??= list.isNotEmpty ? list.first : null;
        tracksReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => tracksReady = true);
    }
  }

  Future<void> _loadAreas() async {
    final law = context.read<AuthState>().user?.isLaw ?? false;
    if (!mounted || !law) return;
    try {
      final list = await context.read<ApiClient>().subjects(division: 'law');
      if (!mounted) return;
      setState(() {
        areas = list;
        area ??= list.isNotEmpty ? list.first : null;
        areasReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => areasReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;

    return TrackScope(
      tracks: law ? const [] : tracks,
      selected: law ? null : selected,
      ready: law || tracksReady,
      onSelect: (track) => setState(() => selected = track),
      child: PracticeScope(
        areas: law ? areas : const [],
        selected: law ? area : null,
        ready: !law || areasReady,
        onSelect: (subject) => setState(() => area = subject),
        child: TabFocus(
          index: index,
          child: Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < pages.length; i++) visited.contains(i) ? pages[i] : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() {
              visited.add(i);
              index = i;
            }),
            backgroundColor: Theme.of(context).colorScheme.surface,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people_rounded),
                label: law ? 'Advisers' : 'Tutors',
              ),
              const NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help_rounded), label: 'Ask'),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class TrackScope extends InheritedWidget {
  final List<LearningTrack> tracks;
  final LearningTrack? selected;
  final bool ready;
  final ValueChanged<LearningTrack> onSelect;

  const TrackScope({
    super.key,
    required this.tracks,
    required this.selected,
    required this.ready,
    required this.onSelect,
    required super.child,
  });

  static TrackScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TrackScope>();
  }

  @override
  bool updateShouldNotify(TrackScope oldWidget) {
    return ready != oldWidget.ready ||
        selected?.slug != oldWidget.selected?.slug ||
        tracks.length != oldWidget.tracks.length;
  }
}

class PracticeScope extends InheritedWidget {
  final List<Subject> areas;
  final Subject? selected;
  final bool ready;
  final ValueChanged<Subject> onSelect;

  const PracticeScope({
    super.key,
    required this.areas,
    required this.selected,
    required this.ready,
    required this.onSelect,
    required super.child,
  });

  static PracticeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PracticeScope>();
  }

  @override
  bool updateShouldNotify(PracticeScope oldWidget) {
    return ready != oldWidget.ready ||
        selected?.slug != oldWidget.selected?.slug ||
        areas.length != oldWidget.areas.length;
  }
}

String _selectionKey(BuildContext context) {
  final law = context.read<AuthState>().user?.isLaw ?? false;
  if (law) {
    final practice = PracticeScope.maybeOf(context);
    if (practice?.ready != true) return 'waiting';
    return 'law:${practice?.selected?.slug ?? 'none'}';
  }
  final scope = TrackScope.maybeOf(context);
  if (scope?.ready != true) return 'waiting';
  return scope?.selected?.slug ?? 'none';
}

class _StudentHome extends StatefulWidget {
  const _StudentHome();

  @override
  State<_StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<_StudentHome> {
  late Future<({List<LessonModel> lessons, List<QuestionModel> questions, List<Subject> subjects})> future;
  String? loadedKey;
  int seenRevision = -1;

  @override
  void initState() {
    super.initState();
    future = Future.value((lessons: <LessonModel>[], questions: <QuestionModel>[], subjects: <Subject>[]));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = TabFocus.of(context);
    final revision = context.watch<ApiClient>().revision;
    final key = _selectionKey(context);
    if (key == 'waiting') return;
    final first = loadedKey == null;
    final selectionChanged = key != loadedKey;
    final stale = revision != seenRevision;
    if (!first && !selectionChanged && !(focus == 0 && stale)) return;
    loadedKey = key;
    if (focus == 0) seenRevision = revision;
    final next = _load(force: stale && !first);
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  Future<({List<LessonModel> lessons, List<QuestionModel> questions, List<Subject> subjects})> _load({bool force = false}) async {
    final api = context.read<ApiClient>();
    final user = context.read<AuthState>().user;
    final track = TrackScope.maybeOf(context)?.selected;
    final subjectFuture = user?.isLaw == true
        ? api.subjects(division: user?.division, force: force)
        : (track == null || track.isProgramme)
            ? Future.value(<Subject>[])
            : api.subjects(division: 'tutor', track: track.slug, force: force);
    final results = await Future.wait([
      api.lessons(force: force),
      api.questions(force: force),
      subjectFuture,
    ]);
    return (
      lessons: results[0] as List<LessonModel>,
      questions: results[1] as List<QuestionModel>,
      subjects: results[2] as List<Subject>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (loadedKey == null) {
      return const Scaffold(body: PageSkeleton.home());
    }
    return RefreshIndicator(
      onRefresh: () async => setState(() => future = _load(force: true)),
      child: HoldBuilder(
        future: future,
        loading: const PageSkeleton.home(),
        error: (error) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('API error: $error', textAlign: TextAlign.center),
        )),
        builder: (context, data) {
          final scope = TrackScope.maybeOf(context);
          final practice = PracticeScope.maybeOf(context);
          final law = user?.isLaw == true;
          if ((!law && scope?.ready != true) || (law && practice?.ready != true)) {
            return const PageSkeleton.home();
          }
          final upcoming = data.lessons.where((l) => l.status == 'scheduled' || l.status == 'live').toList();
          final openQs = data.questions.where((q) => q.status == 'open').length;
          final track = scope?.selected;
          final area = practice?.selected;
          final showTracks = !law && (scope?.tracks.isNotEmpty ?? false);
          final showAreas = law && (practice?.areas.isNotEmpty ?? false);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeader(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            user?.roleLabel ?? 'Student',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          law
                              ? 'Hello, ${user?.name.split(' ').first ?? 'Client'}'
                              : 'Ayubowan, ${user?.name.split(' ').first ?? 'Student'}',
                          style: GoogleFonts.sora(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          law
                              ? (area?.name ?? 'Choose a practice area')
                              : (track == null ? 'Choose what you are studying' : track.name),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
                        ),
                        if (showTracks) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final item in scope!.tracks)
                                ChoiceChip(
                                  label: Text(item.name),
                                  selected: item.slug == track?.slug,
                                  selectedColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                                  labelStyle: TextStyle(
                                    color: item.slug == track?.slug ? AppColors.tealDeep : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: BorderSide.none,
                                  onSelected: (_) => scope.onSelect(item),
                                ),
                            ],
                          ),
                        ],
                        if (showAreas) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final item in practice!.areas)
                                ChoiceChip(
                                  label: Text(item.name),
                                  selected: item.slug == area?.slug,
                                  selectedColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                                  labelStyle: TextStyle(
                                    color: item.slug == area?.slug ? AppColors.tealDeep : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: BorderSide.none,
                                  onSelected: (_) => practice.onSelect(item),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _MiniStat('${upcoming.length}', 'Upcoming'),
                            const SizedBox(width: 10),
                            _MiniStat('$openQs', 'Open Q'),
                            const SizedBox(width: 10),
                            _MiniStat(
                              law
                                  ? '${practice?.areas.length ?? 0}'
                                  : track?.isProgramme == true
                                      ? '1'
                                      : '${data.subjects.length}',
                              law ? 'Areas' : (track?.isProgramme == true ? 'Programme' : 'Subjects'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverToBoxAdapter(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(
                          law ? 'Upcoming consultation' : 'Upcoming live lesson',
                          subtitle: law ? 'Booked with a lawyer or counsel' : 'Scheduled with your tutor',
                        ),
                        const SizedBox(height: 12),
                        if (upcoming.isEmpty)
                          EmptyHint(law ? 'No consultations booked yet.' : 'No upcoming lessons yet.')
                        else
                          ...upcoming.take(2).map((lesson) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SoftCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          StatusPill(lesson.status, color: AppColors.teal),
                                          const Spacer(),
                                          Text(
                                            lesson.scheduledAt == null
                                                ? ''
                                                : DateFormat('EEE d MMM · HH:mm').format(lesson.scheduledAt!.toLocal()),
                                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(lesson.title, style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17)),
                                      Text(
                                        law
                                            ? 'with ${lesson.tutor?.name ?? 'your adviser'}'
                                            : 'with ${lesson.tutor?.name ?? 'Tutor'}',
                                        style: const TextStyle(color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                await context.read<ApiClient>().startLesson(lesson.id);
                                                if (context.mounted) context.push('/live-lesson');
                                              },
                                              icon: const Icon(Icons.videocam_rounded),
                                              label: Text(law ? 'Join consultation' : 'Join class'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          OutlinedButton(
                                            onPressed: () async {
                                              if (lesson.tutor == null) return;
                                              await context.read<ApiClient>().givePoint(
                                                    tutorId: lesson.tutor!.id,
                                                    lessonId: lesson.id,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Satisfaction point sent via API')),
                                                );
                                              }
                                            },
                                            child: const Text('+ Point'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        const SizedBox(height: 18),
                        if (law)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionTitle(area?.name ?? 'Practice area', subtitle: 'Then choose a lawyer or legal counsel'),
                              const SizedBox(height: 12),
                              const SoftCard(
                                child: Text(
                                  'This is general guidance, not a court filing. Pick this practice area, then a lawyer for one-to-one advice or legal counsel for a written opinion.',
                                  style: TextStyle(height: 1.4),
                                ),
                              ),
                            ],
                          )
                        else ...[
                        SectionTitle(
                          track?.isProgramme == true ? track!.name : 'Subjects',
                          subtitle: track?.isProgramme == true ? 'One exam programme' : 'For ${track?.name ?? 'this track'}',
                        ),
                        const SizedBox(height: 12),
                        if (track?.isProgramme == true)
                          SoftCard(
                            child: Text(
                              track?.description ?? 'Grade 5 scholarship is one programme. There is no subject list.',
                              style: const TextStyle(height: 1.4),
                            ),
                          )
                        else
                          SizedBox(
                            height: 96,
                            child: data.subjects.isEmpty
                                ? const EmptyHint('No subjects on this track yet.')
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: data.subjects.length,
                                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final s = data.subjects[i];
                                      return SoftCard(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: SizedBox(
                                          width: 92,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_subjectIcon(s.icon), color: AppColors.teal),
                                              const SizedBox(height: 8),
                                              Text(s.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SectionTitle(law ? 'Recent questions' : 'Recent support', subtitle: law ? 'Advice you have asked for' : 'Questions you have sent'),
                        const SizedBox(height: 12),
                        if (data.questions.isEmpty)
                          const EmptyHint('No questions yet.')
                        else
                          ...data.questions.take(5).map((q) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: QuestionTile(
                                  question: q,
                                  onOpen: () async {
                                    final changed = await context.push<bool>('/question/${q.id}', extra: q);
                                    if (changed == true && mounted) setState(() => future = _load(force: true));
                                  },
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TutorsTab extends StatefulWidget {
  const _TutorsTab();

  @override
  State<_TutorsTab> createState() => _TutorsTabState();
}

class _TutorsTabState extends State<_TutorsTab> {
  late Future<List<TutorProfile>> future;
  String? loadedKey;
  int seenRevision = -1;
  String query = '';

  @override
  void initState() {
    super.initState();
    future = Future.value(const []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = TabFocus.of(context);
    final revision = context.watch<ApiClient>().revision;
    final key = _selectionKey(context);
    if (key == 'waiting') return;
    final first = loadedKey == null;
    final selectionChanged = key != loadedKey;
    final stale = revision != seenRevision;
    if (!first && !selectionChanged && !(focus == 1 && stale)) return;
    loadedKey = key;
    if (focus == 1) seenRevision = revision;
    final next = _load(force: stale && !first);
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  Future<List<TutorProfile>> _load({bool force = false}) async {
    final api = context.read<ApiClient>();
    final user = context.read<AuthState>().user;
    final track = TrackScope.maybeOf(context)?.selected;
    final division = user?.division;
    if (user?.isLaw == true) {
      final area = PracticeScope.maybeOf(context)?.selected;
      return api.tutors(division: 'law', subject: area?.slug, force: force);
    }
    final all = await api.tutors(division: division, force: force);
    if (track == null || track.isProgramme) return all;
    final subjects = await api.subjects(division: 'tutor', track: track.slug, force: force);
    final slugs = subjects.map((subject) => subject.slug).toSet();
    return all.where((tutor) => tutor.subjects.any((subject) => slugs.contains(subject.slug))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    final track = TrackScope.maybeOf(context)?.selected;
    final area = PracticeScope.maybeOf(context)?.selected;
    final title = law
        ? (area?.name ?? 'Lawyers and counsel')
        : track?.isProgramme == true
            ? 'Grade 5 scholarship'
            : 'Choose a tutor';
    if (loadedKey == null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const PageSkeleton.list());
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => future = _load(force: true)),
        child: HoldBuilder(
          future: future,
          loading: const PageSkeleton.list(),
          error: (error) => Center(child: Text('$error')),
          builder: (context, rows) {
            final tutors = rows.where((tutor) => textMatches(query, [
              tutor.displayName,
              tutor.subjectLabel,
              tutor.bio,
              tutor.user?.roleLabel,
            ])).toList();
            final search = AppSearchField(
              hint: law ? 'Search advisers' : 'Search tutors',
              onChanged: (value) => setState(() => query = value),
            );
            if (law) {
              final lawyers = tutors.where((tutor) => tutor.user?.role != 'counsel').toList();
              final counsel = tutors.where((tutor) => tutor.user?.role == 'counsel').toList();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  search,
                  const SizedBox(height: 16),
                  const Text(
                    'This is general guidance, not a court filing.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Lawyers', subtitle: 'One-to-one advice'),
                  const SizedBox(height: 12),
                  if (lawyers.isEmpty)
                    const EmptyHint('No lawyers in this practice area yet.')
                  else
                    ...lawyers.map((tutor) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _adviserCard(context, tutor),
                        )),
                  const SizedBox(height: 8),
                  const SectionTitle('Legal counsel', subtitle: 'Written opinions'),
                  const SizedBox(height: 12),
                  if (counsel.isEmpty)
                    const EmptyHint('No legal counsel in this practice area yet.')
                  else
                    ...counsel.map((tutor) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _adviserCard(context, tutor),
                        )),
                ],
              );
            }
            final scope = TrackScope.maybeOf(context);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                search,
                const SizedBox(height: 16),
                if (scope != null && scope.tracks.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in scope.tracks)
                        ChoiceChip(
                          label: Text(item.name),
                          selected: item.slug == track?.slug,
                          onSelected: (_) => scope.onSelect(item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (tutors.isEmpty)
                  EmptyHint(
                    track?.isProgramme == true
                        ? 'No tutors are listed for ${track?.name ?? 'this programme'} yet.'
                        : 'No tutors teach ${track?.name ?? 'this track'} yet. Nimal, Sanduni, and Kasun are on For O/L.',
                  )
                else
                  ...tutors.indexed.map((entry) {
                    final t = entry.$2;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        onTap: () => context.push('/tutor-profile/${t.id}', extra: t),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                              child: Text(
                                t.displayName.isNotEmpty ? t.displayName[0] : 'T',
                                style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: AppColors.tealDeep),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  Text(t.subjectLabel, style: const TextStyle(color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.thumb_up_alt_rounded, size: 14, color: AppColors.amber),
                                      const SizedBox(width: 4),
                                      Text('${t.satisfactionPoints} points', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                          ],
                        ),
                      ).animate().fadeIn(delay: (80 * entry.$1).ms),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _adviserCard(BuildContext context, TutorProfile tutor) {
    final role = tutor.user?.roleLabel ?? 'Adviser';
    return SoftCard(
      onTap: () => context.push('/tutor-profile/${tutor.id}', extra: tutor),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
            child: Text(
              tutor.displayName.isNotEmpty ? tutor.displayName[0] : 'A',
              style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: AppColors.tealDeep),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tutor.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('$role · ${tutor.subjectLabel}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.thumb_up_alt_rounded, size: 14, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Text('${tutor.satisfactionPoints} points', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _QuestionsTab extends StatefulWidget {
  const _QuestionsTab();

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  final controller = TextEditingController();
  List<Subject> subjects = [];
  List<TutorProfile> tutors = [];
  List<QuestionModel> questions = [];
  Subject? selectedSubject;
  TutorProfile? selectedTutor;
  bool loading = true;
  bool submitting = false;
  String? loadedKey;
  int seenRevision = -1;
  String query = '';
  String queue = 'active';
  String? attachmentPath;
  String? attachmentName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = TabFocus.of(context);
    final revision = context.watch<ApiClient>().revision;
    final key = _selectionKey(context);
    if (key == 'waiting') return;
    final first = loadedKey == null;
    final stale = revision != seenRevision;
    if (!first && key == loadedKey && !(focus == 2 && stale)) return;
    loadedKey = key;
    if (focus == 2) seenRevision = revision;
    _load(force: stale && !first);
  }

  Future<void> _load({bool force = false}) async {
    final api = context.read<ApiClient>();
    final user = context.read<AuthState>().user;
    final area = PracticeScope.maybeOf(context)?.selected;
    if (questions.isEmpty) setState(() => loading = true);
    try {
      final tutorFuture = user?.isLaw == true
          ? api.tutors(division: 'law', subject: area?.slug, force: force)
          : api.tutors(division: 'tutor', force: force);
      final results = await Future.wait([
        api.activeTutorUserIds(force: force),
        tutorFuture,
        api.questions(force: force),
      ]);
      final paidIds = results[0] as Set<int>;
      final all = results[1] as List<TutorProfile>;
      tutors = all.where((tutor) => paidIds.contains(tutor.userId)).toList();
      if (selectedTutor == null || !tutors.any((tutor) => tutor.id == selectedTutor!.id)) {
        selectedTutor = tutors.isNotEmpty ? tutors.first : null;
      }
      _subjectsForSelectedTutor();
      questions = results[2] as List<QuestionModel>;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _subjectsForSelectedTutor() {
    subjects = selectedTutor?.subjects ?? const [];
    if (selectedSubject == null || !subjects.any((subject) => subject.id == selectedSubject!.id)) {
      selectedSubject = subjects.isNotEmpty ? subjects.first : null;
    }
  }

  bool _inQueue(QuestionModel q) => queue == 'closed' ? q.status == 'closed' : q.status != 'closed';

  Future<void> _pick(String kind) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kind == 'video' ? ['mp4', 'mov'] : ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = picked?.files.single;
    if (file?.path == null) return;
    setState(() {
      attachmentPath = file!.path;
      attachmentName = file.name;
    });
  }

  Future<void> _submit() async {
    if (selectedTutor == null) return;
    if (controller.text.trim().isEmpty && attachmentPath == null) return;
    setState(() => submitting = true);
    try {
      await context.read<ApiClient>().askQuestion(
            tutorId: selectedTutor!.userId,
            subjectId: selectedSubject?.id,
            body: controller.text.trim(),
            filePath: attachmentPath,
            filename: attachmentName,
          );
      controller.clear();
      attachmentPath = null;
      attachmentName = null;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question posted to API')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    final area = PracticeScope.maybeOf(context)?.selected;
    return Scaffold(
      appBar: AppBar(title: Text(law ? 'Ask for advice' : 'Instant question')),
      body: loading
          ? const PageSkeleton.list()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        law ? 'Ask a lawyer or counsel' : 'Ask your tutor anytime',
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        law
                            ? 'General guidance on ${area?.name ?? 'this practice area'}. Not a court filing.'
                            : 'Your tutor replies here.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      if (tutors.isEmpty)
                        Text(
                          law
                              ? 'You can ask an adviser after you have an active paid package with them.'
                              : 'You can ask a tutor after you have an active paid package with them.',
                          style: const TextStyle(color: AppColors.muted, height: 1.35),
                        )
                      else
                        DropdownButtonFormField<TutorProfile>(
                          initialValue: selectedTutor,
                          items: tutors
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(law ? '${t.displayName} · ${t.user?.roleLabel ?? 'Adviser'}' : t.displayName),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            selectedTutor = v;
                            _subjectsForSelectedTutor();
                          }),
                          decoration: InputDecoration(labelText: law ? 'Lawyer or counsel' : 'Tutor'),
                        ),
                      if (!law && subjects.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Subject>(
                          initialValue: selectedSubject,
                          items: subjects
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedSubject = v),
                          decoration: const InputDecoration(labelText: 'Subject'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Your question', alignLabelWithHint: true),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: submitting ? null : () => _pick('image'),
                              icon: const Icon(Icons.photo_outlined),
                              label: const Text('Photo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: submitting ? null : () => _pick('video'),
                              icon: const Icon(Icons.videocam_outlined),
                              label: const Text('Video'),
                            ),
                          ),
                        ],
                      ),
                      if (attachmentPath != null) ...[
                        const SizedBox(height: 12),
                        LinkedFile(localPath: attachmentPath, name: attachmentName),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() {
                              attachmentPath = null;
                              attachmentName = null;
                            }),
                            child: const Text('Remove file'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting || selectedTutor == null ? null : _submit,
                          child: Text(submitting ? 'Sending…' : 'Submit question'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle('Your questions'),
                const SizedBox(height: 12),
                QuestionQueueTabs(
                  selected: queue,
                  activeCount: questions.where((q) => q.status != 'closed').length,
                  closedCount: questions.where((q) => q.status == 'closed').length,
                  onChanged: (value) => setState(() => queue = value),
                ),
                const SizedBox(height: 12),
                AppSearchField(
                  hint: 'Search your questions',
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                if (questions.where((q) => _inQueue(q) && textMatches(query, [q.body, q.subject?.name, q.status])).isEmpty)
                  EmptyHint(queue == 'closed' ? 'No closed questions.' : 'No active questions.')
                else
                ...questions.where((q) => _inQueue(q) && textMatches(query, [q.body, q.subject?.name, q.status])).map((q) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: QuestionTile(
                        question: q,
                        onOpen: () async {
                          final changed = await context.push<bool>('/question/${q.id}', extra: q);
                          if (changed == true && mounted) _load(force: true);
                        },
                      ),
                    )),
              ],
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

IconData _subjectIcon(String? key) {
  return switch (key) {
    'calculate' => Icons.calculate_rounded,
    'science' => Icons.science_rounded,
    'menu_book' => Icons.menu_book_rounded,
    'computer' => Icons.computer_rounded,
    _ => Icons.school_rounded,
  };
}
