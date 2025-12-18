import 'package:flutter/material.dart';
import '../../models/person.dart';

class PersonDetailPage extends StatelessWidget {
  final Person person;

  const PersonDetailPage({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, 
          crossAxisSpacing: 12, 
          mainAxisSpacing: 12, 
        ), 
        itemCount: person.photos,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image),
          );
        },
      ),
    );
  }
}