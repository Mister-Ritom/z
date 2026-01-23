import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/moment_provider.dart';
import 'package:z/screens/moments/create_moment_screen.dart';
import 'package:z/widgets/moments/moment_card.dart';

class MomentsRail extends ConsumerWidget {
  const MomentsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(momentsRailProvider);

    return SizedBox(
      height: 140, // explicit height for ListView
      child: momentsAsync.when(
        data: (moments) {
          // Always show "Add Moment" button as first item
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: moments.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AddMomentButton();
              }
              return MomentCard(moment: moments[index - 1]);
            },
          );
        },
        loading:
            () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        error: (err, stack) => const SizedBox.shrink(), // Collapse on error
      ),
    );
  }
}

class _AddMomentButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateMomentScreen(),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'New\nMoment',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
