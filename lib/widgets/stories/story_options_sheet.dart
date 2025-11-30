import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/report_model.dart';
import 'package:z/models/story_model.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/services/content/stories/story_service.dart';
import 'package:z/widgets/moderation/block_confirmation_dialog.dart';
import 'package:z/widgets/moderation/report_dialog.dart';

class StoryOptionsSheet extends ConsumerStatefulWidget {
  final StoryModel story;
  final VoidCallback? onDeleted;

  const StoryOptionsSheet({
    super.key,
    required this.story,
    this.onDeleted,
  });

  @override
  ConsumerState<StoryOptionsSheet> createState() => _StoryOptionsSheetState();
}

class _StoryOptionsSheetState extends ConsumerState<StoryOptionsSheet> {
  bool _isDeleting = false;
  bool _isReporting = false;

  Future<void> _handleDelete() async {
    if (_isDeleting) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BlockConfirmationDialog(
        title: 'Delete Story',
        message: 'Are you sure you want to delete this story? This action cannot be undone.',
        confirmText: 'Delete',
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final storyService = StoryService();

    try {
      await storyService.deleteStory(
        storyId: widget.story.id,
        userId: currentUser.uid,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _handleReport() async {
    if (_isReporting) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isReporting = true);

    try {
      await showDialog(
        context: context,
        builder: (context) => ReportDialog(
          reportType: ReportType.story,
          storyId: widget.story.id,
          reporterId: currentUser.uid,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final isOwner = currentUser?.uid == widget.story.userId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: _isDeleting ? null : _handleDelete,
              trailing: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          if (!isOwner)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: _isReporting ? null : _handleReport,
              trailing: _isReporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

