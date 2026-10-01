import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/app_settings.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'account_forms.dart';

class AccountProfile extends StatelessWidget {
  const AccountProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final settings = context.watch<AppSettings>();
    final profile = user?.tutorProfile;
    final name = user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'Account';
    final initial = name.substring(0, 1).toUpperCase();
    final muted = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA8B4B8) : AppColors.muted;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            height: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Text(
                        initial,
                        style: GoogleFonts.sora(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user?.roleLabel ?? 'Account',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.86)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile != null) ...[
                  _AboutCard(profile: profile, muted: muted, law: user?.isLaw == true),
                  const SizedBox(height: 22),
                ] else ...[
                  _AccountCard(user: user),
                  const SizedBox(height: 22),
                ],
                Text('Settings', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit details',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditDetailsScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change password',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('App theme', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Light or dark, for every screen.', style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeChoice(
                              icon: Icons.light_mode_rounded,
                              label: 'Light',
                              selected: settings.mode == ThemeMode.light,
                              onTap: () => settings.setMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ThemeChoice(
                              icon: Icons.dark_mode_rounded,
                              label: 'Dark',
                              selected: settings.mode == ThemeMode.dark,
                              onTap: () => settings.setMode(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () async {
                      await context.read<AuthState>().logout();
                      if (context.mounted) context.go('/welcome');
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.coral),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Sign out', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.coral)),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.coral),
                        ],
                      ),
                    ),
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

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final TutorProfile profile;
  final Color muted;
  final bool law;

  const _AboutCard({required this.profile, required this.muted, required this.law});

  @override
  Widget build(BuildContext context) {
    final status = profile.status.isEmpty ? 'pending' : profile.status;
    final approved = status == 'approved';
    final subjects = profile.subjectLabel;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subjects.isEmpty ? (law ? 'Practice' : 'Subjects') : subjects,
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                status[0].toUpperCase() + status.substring(1),
                color: approved ? AppColors.teal : AppColors.amber,
              ),
            ],
          ),
          if ((profile.bio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(profile.bio!.trim(), style: TextStyle(height: 1.4, color: muted)),
          ],
          const SizedBox(height: 14),
          _Fact(icon: Icons.school_outlined, label: 'Qualifications', value: _orDash(profile.qualifications)),
          const SizedBox(height: 10),
          _Fact(icon: Icons.work_outline_rounded, label: 'Experience', value: _orDash(profile.experience)),
          if (profile.availableSlots.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Available times', style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.availableSlots.map((slot) => Chip(label: Text(slot))).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.thumb_up_alt_rounded, color: AppColors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${profile.satisfactionPoints} satisfaction points',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AppUser? user;

  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final side = user?.isLaw == true ? 'Law advice' : 'Learning';
    return SoftCard(
      child: Column(
        children: [
          _Fact(icon: Icons.mail_outline_rounded, label: 'Email', value: _orDash(user?.email)),
          const SizedBox(height: 10),
          _Fact(icon: Icons.phone_outlined, label: 'Phone', value: _orDash(user?.phone)),
          const SizedBox(height: 10),
          _Fact(icon: Icons.account_tree_outlined, label: 'Side', value: side),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? AppColors.teal : (dark ? const Color(0xFF243032) : AppColors.sand),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.teal),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _orDash(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '—' : text;
}
