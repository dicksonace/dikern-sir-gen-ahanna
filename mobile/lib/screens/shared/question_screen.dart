import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/linked_file.dart';

String questionStatusLabel(String status) {
  switch (status) {
    case 'answered':
      return 'Answered';
    case 'closed':
      return 'Closed';
    default:
      return 'Open';
  }
}

Color questionStatusColor(String status) {
  switch (status) {
    case 'open':
      return AppColors.coral;
    case 'closed':
      return AppColors.muted;
    default:
      return AppColors.teal;
  }
}

class QuestionQueueTabs extends StatelessWidget {
  final String selected;
  final int activeCount;
  final int closedCount;
  final ValueChanged<String> onChanged;

  const QuestionQueueTabs({
    super.key,
    required this.selected,
    required this.activeCount,
    required this.closedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.06) : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _tab(context, 'Active', 'active', activeCount),
          _tab(context, 'Closed', 'closed', closedCount),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, String value, int count) {
    final on = selected == value;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: on ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '$label  $count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : (dark ? Colors.white : AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuestionTile extends StatelessWidget {
  final QuestionModel question;
  final VoidCallback onOpen;

  const QuestionTile({super.key, required this.question, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final latest = question.replies.isEmpty ? null : question.replies.last;
    final replyLine = latest == null
        ? 'No reply yet'
        : '${latest.tutor?.name ?? 'Reply'}: ${_replyPreview(latest)}';

    return SoftCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.subject?.name ?? 'General',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(questionStatusLabel(question.status), color: questionStatusColor(question.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(replyLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }

  String _replyPreview(QuestionReply reply) {
    final text = (reply.content ?? '').trim();
    if (text.isNotEmpty) return text;
    switch (reply.attachmentKind) {
      case 'image':
        return 'Sent a photo';
      case 'video':
        return 'Sent a video';
      default:
        return reply.attachmentUrl != null ? 'Sent a file' : 'Replied';
    }
  }
}

class QuestionScreen extends StatefulWidget {
  final int id;
  final QuestionModel? initial;

  const QuestionScreen({super.key, required this.id, this.initial});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  QuestionModel? question;
  bool loading = true;
  bool busy = false;
  bool changed = false;
  String? error;

  @override
  void initState() {
    super.initState();
    question = widget.initial;
    loading = widget.initial == null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = question == null;
      error = null;
    });
    try {
      final row = await api.question(widget.id, force: question != null);
      if (mounted) setState(() => question = row);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _close() async {
    final law = context.read<AuthState>().user?.isLaw ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close question'),
        content: Text(
          law
              ? 'Close this question? You can still read it. No new replies can be added.'
              : 'Close this question? You can still open it and read the replies. No new replies can be added.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep open')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      final row = await context.read<ApiClient>().closeQuestion(widget.id);
      if (mounted) {
        setState(() {
          question = row;
          changed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reply(String type) async {
    String? filePath;
    String? filename;
    if (type != 'text') {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: switch (type) {
          'video' => ['mp4', 'mov'],
          'doc' => ['pdf'],
          _ => ['jpg', 'jpeg', 'png', 'webp'],
        },
      );
      final file = picked?.files.single;
      if (file?.path == null || !mounted) return;
      filePath = file!.path;
      filename = file.name;
    }
    if (!mounted) return;
    final law = context.read<AuthState>().user?.isLaw ?? false;
    final controller = TextEditingController(
      text: type == 'text' ? (law ? 'Here is guidance on your question.' : 'Here is a quick explanation from your tutor.') : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'text' ? 'Reply' : 'Send $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (filePath != null) ...[
              LinkedFile(localPath: filePath, name: filename),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(hintText: type == 'text' ? 'Your reply' : 'Optional note'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<ApiClient>().replyQuestion(
            widget.id,
            type: type == 'doc' ? 'document' : type,
            content: controller.text,
            filePath: filePath,
            filename: filename,
          );
      changed = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().user;
    final q = question;
    final law = me?.isLaw ?? false;
    final isTutor = q != null && me?.id == q.tutorId;
    final closed = q?.status == 'closed';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.pop(changed);
      },
      child: Scaffold(
      appBar: AppBar(title: Text(q?.subject?.name ?? 'Question')),
      body: loading
          ? const PageSkeleton.list()
          : q == null
              ? Center(child: Text(error ?? 'This question could not be opened.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text(_statusNote(q, law, isTutor), style: const TextStyle(color: AppColors.muted, height: 1.35)),
                    const SizedBox(height: 14),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  q.student?.name ?? 'Student',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              StatusPill(questionStatusLabel(q.status), color: questionStatusColor(q.status)),
                            ],
                          ),
                          if (q.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(_when(q.createdAt!), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                          const SizedBox(height: 10),
                          Text(q.body),
                          if (q.attachmentUrl != null) ...[
                            const SizedBox(height: 10),
                            LinkedFile(url: q.attachmentUrl, kind: q.attachmentKind),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Replies'),
                    const SizedBox(height: 12),
                    if (q.replies.isEmpty)
                      const EmptyHint('No reply yet.')
                    else
                      ...q.replies.map((reply) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(reply.tutor?.name ?? (law ? 'Adviser' : 'Tutor'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  if (reply.createdAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(_when(reply.createdAt!), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                  ],
                                  if ((reply.content ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(reply.content!),
                                  ],
                                  if (reply.attachmentUrl != null) ...[
                                    const SizedBox(height: 10),
                                    LinkedFile(url: reply.attachmentUrl, kind: reply.attachmentKind),
                                  ],
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
      bottomNavigationBar: q == null || closed
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isTutor) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(onPressed: busy ? null : () => _reply('text'), child: const Text('Text')),
                          OutlinedButton(onPressed: busy ? null : () => _reply('image'), child: const Text('Photo')),
                          OutlinedButton(onPressed: busy ? null : () => _reply('video'), child: const Text('Video')),
                          OutlinedButton(onPressed: busy ? null : () => _reply('doc'), child: const Text('PDF')),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton(
                      onPressed: busy ? null : _close,
                      child: Text(busy ? 'Saving…' : 'Close question'),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  String _statusNote(QuestionModel q, bool law, bool isTutor) {
    final person = law ? 'adviser' : 'tutor';
    if (q.status == 'closed') {
      return 'This question is closed. You can still read it, and nobody can add another reply.';
    }
    if (isTutor) {
      return q.status == 'answered'
          ? 'You have replied. Close it when the ${law ? 'client' : 'student'} is finished, or send another reply.'
          : 'This is still open. Reply here, then close it when the conversation is finished.';
    }
    if (q.status == 'answered') {
      return 'Your $person has replied. Close the question when you are finished.';
    }
    return 'Waiting for your $person. You can close it if you no longer need an answer.';
  }

  String _when(DateTime value) => DateFormat('d MMM, h:mm a').format(value.toLocal());
}
