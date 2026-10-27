import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class LinkedFile extends StatelessWidget {
  final String? url;
  final String? localPath;
  final String? kind;
  final String? name;

  const LinkedFile({super.key, this.url, this.localPath, this.kind, this.name});

  String get _caption {
    final title = name ?? (_kind == 'video' ? 'Video' : _kind == 'image' ? 'Photo' : 'File');
    final size = _fileSize;
    if (size == null) return title;
    return '$title · $size';
  }

  String? get _fileSize {
    final path = localPath;
    if (path == null || path.isEmpty) return null;
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return null;
    }
  }

  String get _kind {
    if (kind != null && kind!.isNotEmpty) return kind!;
    final value = (localPath ?? name ?? url ?? '').toLowerCase();
    if (value.endsWith('.mp4') || value.endsWith('.mov')) return 'video';
    if (value.endsWith('.jpg') || value.endsWith('.jpeg') || value.endsWith('.png') || value.endsWith('.webp')) {
      return 'image';
    }
    return 'file';
  }

  @override
  Widget build(BuildContext context) {
    if ((url == null || url!.isEmpty) && (localPath == null || localPath!.isEmpty)) {
      return const SizedBox.shrink();
    }

    if (_kind == 'image' && localPath != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openImage(context, Image.file(File(localPath!))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(localPath!), height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(_caption, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
    }

    if (_kind == 'image' && url != null) {
      final token = context.read<ApiClient>().token;
      final headers = {
        'Accept': 'image/*',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      return GestureDetector(
        onTap: () => _openImage(context, Image.network(url!, headers: headers)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            headers: headers,
            errorBuilder: (_, _, _) => const _FileTile(icon: Icons.broken_image_outlined, label: 'Photo could not load'),
          ),
        ),
      );
    }

    final label = _caption;
    return _FileTile(
      icon: _kind == 'video' ? Icons.play_circle_fill_rounded : Icons.insert_drive_file_outlined,
      label: label,
      onTap: _kind == 'video' && (url != null || localPath != null)
          ? () {
              final token = context.read<ApiClient>().token;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _VideoPreview(url: url, path: localPath, token: token),
                ),
              );
            }
          : null,
    );
  }
}

void _openImage(BuildContext context, Image image) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImagePreview(image: image)));
}

class _ImagePreview extends StatelessWidget {
  final Image image;

  const _ImagePreview({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Photo')),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image(
            image: image.image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('Photo could not load', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FileTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.teal.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.tealDeep),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String? url;
  final String? path;
  final String? token;

  const _VideoPreview({this.url, this.path, this.token});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    if (widget.path != null) {
      controller = VideoPlayerController.file(File(widget.path!));
    } else {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url!),
        httpHeaders: {
          if (widget.token != null) 'Authorization': 'Bearer ${widget.token}',
        },
      );
    }
    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        controller.play();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Video')),
      body: Center(
        child: controller.value.isInitialized
            ? AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller))
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
