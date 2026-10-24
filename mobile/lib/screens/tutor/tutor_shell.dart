import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/hold_builder.dart';
import '../../widgets/tab_focus.dart';
import '../shared/question_screen.dart';
import '../shared/account_profile.dart';

class TutorShell extends StatefulWidget {
  const TutorShell({super.key});

  @override
  State<TutorShell> createState() => _TutorShellState();
}

class _TutorShellState extends State<TutorShell> with WidgetsBindingObserver {
  int index = 0;
  final visited = <int>{0};
  final pages = const [
    _TutorHome(),
    _TutorQuestions(),
    _TutorEarnings(),
    AccountProfile(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = context.read<ApiClient>();
      api.lessons();
      api.questions();
      api.tutorEarnings();
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
    api.forget('earnings');
    api.bump();
  }

  @override
  Widget build(BuildContext context) {
    return TabFocus(
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'Earn'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    ),
    );
  }
}

class _TutorHome extends StatefulWidget {
  const _TutorHome();

  @override
  State<_TutorHome> createState() => _TutorHomeState();
}

class _TutorHomeState extends State<_TutorHome> {
  late Future<({List<LessonModel> lessons, List<QuestionModel> questions})> future;
  bool ready = false;
  int seenRevision = -1;

  @override
  void initState() {
    super.initState();
    future = Future.value((lessons: <LessonModel>[], questions: <QuestionModel>[]));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final focus = TabFocus.of(context);
    final revision = context.watch<ApiClient>().revision;
    final first = !ready;
    final stale = revision != seenRevision;
    if (!first && !(focus == 0 && stale)) return;
    ready = true;
    if (focus == 0) seenRevision = revision;
    final next = _load(force: stale && !first);
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  Future<({List<LessonModel> lessons, List<QuestionModel> questions})> _load({bool force = false}) async {
    final api = context.read<ApiClient>();
    final results = await Future.wait([
      api.lessons(force: force),
      api.questions(force: force),
    ]);
    return (lessons: results[0] as List<LessonModel>, questions: results[1] as List<QuestionModel>);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final points = user?.tutorProfile?.satisfactionPoints ?? 0;

    if (!ready) return const Scaffold(body: PageSkeleton.home());
    return RefreshIndicator(
      onRefresh: () async => setState(() => future = _load(force: true)),
      child: HoldBuilder(
        future: future,
        loading: const PageSkeleton.home(),
        error: (error) => Center(child: Text('$error')),
        builder: (context, data) {
          final next = data.lessons.where((l) => l.status == 'scheduled' || l.status == 'live').toList();
          final openQs = data.questions.where((q) => q.status == 'open').length;
          final law = user?.isLaw == true;
          final profile = user?.tutorProfile;
          final waiting = profile != null && profile.status != 'approved';

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
                            user?.roleLabel ?? 'Tutor',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('Hello, ${user?.name.split(' ').first ?? 'Tutor'}',
                            style: GoogleFonts.sora(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('$points satisfaction points', style: TextStyle(color: Colors.white.withValues(alpha: 0.88))),
                      ],
                    ),
                  ),
                ),
              ),
              Spad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (waiting) ...[
                      SoftCard(
                        child: Text(
                          profile.status == 'rejected'
                              ? 'An admin did not approve this ${user?.roleLabel.toLowerCase() ?? 'account'} profile. Update it from Profile, then wait for another review.'
                              : 'Waiting for admin approval. ${law ? 'Clients' : 'Students'} cannot see this ${user?.roleLabel.toLowerCase() ?? 'account'} until an admin approves it.',
                          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (next.isNotEmpty) ...[
                      SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam_rounded, color: AppColors.teal),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${next.first.title} · ${next.first.student?.name ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await context.read<ApiClient>().startLesson(next.first.id);
                                if (context.mounted) context.push('/live-lesson');
                              },
                              child: const Text('Start'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SoftCard(
                      child: Column(
                        children: [
                          _row(Icons.help_outline, law ? 'Open client questions' : 'Open student questions', '$openQs waiting'),
                          const Divider(height: 22),
                          _row(Icons.schedule_rounded, law ? 'Consultations loaded' : 'Lessons loaded', '${data.lessons.length} total'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionTitle(law ? 'Consultation history' : 'Lesson history', subtitle: law ? 'Sessions with your clients' : 'Sessions with your students'),
                    const SizedBox(height: 12),
                    ...data.lessons.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SoftCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        l.scheduledAt == null
                                            ? l.status
                                            : DateFormat('EEE d MMM · HH:mm').format(l.scheduledAt!.toLocal()),
                                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(l.status, color: l.status == 'completed' ? AppColors.teal : AppColors.amber),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.teal),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class Spad extends StatelessWidget {
  final Widget child;
  const Spad({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

class _TutorQuestions extends StatefulWidget {
  const _TutorQuestions();

  @override
  State<_TutorQuestions> createState() => _TutorQuestionsState();
}

class _TutorQuestionsState extends State<_TutorQuestions> {
  late Future<List<QuestionModel>> future;
  bool ready = false;
  int seenRevision = -1;
  String query = '';
  String queue = 'active';

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
    final first = !ready;
    final stale = revision != seenRevision;
    if (!first && !(focus == 1 && stale)) return;
    ready = true;
    if (focus == 1) seenRevision = revision;
    final next = context.read<ApiClient>().questions(force: stale && !first);
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(law ? 'Client questions' : 'Student questions')),
      body: ready
          ? RefreshIndicator(
        onRefresh: () async => setState(() => future = context.read<ApiClient>().questions(force: true)),
        child: HoldBuilder(
          future: future,
          loading: const PageSkeleton.list(),
          error: (error) => Center(child: Text('$error')),
          builder: (context, all) {
            final questions = all.where((question) {
              final inQueue = queue == 'closed' ? question.status == 'closed' : question.status != 'closed';
              return inQueue &&
                  textMatches(query, [
                    question.body,
                    question.student?.name,
                    question.subject?.name,
                    question.status,
                  ]);
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      QuestionQueueTabs(
                        selected: queue,
                        activeCount: all.where((q) => q.status != 'closed').length,
                        closedCount: all.where((q) => q.status == 'closed').length,
                        onChanged: (value) => setState(() => queue = value),
                      ),
                      const SizedBox(height: 12),
                      AppSearchField(
                        hint: 'Search questions',
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: questions.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Center(child: Text(queue == 'closed' ? 'No closed questions.' : 'No active questions.')),
                        ])
                      : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: questions.length,
              itemBuilder: (context, i) {
                final q = questions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuestionTile(
                    question: q,
                    onOpen: () async {
                      final changed = await context.push<bool>('/question/${q.id}', extra: q);
                      if (changed == true && mounted) setState(() => future = context.read<ApiClient>().questions(force: true));
                    },
                  ),
                );
              },
            ),
                ),
              ],
            );
          },
        ),
      )
          : const PageSkeleton.list(),
    );
  }
}

class _TutorEarnings extends StatefulWidget {
  const _TutorEarnings();

  @override
  State<_TutorEarnings> createState() => _TutorEarningsState();
}

class _TutorEarningsState extends State<_TutorEarnings> {
  late Future<List<CommissionModel>> future;
  bool ready = false;
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
    final first = !ready;
    final stale = revision != seenRevision;
    if (!first && !(focus == 2 && stale)) return;
    ready = true;
    if (focus == 2) seenRevision = revision;
    final next = context.read<ApiClient>().tutorEarnings(force: stale && !first);
    if (first) {
      future = next;
    } else {
      setState(() => future = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly earnings')),
      body: ready
          ? HoldBuilder(
        future: future,
        loading: const PageSkeleton.list(),
        error: (error) => Center(child: Text('$error')),
        builder: (context, items) {
          final shown = items.where((item) => textMatches(query, [item.month, item.status])).toList();
          final total = items.fold<double>(0, (a, b) => a + b.amount);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commissions', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('Rs ${total.toStringAsFixed(0)}',
                        style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.tealDeep)),
                    const Text('Paid after a payment is verified', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSearchField(
                hint: 'Search months',
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                const EmptyHint('No commissions yet. Appear after admin verifies a payment.')
              else
                ...shown.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.month, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${c.rate.toStringAsFixed(0)}% of Rs ${c.packageAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text('Rs ${c.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      )
          : const PageSkeleton.list(),
    );
  }
}

