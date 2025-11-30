import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/report_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/bookmarking_provider.dart';
import 'package:z/providers/moderation_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/widgets/moderation/block_confirmation_dialog.dart';
import 'package:z/widgets/moderation/report_dialog.dart';

class ZapOptionsSheet extends ConsumerStatefulWidget {
  final ZapModel zap;
  final String currentUserId;
  final bool isBookmarked;
  final VoidCallback? onDeleted;

  const ZapOptionsSheet({
    super.key,
    required this.zap,
    required this.currentUserId,
    required this.isBookmarked,
    this.onDeleted,
  });

  @override
  ConsumerState<ZapOptionsSheet> createState() => _ZapOptionsSheetState();
}

class _ZapOptionsSheetState extends ConsumerState<ZapOptionsSheet> {
  bool _isBookmarking = false;
  bool _isDeleting = false;
  bool _isBlocking = false;
  bool _isReporting = false;

  Future<void> _handleBookmark() async {
    if (_isBookmarking) return;

    setState(() => _isBookmarking = true);
    final zapService = ref.read(zapServiceProvider(false));
    ref.read(bookmarkingProvider(widget.zap.id).notifier).state = true;

    try {
      if (widget.isBookmarked) {
        await zapService.removeBookmark(widget.zap.id, widget.currentUserId);
      } else {
        await zapService.bookmarkZap(widget.zap.id, widget.currentUserId);
      }
      ref.invalidate(
        isBookmarkedProvider((
          zapId: widget.zap.id,
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
      ref.read(bookmarkingProvider(widget.zap.id).notifier).state = false;
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
        title: 'Delete Zap',
        message: 'Are you sure you want to delete this zap? This action cannot be undone.',
        confirmText: 'Delete',
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final zapService = ref.read(zapServiceProvider(false));

    try {
      await zapService.deleteZap(widget.zap.id, widget.currentUserId);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zap deleted successfully')),
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
        title: 'Block Zap',
        message: 'Block this zap? You won\'t see it in your feed.',
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBlocking = true);
    final blockService = ref.read(blockServiceProvider);

    try {
      await blockService.blockPost(
        blockerId: widget.currentUserId,
        postId: widget.zap.id,
        isShort: false,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zap blocked')),
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
          postId: widget.zap.id,
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
    final isOwner = widget.currentUserId == widget.zap.userId ||
        widget.currentUserId == widget.zap.originalUserId;

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
            title: const Text('Block zap'),
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

