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
import '../shared/account_profile.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;
  List<LearningTrack> tracks = [];
  LearningTrack? selected;
  bool tracksReady = false;
  List<Subject> areas = [];
  Subject? area;
  bool areasReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTracks();
      _loadAreas();
    });
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
    final pages = const [
      _StudentHome(),
      _TutorsTab(),
      _QuestionsTab(),
      _PackagesTab(),
      AccountProfile(),
    ];
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
        child: Scaffold(
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            backgroundColor: Theme.of(context).colorScheme.surface,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people_rounded),
                label: law ? 'Advisers' : 'Tutors',
              ),
              const NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help_rounded), label: 'Ask'),
              const NavigationDestination(icon: Icon(Icons.card_membership_outlined), selectedIcon: Icon(Icons.card_membership), label: 'Package'),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
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

  @override
  void initState() {
    super.initState();
    future = Future.value((lessons: <LessonModel>[], questions: <QuestionModel>[], subjects: <Subject>[]));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = _selectionKey(context);
    if (key == 'waiting' || key == loadedKey) return;
    final first = loadedKey == null;
    loadedKey = key;
    final next = _load();
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  Future<({List<LessonModel> lessons, List<QuestionModel> questions, List<Subject> subjects})> _load() async {
    final api = context.read<ApiClient>();
    final user = context.read<AuthState>().user;
    final track = TrackScope.maybeOf(context)?.selected;
    final lessons = await api.lessons();
    final questions = await api.questions();
    final subjects = user?.isLaw == true
        ? await api.subjects(division: user?.division)
        : (track == null || track.isProgramme)
            ? <Subject>[]
            : await api.subjects(division: 'tutor', track: track.slug);
    return (lessons: lessons, questions: questions, subjects: subjects);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    return RefreshIndicator(
      onRefresh: () async => setState(() => future = _load()),
      child: FutureBuilder(
        future: future,
        builder: (context, snap) {
          final scope = TrackScope.maybeOf(context);
          final practice = PracticeScope.maybeOf(context);
          final law = user?.isLaw == true;
          if ((!law && scope?.ready != true) || (law && practice?.ready != true)) {
            return const PageSkeleton.home();
          }
          if (snap.connectionState != ConnectionState.done) {
            return const PageSkeleton.home();
          }
          if (snap.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('API error: ${snap.error}', textAlign: TextAlign.center),
            ));
          }
          final data = snap.data!;
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
                                child: SoftCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Chip(label: Text(q.subject?.name ?? 'General')),
                                          const Spacer(),
                                          StatusPill(
                                            q.status,
                                            color: q.status == 'open' ? AppColors.coral : AppColors.teal,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(q.body, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      if (q.replies.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(q.replies.first.content ?? '', style: const TextStyle(color: AppColors.muted)),
                                      ],
                                    ],
                                  ),
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
  String query = '';

  @override
  void initState() {
    super.initState();
    future = Future.value(const []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = _selectionKey(context);
    if (key == 'waiting' || key == loadedKey) return;
    final first = loadedKey == null;
    loadedKey = key;
    final next = _load();
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  Future<List<TutorProfile>> _load() async {
    final api = context.read<ApiClient>();
    final user = context.read<AuthState>().user;
    final track = TrackScope.maybeOf(context)?.selected;
    final division = user?.division;
    if (user?.isLaw == true) {
      final area = PracticeScope.maybeOf(context)?.selected;
      return api.tutors(division: 'law', subject: area?.slug);
    }
    final all = await api.tutors(division: division);
    if (track == null || track.isProgramme) return all;
    final subjects = await api.subjects(division: 'tutor', track: track.slug);
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => future = _load()),
        child: FutureBuilder(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const PageSkeleton.list();
            }
            final tutors = snap.data!.where((tutor) => textMatches(query, [
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
                        onTap: () => context.push('/tutor-profile/${t.id}'),
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
      onTap: () => context.push('/tutor-profile/${tutor.id}'),
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
  String query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = _selectionKey(context);
    if (key == 'waiting' || key == loadedKey) return;
    loadedKey = key;
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final user = context.read<AuthState>().user;
    final track = TrackScope.maybeOf(context)?.selected;
    setState(() => loading = true);
    try {
      if (user?.isLaw == true) {
        final area = PracticeScope.maybeOf(context)?.selected;
        subjects = area == null ? [] : [area];
        tutors = await api.tutors(division: 'law', subject: area?.slug);
      } else if (track != null && !track.isProgramme) {
        subjects = await api.subjects(division: 'tutor', track: track.slug);
        final all = await api.tutors(division: user?.division);
        final slugs = subjects.map((subject) => subject.slug).toSet();
        tutors = all.where((tutor) => tutor.subjects.any((subject) => slugs.contains(subject.slug))).toList();
      } else {
        subjects = [];
        tutors = await api.tutors(division: user?.division);
      }
      questions = await api.questions();
      if (selectedSubject == null || !subjects.any((subject) => subject.id == selectedSubject!.id)) {
        selectedSubject = subjects.isNotEmpty ? subjects.first : null;
      }
      if (selectedTutor == null || !tutors.any((tutor) => tutor.id == selectedTutor!.id)) {
        selectedTutor = tutors.isNotEmpty ? tutors.first : null;
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    if (selectedTutor == null || controller.text.trim().isEmpty) return;
    setState(() => submitting = true);
    try {
      await context.read<ApiClient>().askQuestion(
            tutorId: selectedTutor!.userId,
            subjectId: selectedSubject?.id,
            body: controller.text.trim(),
          );
      controller.clear();
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
                          law ? 'No advisers in this practice area yet.' : 'No tutors on this track yet.',
                          style: const TextStyle(color: AppColors.muted),
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
                          onChanged: (v) => setState(() => selectedTutor = v),
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
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting ? null : _submit,
                          child: Text(submitting ? 'Sending…' : 'Submit question'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle('Your questions'),
                const SizedBox(height: 12),
                AppSearchField(
                  hint: 'Search your questions',
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                ...questions.where((q) => textMatches(query, [q.body, q.subject?.name, q.status])).map((q) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(q.subject?.name ?? 'General', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const Spacer(),
                                StatusPill(
                                  q.status,
                                  color: q.status == 'open' ? AppColors.coral : AppColors.teal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(q.body),
                            if (q.replies.isNotEmpty) ...[
                              const Divider(height: 20),
                              Text(law ? 'Reply' : 'Tutor reply', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.tealDeep)),
                              const SizedBox(height: 4),
                              Text(q.replies.first.content ?? ''),
                            ],
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _PackagesTab extends StatefulWidget {
  const _PackagesTab();

  @override
  State<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<_PackagesTab> {
  late Future<List<PackageModel>> future;
  String query = '';

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().packages(division: context.read<AuthState>().user?.division);
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(law ? 'Consultation packages' : 'Monthly packages')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const PageSkeleton.list();
          final packages = snap.data!.where((package) => textMatches(query, [package.name, package.description])).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppSearchField(
                hint: 'Search packages',
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 16),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bank transfer payment', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Bank: Commercial Bank\nAccount: Sir Gen Ahanna (Pvt) Ltd\nAcc No: 8001234567\nBranch: Colombo',
                      style: TextStyle(height: 1.45, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...packages.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(p.name, style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17)),
                              ),
                              Text(
                                'Rs ${p.price.toStringAsFixed(0)}',
                                style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: AppColors.tealDeep),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p.description ?? '', style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 8),
                          Text(
                            law ? 'Consultation in your practice area' : '${p.weeklyHours} hrs live / week · Instant Q · Screen share',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => context.push('/payment/${p.id}'),
                              child: const Text('Select & pay'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
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
