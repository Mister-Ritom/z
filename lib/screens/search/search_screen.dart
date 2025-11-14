import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import '../../providers/zap_provider.dart';
import '../../widgets/user_card.dart';
import '../../widgets/zap_card.dart'; // assume you have a ZapCard widget

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
    final searchUsersAsync = ref.watch(searchUsersProvider(_searchQuery));
    final searchZapsAsync = ref.watch(searchZapsProvider(_searchQuery));

    final isEmptyQuery = _searchQuery.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search users or zaps',
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
          isEmptyQuery
              ? const Center(child: Text('Search for users, zaps, or hashtags'))
              : _buildCombinedResults(searchUsersAsync, searchZapsAsync),
    );
  }

  Widget _buildCombinedResults(
    AsyncValue<List<dynamic>> usersAsync,
    AsyncValue<List<dynamic>> zapsAsync,
  ) {
    // Combine both async values manually
    if (usersAsync.isLoading || zapsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (usersAsync.hasError || zapsAsync.hasError) {
      log(
        "Search Error",
        error: usersAsync.error ?? zapsAsync.error,
        stackTrace: usersAsync.stackTrace ?? zapsAsync.stackTrace,
      );
      return Center(
        child: Text('Error: ${usersAsync.error ?? zapsAsync.error}'),
      );
    }

    final users = usersAsync.value ?? [];
    final zaps = zapsAsync.value ?? [];

    if (users.isEmpty && zaps.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView(
      children: [
        if (users.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Users',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ...users.map((user) => UserCard(user: user)),
          const Divider(height: 32),
        ],
        if (zaps.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Zaps',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ...zaps.map((zap) {
            return ZapCard(zap: zap);
          }),
        ],
      ],
    );
  }
}
