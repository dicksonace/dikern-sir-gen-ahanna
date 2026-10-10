import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _AdminDashboard(),
      _PendingTutors(),
      _PendingPayments(),
      _AdminMore(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.teal.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg), label: 'Tutors'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Manage'),
        ],
      ),
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  late Future<AdminStats> future;

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().adminStats();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => future = context.read<ApiClient>().adminStats()),
      child: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const PageSkeleton.home();
          }
          final s = snap.data!;
          final stats = [
            ('Students', '${s.students}', Icons.school_rounded),
            ('Approved tutors', '${s.tutors}', Icons.record_voice_over_rounded),
            ('Pending tutors', '${s.pendingTutors}', Icons.hourglass_top_rounded),
            ('Pending payments', '${s.pendingPayments}', Icons.payments_rounded),
            ('Active packages', '${s.activeSubscriptions}', Icons.card_membership_rounded),
            ('Open questions', '${s.openQuestions}', Icons.help_rounded),
          ];

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
                            const Text('Admin', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text('Platform control', style: GoogleFonts.sora(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('People, lessons, and payments', style: TextStyle(color: Colors.white.withValues(alpha: 0.88))),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverToBoxAdapter(
                  child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        for (var i = 0; i < stats.length; i++)
                          SoftCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(stats[i].$3, color: AppColors.teal),
                                const Spacer(),
                                Text(stats[i].$2, style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800)),
                                Text(stats[i].$1, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                          ).animate().fadeIn(delay: (60 * i).ms),
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

class _PendingTutors extends StatefulWidget {
  const _PendingTutors();

  @override
  State<_PendingTutors> createState() => _PendingTutorsState();
}

class _PendingTutorsState extends State<_PendingTutors> {
  late Future<List<TutorProfile>> future;
  String query = '';

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().pendingTutors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutor approvals')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => future = context.read<ApiClient>().pendingTutors()),
        child: FutureBuilder(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) return const PageSkeleton.list();
            final list = snap.data!.where((tutor) => textMatches(query, [
              tutor.displayName,
              tutor.subjectLabel,
              tutor.bio,
            ])).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AppSearchField(
                    hint: 'Search people',
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No pending tutors')),
                        ])
                      : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final t = list[i];
                return SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                            child: Text(
                              t.displayName.isNotEmpty ? t.displayName[0] : 'T',
                              style: const TextStyle(color: AppColors.tealDeep, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                Text('${t.subjectLabel} · ${t.experience ?? ''}', style: const TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          ),
                          const StatusPill('Pending', color: AppColors.coral),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(t.bio ?? ''),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await context.read<ApiClient>().approveTutor(t.id);
                            setState(() => future = context.read<ApiClient>().pendingTutors());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tutor approved via API')),
                              );
                            }
                          },
                          child: const Text('Approve tutor'),
                        ),
                      ),
                    ],
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

class _PendingPayments extends StatefulWidget {
  const _PendingPayments();

  @override
  State<_PendingPayments> createState() => _PendingPaymentsState();
}

class _PendingPaymentsState extends State<_PendingPayments> {
  late Future<List<PaymentModel>> future;
  String query = '';

  @override
  void initState() {
    super.initState();
    future = context.read<ApiClient>().pendingPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank slip verification')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => future = context.read<ApiClient>().pendingPayments()),
        child: FutureBuilder(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) return const PageSkeleton.list();
            final list = snap.data!.where((payment) {
              final packageName = (payment.subscription?['package'] as Map?)?['name']?.toString();
              final tutorName = (payment.subscription?['tutor'] as Map?)?['name']?.toString();
              return textMatches(query, [payment.student?.name, packageName, tutorName, payment.status]);
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AppSearchField(
                    hint: 'Search payments',
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No pending payments — subscribe as student to create one')),
                        ])
                      : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = list[i];
                final packageName = (p.subscription?['package'] as Map?)?['name']?.toString() ?? 'Package';
                final tutorName = (p.subscription?['tutor'] as Map?)?['name']?.toString() ?? 'Tutor';
                return SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('$packageName · Rs ${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          const StatusPill('Pending', color: AppColors.amber),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Student: ${p.student?.name ?? '-'}'),
                      Text('Tutor: $tutorName'),
                      Text('Slip: ${p.slipPath ?? '-'}'),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await context.read<ApiClient>().verifyPayment(p.id);
                            setState(() => future = context.read<ApiClient>().pendingPayments());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Payment verified · package activated · commission created')),
                              );
                            }
                          },
                          child: const Text('Verify & activate package'),
                        ),
                      ),
                    ],
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

class _AdminMore extends StatelessWidget {
  const _AdminMore();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage platform')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API connected', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Packages, tutors, payments, commissions are driven by Laravel endpoints.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await context.read<AuthState>().logout();
                    if (context.mounted) context.go('/welcome');
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
