import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';

class EditDetailsScreen extends StatefulWidget {
  const EditDetailsScreen({super.key});

  @override
  State<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends State<EditDetailsScreen> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController bio;
  late final TextEditingController qualifications;
  late final TextEditingController experience;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    final profile = user?.tutorProfile;
    name = TextEditingController(text: user?.name ?? '');
    phone = TextEditingController(text: user?.phone ?? '');
    bio = TextEditingController(text: profile?.bio ?? '');
    qualifications = TextEditingController(text: profile?.qualifications ?? '');
    experience = TextEditingController(text: profile?.experience ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    bio.dispose();
    qualifications.dispose();
    experience.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final user = context.read<AuthState>().user;
      final updated = await context.read<ApiClient>().updateProfile(
            name: name.text.trim(),
            phone: phone.text.trim(),
            bio: user?.tutorProfile == null ? null : bio.text.trim(),
            qualifications: user?.tutorProfile == null ? null : qualifications.text.trim(),
            experience: user?.tutorProfile == null ? null : experience.text.trim(),
          );
      if (!mounted) return;
      context.read<AuthState>().applyUser(updated);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = context.watch<AuthState>().user?.tutorProfile != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftCard(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                if (hasProfile) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: bio,
                    decoration: const InputDecoration(labelText: 'About'),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: qualifications, decoration: const InputDecoration(labelText: 'Qualifications')),
                  const SizedBox(height: 12),
                  TextField(controller: experience, decoration: const InputDecoration(labelText: 'Experience')),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
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

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (next.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match.')));
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<ApiClient>().changePassword(
            currentPassword: current.text,
            password: next.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: current,
                  decoration: const InputDecoration(labelText: 'Current password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  decoration: const InputDecoration(labelText: 'New password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update password'),
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = '', this.division = 'tutor'});

  final String initialEmail;
  final String division;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController email;
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool sending = false;
  bool resetting = false;
  bool codeSent = false;
  String? shownCode;

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => sending = true);
    try {
      final resetCode = await context.read<ApiClient>().forgotPassword(email.text.trim(), division: widget.division);
      if (!mounted) return;
      setState(() {
        codeSent = true;
        shownCode = resetCode;
        if (resetCode != null) code.text = resetCode;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _reset() async {
    if (password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match.')));
      return;
    }
    setState(() => resetting = true);
    try {
      await context.read<ApiClient>().resetPassword(
            email: email.text.trim(),
            division: widget.division,
            code: code.text.trim(),
            password: password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset. Sign in with the new password.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.division == 'law'
                      ? 'This resets the Law advice account for this email.'
                      : 'This resets the Learning account for this email.',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: sending ? null : _send,
                  child: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send reset code'),
                ),
                if (codeSent) ...[
                  const SizedBox(height: 18),
                  Text(
                    shownCode == null
                        ? 'Enter the code from your email, then choose a new password.'
                        : 'This local API shows the code here. On a live mailbox it arrives by email.',
                    style: const TextStyle(color: Color(0xFF5C6B73), height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Reset code'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    decoration: const InputDecoration(labelText: 'New password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: resetting ? null : _reset,
                    child: resetting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Reset password'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
