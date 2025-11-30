import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/report_model.dart';
import 'package:z/providers/bookmarking_provider.dart';
import 'package:z/providers/moderation_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/moderation/block_confirmation_dialog.dart';
import 'package:z/widgets/moderation/report_dialog.dart';

class ShortVideoOptionsSheet extends ConsumerStatefulWidget {
  final String zapId;
  final String zapUserId;
  final String currentUserId;
  final bool isBookmarked;
  final VoidCallback? onDeleted;

  const ShortVideoOptionsSheet({
    super.key,
    required this.zapId,
    required this.zapUserId,
    required this.currentUserId,
    required this.isBookmarked,
    this.onDeleted,
  });

  @override
  ConsumerState<ShortVideoOptionsSheet> createState() =>
      _ShortVideoOptionsSheetState();
}

class _ShortVideoOptionsSheetState
    extends ConsumerState<ShortVideoOptionsSheet> {
  bool _isBookmarking = false;
  bool _isDeleting = false;
  bool _isBlocking = false;
  bool _isReporting = false;

  Future<void> _handleBookmark() async {
    if (_isBookmarking) return;

    setState(() => _isBookmarking = true);
    final zapService = ref.read(zapServiceProvider(true));
    ref.read(bookmarkingProvider(widget.zapId).notifier).state = true;

    try {
      if (widget.isBookmarked) {
        await zapService.removeBookmark(widget.zapId, widget.currentUserId);
      } else {
        await zapService.bookmarkZap(widget.zapId, widget.currentUserId);
      }
      ref.invalidate(
        isBookmarkedProvider((
          zapId: widget.zapId,
          userId: widget.currentUserId,
        )),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isBookmarked
                ? 'Removed from bookmarks'
                : 'Added to bookmarks'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      ref.read(bookmarkingProvider(widget.zapId).notifier).state = false;
      if (mounted) {
        setState(() => _isBookmarking = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BlockConfirmationDialog(
        title: 'Delete Short',
        message: 'Are you sure you want to delete this short? This action cannot be undone.',
        confirmText: 'Delete',
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final zapService = ref.read(zapServiceProvider(true));

    try {
      await zapService.deleteZap(widget.zapId, widget.currentUserId);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short deleted successfully')),
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

  Future<void> _handleBlockPost() async {
    if (_isBlocking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BlockConfirmationDialog(
        title: 'Block Short',
        message: 'Block this short? You won\'t see it in your feed.',
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBlocking = true);
    final blockService = ref.read(blockServiceProvider);

    try {
      await blockService.blockPost(
        blockerId: widget.currentUserId,
        postId: widget.zapId,
        isShort: true,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBlocking = false);
      }
    }
  }

  Future<void> _handleReport() async {
    if (_isReporting) return;

    setState(() => _isReporting = true);

    try {
      await showDialog(
        context: context,
        builder: (context) => ReportDialog(
          reportType: ReportType.post,
          postId: widget.zapId,
          reporterId: widget.currentUserId,
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
    final isOwner = widget.currentUserId == widget.zapUserId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            title: Text(widget.isBookmarked ? 'Remove bookmark' : 'Bookmark'),
            onTap: _isBookmarking ? null : _handleBookmark,
            trailing: _isBookmarking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
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
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Block short'),
            onTap: _isBlocking ? null : _handleBlockPost,
            trailing: _isBlocking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
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

