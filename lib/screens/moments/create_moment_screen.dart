import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/models/moment_model.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/moment_provider.dart';

class CreateMomentScreen extends ConsumerStatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  ConsumerState<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends ConsumerState<CreateMomentScreen> {
  final _textController = TextEditingController();
  MomentCategory _selectedCategory = MomentCategory.presence;
  MomentVisibility _selectedVisibility = MomentVisibility.circle;
  bool _isSubmitting = false;

  void _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (text.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moments must be under 60 characters.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      final moment = MomentModel(
        id: '', // Service generates ID
        userId: currentUser.uid,
        text: text,
        category: _selectedCategory,
        visibility: _selectedVisibility,
        createdAt: DateTime.now(),
        // Expires in 24 hours by default
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await ref.read(momentServiceProvider).createMoment(moment);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Moment shared.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share moment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Moment'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Share'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is currently happening?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'I am...',
                border: InputBorder.none,
                counterText: '',
              ),
              style: const TextStyle(fontSize: 24),
              onSubmitted: (_) => _submit(),
            ),
            const Spacer(),
            // Category Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    MomentCategory.values.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(category.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected)
                              setState(() => _selectedCategory = category);
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Privacy Selector
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                DropdownButton<MomentVisibility>(
                  value: _selectedVisibility,
                  underline: const SizedBox(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedVisibility = val);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: MomentVisibility.circle,
                      child: Text('Circle (Friends)'),
                    ),
                    DropdownMenuItem(
                      value: MomentVisibility.public,
                      child: Text('Public'),
                    ),
                    DropdownMenuItem(
                      value: MomentVisibility.private,
                      child: Text('Private (Only Me)'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
