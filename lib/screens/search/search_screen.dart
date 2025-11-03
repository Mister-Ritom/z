import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/user_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchUsersProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search users',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
      body:
          _searchQuery.isEmpty
              ? const Center(
                child: Text('Search for users, tweets, and hashtags'),
              )
              : searchResultsAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(child: Text('No results found'));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return UserCard(
                        user: user,
                        onTap: () {
                          // Navigate to profile
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
    );
  }
}
