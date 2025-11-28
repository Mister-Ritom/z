import 'package:flutter/material.dart';
import 'package:z/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send feedback.')),
      );
      return;
    }

    setState(() => _loading = true);

    String version = '';
    String build = '';

    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {}

    try {
      if (!mounted) return;
      String platform = Theme.of(context).platform.name;
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'userId': user.uid,
        'email': user.email,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': '$version+$build',
        'platform': platform,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
      _controller.clear();
      AppLogger.info(
        'FeedbackScreen',
        'Feedback submitted successfully',
        data: {'userId': user.uid},
      );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      AppLogger.error(
        'FeedbackScreen',
        'Error submitting feedback',
        error: e,
        stackTrace: st,
        data: {'userId': user.uid},
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Tell us what you think'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Share your feedback...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submitFeedback,
              child:
                  _loading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
