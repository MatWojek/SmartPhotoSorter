import 'package:flutter/material.dart';
import '../../models/person.dart';
import 'widgets/folder_drop_zone.dart';
import 'widgets/person_grid.dart';
import '../navigation/app_top_bar.dart';
import '../auth/auth_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loggedIn = false;

  final List<Person> persons = [
    Person(name: 'Anna', photos: 124),
    Person(name: 'Mateusz', photos: 86),
    Person(name: 'Unknown #1', photos: 57),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        loggedIn: loggedIn,
        onLoginToggle: () => setState(() {
          loggedIn = !loggedIn;
        }),
      ),
      body: Column(
        children: [
          AuthPanel(loggedIn: loggedIn),
          const SizedBox(height: 8),
          const FolderDropZone(),
          const Divider(height: 32),
          Expanded(child: PersonGrid(persons: persons)),
        ],
      ),
    );
  }
}