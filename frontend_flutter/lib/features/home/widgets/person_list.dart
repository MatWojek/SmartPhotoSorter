import 'package:flutter/material.dart';
import '../../../models/person.dart';

class PersonList extends StatelessWidget {
  final List<Person> persons;
  final void Function(String personName)? onDeleteFolder;
  const PersonList({super.key, required this.persons, this.onDeleteFolder});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: persons.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = persons[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(p.name),
          subtitle: Text('${p.photos} photos'),
          trailing: PopupMenuButton<String>(
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete_folder', child: Text('Delete folder'))],
            onSelected: (v) => v == 'delete_folder' ? onDeleteFolder?.call(p.name) : null,
          ),
          onTap: () {
          },
        );
      },
    );
  }
}