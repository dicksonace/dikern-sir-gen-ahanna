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

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _StudentHome(),
      _TutorsTab(),
      _QuestionsTab(),
      _PackagesTab(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.teal.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Tutors'),
          NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help_rounded), label: 'Ask'),
          NavigationDestination(icon: Icon(Icons.card_membership_outlined), selectedIcon: Icon(Icons.card_membership), label: 'Package'),
        ],
      ),
    );
  }
}

class _StudentHome extends StatefulWidget {
  const _StudentHome();

  @override
  State<_StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<_StudentHome> {
  late Future<({List<LessonModel> lessons, List<QuestionModel> questions, List<Subject> subjects})> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<({List<LessonModel> lessons, List<QuestionModel> questions, List<Subject> subjects})> _load() async {
    final api = context.read<ApiClient>();
    final lessons = await api.lessons();
    final questions = await api.questions();
    final subjects = await api.subjects();
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
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await context.read<AuthState>().logout();
                                if (context.mounted) context.go('/welcome');
                              },
                              icon: const Icon(Icons.logout_rounded, color: Colors.white),
                            ),
                            const Spacer(),
                            const Text('Student · live API', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          'Ayubowan, ${user?.name.split(' ').first ?? 'Student'}',
                          style: GoogleFonts.sora(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text('Data loaded from Laravel API', style: TextStyle(color: Colors.white.withValues(alpha: 0.88))),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _MiniStat('${upcoming.length}', 'Upcoming'),
                            const SizedBox(width: 10),
                            _MiniStat('$openQs', 'Open Q'),
                            const SizedBox(width: 10),
                            _MiniStat('${data.subjects.length}', 'Subjects'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                sliver: SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Upcoming live lesson', subtitle: 'From /api/lessons'),
                        const SizedBox(height: 12),
                        if (upcoming.isEmpty)
                          const EmptyHint('No upcoming lessons yet.')
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
                                      Text('with ${lesson.tutor?.name ?? 'Tutor'}', style: const TextStyle(color: AppColors.muted)),
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
                                              label: const Text('Join class'),
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
                        const SectionTitle('Subjects', subtitle: 'From /api/subjects'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
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
                        const SizedBox(height: 18),
                        const SectionTitle('Recent support', subtitle: 'From /api/questions'),
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

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().tutors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a tutor')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => future = context.read<ApiClient>().tutors()),
        child: FutureBuilder(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tutors = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: tutors.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final t = tutors[i];
                return SoftCard(
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
                ).animate().fadeIn(delay: (80 * i).ms);
              },
            );
          },
        ),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() => loading = true);
    try {
      subjects = await api.subjects();
      tutors = await api.tutors();
      questions = await api.questions();
      selectedSubject ??= subjects.isNotEmpty ? subjects.first : null;
      selectedTutor ??= tutors.isNotEmpty ? tutors.first : null;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Instant question')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask your tutor anytime', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: 6),
                      const Text('Posts to POST /api/questions', style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<TutorProfile>(
                        initialValue: selectedTutor,
                        items: tutors
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedTutor = v),
                        decoration: const InputDecoration(labelText: 'Tutor'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Subject>(
                        initialValue: selectedSubject,
                        items: subjects
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedSubject = v),
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
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
                ...questions.map((q) => Padding(
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
                              Text('Tutor reply', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.tealDeep)),
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

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().packages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly packages')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final packages = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                          Text('${p.weeklyHours} hrs live / week · Instant Q · Screen share',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
