import 'package:flutter/material.dart';
import '../../services/person_service.dart';

class PersonSearchDelegate extends SearchDelegate<String> {
  final String userId;
  PersonSearchDelegate({required this.userId});

  List<String> _all = [];
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    final list = await PersonService.listPersons(userId);
    _all = [
      for (final p in list) (p['name'] as String?) ?? '',
    ].where((e) => e.isNotEmpty).toList();
    _loaded = true;
  }

  @override
  String get searchFieldLabel => 'Search by person';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return const Center(child: Text("Enter the person's name"));
    }
    close(context, q);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<void>(
      future: _load(),
      builder: (context, snap) {
        final q = query.toLowerCase();
        final suggestions = _all
            .where((n) => n.toLowerCase().contains(q))
            .take(10)
            .toList();
        if (suggestions.isEmpty) {
          return const Center(child: Text('No hints'));
        }
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (_, i) {
            final name = suggestions[i];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(name),
              onTap: () => close(context, name),
            );
          },
        );
      },
    );
  }
}
