import 'package:flutter/material.dart';
import 'package:z/models/report_model.dart';
import 'package:z/services/moderation/report_service.dart';

class ReportDialog extends StatefulWidget {
  final ReportType reportType;
  final String? postId;
  final String? userId;
  final String? storyId;
  final String reporterId;

  const ReportDialog({
    super.key,
    required this.reportType,
    this.postId,
    this.userId,
    this.storyId,
    required this.reporterId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportCategory? _selectedCategory;
  final _detailsController = TextEditingController();
  final _reportService = ReportService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _reportService.reportContent(
        reporterId: widget.reporterId,
        reportType: widget.reportType,
        postId: widget.postId,
        userId: widget.userId,
        storyId: widget.storyId,
        category: _selectedCategory!,
        additionalDetails: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getCategoryLabel(ReportCategory category) {
    switch (category) {
      case ReportCategory.spam:
        return 'Spam';
      case ReportCategory.harassment:
        return 'Harassment or Bullying';
      case ReportCategory.hateSpeech:
        return 'Hate Speech';
      case ReportCategory.inappropriateContent:
        return 'Inappropriate Content';
      case ReportCategory.misinformation:
        return 'False Information';
      case ReportCategory.violence:
        return 'Violence or Dangerous Behavior';
      case ReportCategory.selfHarm:
        return 'Self-Harm or Suicide';
      case ReportCategory.copyright:
        return 'Copyright Violation';
      case ReportCategory.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.reportType == ReportType.user
            ? 'Report User'
            : widget.reportType == ReportType.story
                ? 'Report Story'
                : 'Report Post',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you reporting this?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...ReportCategory.values.map((category) {
              return RadioListTile<ReportCategory>(
                title: Text(_getCategoryLabel(category)),
                value: category,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'Additional details (optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Provide more information...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

