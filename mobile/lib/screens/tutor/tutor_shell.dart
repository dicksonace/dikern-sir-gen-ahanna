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
import '../shared/account_profile.dart';

class TutorShell extends StatefulWidget {
  const TutorShell({super.key});

  @override
  State<TutorShell> createState() => _TutorShellState();
}

class _TutorShellState extends State<TutorShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _TutorHome(),
      _TutorQuestions(),
      _TutorEarnings(),
      AccountProfile(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        backgroundColor: Theme.of(context).colorScheme.surface,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'Earn'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
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

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<({List<LessonModel> lessons, List<QuestionModel> questions})> _load() async {
    final api = context.read<ApiClient>();
    return (lessons: await api.lessons(), questions: await api.questions());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final points = user?.tutorProfile?.satisfactionPoints ?? 0;

    return RefreshIndicator(
      onRefresh: () async => setState(() => future = _load()),
      child: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const PageSkeleton.home();
          final data = snap.data!;
          final next = data.lessons.where((l) => l.status == 'scheduled' || l.status == 'live').toList();
          final openQs = data.questions.where((q) => q.status == 'open').length;
          final law = user?.isLaw == true;

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
  String query = '';

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().questions();
  }

  Future<void> _reply(QuestionModel q, String type) async {
    final controller = TextEditingController(
      text: type == 'text'
          ? (context.read<AuthState>().user?.isLaw == true
              ? 'Here is guidance on your question.'
              : 'Here is a quick explanation from your tutor.')
          : 'Attached $type reply (prototype path)',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply ($type)'),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<ApiClient>().replyQuestion(q.id, type: type == 'doc' ? 'document' : type, content: controller.text);
    setState(() => future = context.read<ApiClient>().questions());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent via API')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(law ? 'Client questions' : 'Student questions')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => future = context.read<ApiClient>().questions()),
        child: FutureBuilder(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) return const PageSkeleton.list();
            final questions = snap.data!.where((question) => textMatches(query, [
              question.body,
              question.student?.name,
              question.subject?.name,
              question.status,
            ])).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AppSearchField(
                    hint: 'Search questions',
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                Expanded(
                  child: questions.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No questions yet'))])
                      : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: questions.length,
              itemBuilder: (context, i) {
                final q = questions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(label: Text(q.subject?.name ?? 'General')),
                            const Spacer(),
                            StatusPill(q.status, color: q.status == 'open' ? AppColors.coral : AppColors.teal),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(q.student?.name ?? 'Student', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        Text(q.body, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (q.status == 'open') ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(onPressed: () => _reply(q, 'text'), child: const Text('Text')),
                              OutlinedButton(onPressed: () => _reply(q, 'image'), child: const Text('Image')),
                              OutlinedButton(onPressed: () => _reply(q, 'video'), child: const Text('Video')),
                              OutlinedButton(onPressed: () => _reply(q, 'doc'), child: const Text('Document')),
                            ],
                          ),
                        ] else if (q.replies.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(q.replies.first.content ?? '', style: const TextStyle(color: AppColors.muted)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
                ),
              ],
            );
          },
        ),
      ),
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
  String query = '';

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().tutorEarnings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly earnings')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const PageSkeleton.list();
          final items = snap.data!;
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
      ),
    );
  }
}

