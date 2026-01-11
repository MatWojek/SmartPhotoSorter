import 'package:flutter/material.dart';
import '../../../models/person.dart';
import '../../person/person_detail_page.dart';

class PersonGrid extends StatelessWidget {
  final List<Person> persons;
  final void Function(String personName)? onDeleteFolder;

  const PersonGrid({
    super.key,
    required this.persons,
    this.onDeleteFolder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: persons.length,
      itemBuilder: (context, index) {
        final person = persons[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonDetailPage(person: person),
              ),
            );
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                Positioned(
                  right: 8,
                  top: 8,
                  child: PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete_folder',
                        child: Text('Delete folder'),
                      ),
                    ],
                    onSelected: (v) async {
                      if (v == 'delete_folder' && onDeleteFolder != null) {
                        onDeleteFolder!(person.name);
                      }
                    },
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
                      const SizedBox(height: 12),
                      Text(
                        person.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${person.photos} photos'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}