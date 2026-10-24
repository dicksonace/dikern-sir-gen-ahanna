import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TutorProfileScreen extends StatefulWidget {
  final String id;
  final TutorProfile? initial;
  const TutorProfileScreen({super.key, required this.id, this.initial});

  @override
  State<TutorProfileScreen> createState() => _TutorProfileScreenState();
}

class _TutorProfileScreenState extends State<TutorProfileScreen> {
  TutorProfile? tutor;
  List<PackageModel> packages = [];
  bool loadingPackages = true;

  @override
  void initState() {
    super.initState();
    tutor = widget.initial;
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final division = context.read<AuthState>().user?.division;
    final results = await Future.wait([
      widget.initial != null ? Future<TutorProfile>.value(widget.initial!) : api.tutorShow(int.parse(widget.id)),
      api.packages(division: division),
    ]);
    if (!mounted) return;
    setState(() {
      tutor = results[0] as TutorProfile;
      packages = results[1] as List<PackageModel>;
      loadingPackages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(law ? 'Adviser' : 'Tutor')),
      body: () {
        final tutor = this.tutor;
        if (tutor == null) return const PageSkeleton.list();
        return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                          child: Text(
                            tutor.displayName.isNotEmpty ? tutor.displayName[0] : 'T',
                            style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.tealDeep),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tutor.displayName, style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 20)),
                              Text(tutor.subjectLabel, style: const TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.thumb_up_alt_rounded, size: 16, color: AppColors.amber),
                                  const SizedBox(width: 4),
                                  Text('${tutor.satisfactionPoints} satisfaction points',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(tutor.bio ?? ''),
                    const SizedBox(height: 12),
                    Text('Qualifications: ${tutor.qualifications ?? '-'}'),
                    Text('Experience: ${tutor.experience ?? '-'}'),
                    if (tutor.availableSlots.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Available times', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: tutor.availableSlots.map((s) => Chip(label: Text(s))).toList()),
                    ],
                    if (law) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'This is general guidance, not a court filing.',
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(law ? 'Choose a consultation' : 'Choose a package', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                law ? 'Pay ${tutor.displayName} for this advice.' : 'Pay ${tutor.displayName} for this package.',
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 12),
              if (loadingPackages)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (packages.isEmpty)
                const EmptyHint('No packages are available yet.')
              else
                ...packages.map((package) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(package.name, style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17))),
                                Text('Rs ${package.price.toStringAsFixed(0)}', style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: AppColors.tealDeep)),
                              ],
                            ),
                            if ((package.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(package.description!, style: const TextStyle(color: AppColors.muted)),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              law ? 'Consultation with this adviser' : '${package.weeklyHours} hrs live / week · Instant questions',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => context.push('/payment/${package.id}?tutorId=${tutor.userId}'),
                                child: const Text('Select & pay'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        }(),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final String packageId;
  final int? tutorId;
  const PaymentScreen({super.key, required this.packageId, this.tutorId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PackageModel? package;
  List<TutorProfile> tutors = [];
  TutorProfile? selectedTutor;
  bool loading = true;
  bool submitting = false;
  String? slipPath;
  String? slipName;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    final division = context.read<AuthState>().user?.division;
    final cachedPackages = api.peek<List<PackageModel>>('packages:${division ?? ''}');
    final cachedTutors = api.peek<List<TutorProfile>>('tutors:${division ?? ''}:');
    if (cachedPackages != null && cachedTutors != null) {
      _apply(cachedPackages, cachedTutors);
      loading = false;
    }
    _load();
  }

  void _apply(List<PackageModel> rows, List<TutorProfile> people) {
    tutors = people;
    final packageId = int.parse(widget.packageId);
    package = rows.where((row) => row.id == packageId).firstOrNull ?? (rows.isEmpty ? null : rows.first);
    selectedTutor = null;
    if (widget.tutorId != null) {
      for (final t in tutors) {
        if (t.userId == widget.tutorId) {
          selectedTutor = t;
          break;
        }
      }
    } else if (tutors.isNotEmpty) {
      selectedTutor = tutors.first;
    }
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final division = context.read<AuthState>().user?.division;
    final results = await Future.wait([
      api.packages(division: division),
      api.tutors(division: division),
    ]);
    if (!mounted) return;
    setState(() {
      _apply(results[0] as List<PackageModel>, results[1] as List<TutorProfile>);
      loading = false;
    });
  }

  Future<void> _chooseSlip() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: false,
    );
    final file = picked?.files.single;
    final path = file?.path;
    if (path == null || !mounted) return;
    setState(() {
      slipPath = path;
      slipName = file?.name ?? 'slip';
    });
  }

  Future<void> _submit() async {
    final path = slipPath;
    if (selectedTutor == null || package == null || path == null) return;
    setState(() => submitting = true);
    try {
      await context.read<ApiClient>().subscribe(
            tutorId: selectedTutor!.userId,
            packageId: package!.id,
            slipPath: path,
            slipName: slipName ?? 'slip',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment slip submitted — waiting for admin verification')),
      );
      context.pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Bank transfer')),
      body: loading
          ? const PageSkeleton.list()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package?.name ?? '', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${package?.price.toStringAsFixed(0) ?? '0'} / month',
                        style: GoogleFonts.sora(fontWeight: FontWeight.w800, color: AppColors.tealDeep, fontSize: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(package?.description ?? '', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(law ? 'Adviser' : 'Tutor', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        selectedTutor?.displayName ?? (law ? 'Adviser' : 'Tutor'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if ((selectedTutor?.subjectLabel ?? '').isNotEmpty)
                        Text(selectedTutor!.subjectLabel, style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transfer to', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                        'Bank: Commercial Bank\nAccount Name: Sir Gen Ahanna (Pvt) Ltd\nAccount No: 8001234567\nBranch: Colombo',
                        style: TextStyle(height: 1.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload payment slip', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: submitting ? null : _chooseSlip,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(slipPath == null ? 'Choose bank slip image' : 'Choose a different file'),
                      ),
                      if (slipName != null) ...[
                        const SizedBox(height: 8),
                        Text(slipName!, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Text('Check this is the right slip, then submit it.'),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (slipPath != null && !submitting) ? _submit : null,
                          child: Text(submitting ? 'Submitting…' : 'Submit for verification'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class LiveLessonScreen extends StatelessWidget {
  const LiveLessonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final law = context.watch<AuthState>().user?.isLaw ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1F22),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(law ? 'Consultation' : 'Live classroom'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF124E52), Color(0xFF1B4965)]),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded, color: Colors.white70, size: 54),
                          const SizedBox(height: 10),
                          Text(law ? 'Adviser' : 'Tutor camera', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            law ? 'Consultation marked live via API' : 'Lesson marked live via API · WebRTC later',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Container(
                        width: 110,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, color: Colors.white70),
                            SizedBox(height: 6),
                            Text('You', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ctl(Icons.mic, 'Mute'),
                  _ctl(Icons.videocam, 'Video'),
                  _ctl(Icons.screen_share, 'Share'),
                  _ctl(Icons.call_end, 'End', danger: true, onTap: () => context.pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctl(IconData icon, String label, {bool danger = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: danger ? AppColors.coral : AppColors.teal.withValues(alpha: 0.12),
            child: Icon(icon, color: danger ? Colors.white : AppColors.tealDeep),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
