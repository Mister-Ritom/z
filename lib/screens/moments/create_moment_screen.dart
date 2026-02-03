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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Moment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.secondary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Share'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share what\'s up',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _textController,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'I am thinking about...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                counterText: '',
              ),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
              onSubmitted: (_) => _submit(),
            ),
            const Spacer(),
            // Category Selector
            Text(
              'Category',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children:
                    MomentCategory.values.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: FilterChip(
                          label: Text(category.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                          showCheckmark: false,
                          selectedColor: colorScheme.secondary,
                          labelStyle: TextStyle(
                            color:
                                isSelected
                                    ? Colors.white
                                    : colorScheme.onSurface,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? Colors.transparent
                                      : colorScheme.outline,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            // Privacy Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<MomentVisibility>(
                    value: _selectedVisibility,
                    underline: const SizedBox(),
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    icon: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedVisibility = val);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: MomentVisibility.circle,
                        child: Text('Friends Only'),
                      ),
                      DropdownMenuItem(
                        value: MomentVisibility.public,
                        child: Text('Public'),
                      ),
                      DropdownMenuItem(
                        value: MomentVisibility.private,
                        child: Text('Private'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
