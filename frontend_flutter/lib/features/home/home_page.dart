import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/person.dart';
import 'widgets/folder_drop_zone.dart';
import 'widgets/person_grid.dart';
import '../navigation/app_top_bar.dart';
import 'widgets/sort_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../services/person_service.dart';
import 'widgets/photo_grid.dart';
import 'widgets/photo_list.dart';
import 'widgets/person_list.dart';
import '../../utils/file_actions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool listMode = false;
  bool loggedIn = false;
  String? selectedFolder;
  String? currentUserId;
  DateTime? lastSortDate;

  final Set<String> selectedPhotos = {};
  bool selectionMode = false;

  List<Person> persons = [];
  List<Map<String, dynamic>> photoResults = [];
  List<String> activeFilterPersons = [];

  Future<void> _fetchPersons() async {
    if (currentUserId == null || currentUserId!.isEmpty) return;
    final list = await PersonService.listPersons(currentUserId!);
    setState(() {
      persons = [
        for (final p in list) Person.fromMap(p as Map<String, dynamic>),
      ];
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserId(); // do not fetch persons until logged in
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentUserId = prefs.getString('current_user_id'));
  }

  Future<void> _saveUserId(String? id) async {
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', id);
  }

  Future<void> _loadLastSortDate() async {
    if (selectedFolder == null || selectedFolder!.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('last_sort_date_${selectedFolder!}');
    if (s != null && s.isNotEmpty) {
      setState(() => lastSortDate = DateTime.tryParse(s));
    }
  }

  Future<void> _searchByPerson(String name) async {
    if (currentUserId == null || currentUserId!.isEmpty) return;
    final res = await ImageService.searchPhotosByPerson(currentUserId!, name);
    // Deduplicate by path if available, else by photo_id
    final Map<String, Map<String, dynamic>> unique = {};
    for (final p in res) {
      final String? path = p['path'] as String?;
      final String id = (p['photo_id'] as String?) ?? '';
      final key = (path != null && path.isNotEmpty) ? 'path:$path' : 'id:$id';
      unique[key] = p;
    }
    setState(() {
      activeFilterPersons = [name];
      photoResults = unique.values.toList();
    });
  }

  Future<void> _applyFilters({
    required List<String> persons,
    Map<String, dynamic>? attributes,
  }) async {
    if (currentUserId == null || currentUserId!.isEmpty) return;
    if (persons.isEmpty) {
      setState(() {
        activeFilterPersons = [];
        photoResults = [];
      });
      return;
    }
    final Map<String, Map<String, dynamic>> unique = {};
    for (final name in persons) {
      final res = await ImageService.searchPhotosByPerson(currentUserId!, name);
      for (final p in res) {
        final String? path = p['path'] as String?;
        final String id = (p['photo_id'] as String?) ?? '';
        final key = (path != null && path.isNotEmpty) ? 'path:$path' : 'id:$id';
        unique[key] = p;
      }
    }
    setState(() {
      activeFilterPersons = persons;
      photoResults = unique.values.toList();
    });
  }

  void _toggleSelect(String pid, bool selected) {
    setState(() {
      if (selected)
        selectedPhotos.add(pid);
      else
        selectedPhotos.remove(pid);
      selectionMode = selectedPhotos.isNotEmpty;
    });
  }

  Future<void> _deleteSelected() async {
    if (currentUserId == null) return;
    final ids = selectedPhotos.toList();
    if (ids.isEmpty) return;
    await ImageService.deleteBatch(currentUserId!, ids);
    setState(() {
      photoResults.removeWhere((e) => selectedPhotos.contains(e['photo_id']));
      selectedPhotos.clear();
      selectionMode = false;
    });
  }

  Future<void> _downloadSelected() async {
    // simple: open each photo URL externally
    for (final id in selectedPhotos) {
      final url = ImageService.photoUrl(currentUserId!, id);
      await downloadPhotoUrl(context, Uri.parse(url));
    }
  }

  Future<void> _revealSelected() async {
    // reveal selected items in file manager
    for (final id in selectedPhotos) {
      final item = photoResults.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['photo_id'] == id,
        orElse: () => const {},
      );
      final path = (item['path'] as String?) ?? '';
      if (path.isNotEmpty) {
        await revealInFolder(context, path);
      }
    }
  }

  Future<void> _copySelectedPaths() async {
    // copy paths to clipboard for selected items
    for (final id in selectedPhotos) {
      final item = photoResults.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['photo_id'] == id,
        orElse: () => const {},
      );
      final path = (item['path'] as String?) ?? '';
      if (path.isNotEmpty) {
        await copyPath(context, path);
      }
    }
  }

  Future<void> _moveSelectedLocal(String personName) async {
    if (selectedFolder == null || selectedFolder!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a base folder first.')),
      );
      return;
    }
    final baseDir = Directory(selectedFolder!);
    final outputBase = Directory(
      '${baseDir.path}${Platform.pathSeparator}sorted',
    );
    final destDir = Directory(
      '${outputBase.path}${Platform.pathSeparator}$personName',
    );
    if (!outputBase.existsSync()) outputBase.createSync(recursive: true);
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    // also copy to manual train dir for future learning
    Directory manualTrainBase() {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      final userPart = (currentUserId != null && currentUserId!.isNotEmpty)
          ? currentUserId!
          : 'local';
      final dir = Directory(
        '$home${Platform.pathSeparator}.smartphotosorter${Platform.pathSeparator}train_manual${Platform.pathSeparator}$userPart${Platform.pathSeparator}$personName',
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }

    final manualDir = manualTrainBase();

    for (final id in selectedPhotos.toList()) {
      final item = photoResults.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['photo_id'] == id,
        orElse: () => const {},
      );
      final path = (item['path'] as String?) ?? '';
      if (path.isEmpty) continue;
      final srcFile = File(path);
      if (!srcFile.existsSync()) continue;
      final fileName = path.split(RegExp(r'[\\/]')).last;
      final destPath = '${destDir.path}${Platform.pathSeparator}$fileName';
      try {
        await srcFile.rename(destPath);
      } catch (_) {
        try {
          await srcFile.copy(destPath);
          await srcFile.delete();
        } catch (_) {}
      }
      // copy to manual train dir (keep a copy)
      try {
        final trainCopy = File(
          '${manualDir.path}${Platform.pathSeparator}$fileName',
        );
        if (!trainCopy.existsSync()) {
          await File(destPath).copy(trainCopy.path);
        }
      } catch (_) {}
      // update UI state: remove moved photo
      setState(() {
        photoResults.removeWhere((e) => e['photo_id'] == id);
        selectedPhotos.remove(id);
      });
    }
    setState(() {
      selectionMode = selectedPhotos.isNotEmpty;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Moved to $personName')));
  }

  Future<void> _reassignSelected(String personName) async {
    if (currentUserId == null) return;
    for (final id in selectedPhotos) {
      await ImageService.reassignPhoto(currentUserId!, id, personName);
    }
    await _applyFilters(persons: activeFilterPersons);
    setState(() {
      selectedPhotos.clear();
      selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notLogged =
        !loggedIn || currentUserId == null || currentUserId!.isEmpty;

    if (notLogged) {
      // Logged out: allow local sorting only, with a larger drop zone
      return Scaffold(
        appBar: AppTopBar(
          loggedIn: loggedIn,
          onAuthChanged: (isLoggedIn, {userId, token}) async {
            setState(() {
              loggedIn = isLoggedIn;
              if (userId != null && userId.isNotEmpty) currentUserId = userId;
            });
            if (isLoggedIn) {
              await _saveUserId(userId);
            } else {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('current_user_id');
              currentUserId = null;
            }
            if (isLoggedIn) {
              await _fetchPersons(); // only after login
            } else {
              setState(() {
                persons = [];
                photoResults = [];
                activeFilterPersons = [];
                selectedFolder = null;
              });
            }
          },
          userId: currentUserId,
          // search/filter remain inactive when logged out (AppTopBar already guards)
          onSearchPerson: _searchByPerson,
          onFiltersApplied: ({required persons, attributes}) =>
              _applyFilters(persons: persons, attributes: attributes),
        ),
        body: Column(
          children: [
            // Make the drop zone take most of the screen
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FolderDropZone(
                  selectedPath: selectedFolder,
                  onClearSelected: () => setState(() => selectedFolder = null),
                  onFolderSelected: (path) {
                    setState(() => selectedFolder = path);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Start: $path')));
                  },
                ),
              ),
            ),
            // Local-only actions (delete duplicates / sort images)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SortOptionsPanel(
                selectedFolder: selectedFolder,
                currentUserId: null,
                forceLocalOnly: true,
                onAfterTask: () async {
                  // no persons or backend refresh while logged out
                },
              ),
            ),
          ],
        ),
      );
    }

    // Logged in: full UI as before
    final showPhotos =
        photoResults.isNotEmpty &&
        (currentUserId != null && currentUserId!.isNotEmpty);

    return Scaffold(
      appBar: AppTopBar(
        loggedIn: loggedIn,
        onAuthChanged: (isLoggedIn, {userId, token}) async {
          setState(() {
            loggedIn = isLoggedIn;
            if (userId != null && userId.isNotEmpty) currentUserId = userId;
          });
          if (isLoggedIn) {
            await _saveUserId(userId);
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('current_user_id');
            currentUserId = null;
            // clear token on logout
            AuthService.setToken(null);
          }
          if (isLoggedIn) {
            await _fetchPersons();
          } else {
            setState(() {
              persons = [];
              photoResults = [];
              activeFilterPersons = [];
              selectedFolder = null;
            });
          }
        },
        userId: currentUserId,
        onSearchPerson: _searchByPerson,
        onFiltersApplied: ({required persons, attributes}) =>
            _applyFilters(persons: persons, attributes: attributes),
      ),
      body: Column(
        children: [
          FolderDropZone(
            selectedPath: selectedFolder,
            onClearSelected: () => setState(() => selectedFolder = null),
            onFolderSelected: (path) {
              setState(() => selectedFolder = path);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Start: $path')));
            },
          ),
          if (selectedFolder != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected folder: $selectedFolder',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (lastSortDate != null)
                      Text(
                        'Sorted at: ${lastSortDate!.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          SortOptionsPanel(
            selectedFolder: selectedFolder,
            currentUserId: currentUserId,
            onAfterTask: () async {
              await _fetchPersons();
              if (activeFilterPersons.isNotEmpty) {
                await _applyFilters(persons: activeFilterPersons);
              }
            },
          ),
          const SizedBox(height: 8),
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('${selectedPhotos.length} selected'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _downloadSelected,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _revealSelected,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Reveal'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _copySelectedPaths,
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy paths'),
                  ),
                  const SizedBox(width: 8),
                  // Local move to person folder
                  PopupMenuButton<String>(
                    tooltip: 'Move to person (local)',
                    itemBuilder: (_) {
                      // offer persons list if available, else allow manual input
                      final items = persons
                          .map(
                            (p) => PopupMenuItem(
                              value: p.name,
                              child: Text(p.name),
                            ),
                          )
                          .toList();
                      items.add(
                        const PopupMenuItem(
                          value: '__manual__',
                          child: Text('Other…'),
                        ),
                      );
                      return items;
                    },
                    onSelected: (name) async {
                      if (name == '__manual__') {
                        final ctrl = TextEditingController();
                        final v = await showDialog<String>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Person name'),
                            content: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, ctrl.text.trim()),
                                child: const Text('Move'),
                              ),
                            ],
                          ),
                        );
                        if (v != null && v.isNotEmpty)
                          await _moveSelectedLocal(v);
                      } else {
                        await _moveSelectedLocal(name);
                      }
                    },
                    child: TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.drive_file_move),
                      label: const Text('Move'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Reassign to person',
                    itemBuilder: (_) => persons
                        .map(
                          (p) =>
                              PopupMenuItem(value: p.name, child: Text(p.name)),
                        )
                        .toList(),
                    onSelected: (name) => _reassignSelected(name),
                    child: TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Reassign'),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Grid view',
                icon: const Icon(Icons.grid_view),
                onPressed: () async {
                  setState(() => listMode = false);
                  await _loadLastSortDate();
                },
              ),
              IconButton(
                tooltip: 'List view',
                icon: const Icon(Icons.view_list),
                onPressed: () async {
                  setState(() => listMode = true);
                  await _loadLastSortDate();
                },
              ),
            ],
          ),
          Expanded(
            child: showPhotos
                ? (listMode
                      ? PhotoList(
                          userId: currentUserId!,
                          photos: photoResults,
                          selected: selectedPhotos,
                          onSelectChanged: _toggleSelect,
                          onDeleted: (pid) async => setState(
                            () => photoResults.removeWhere(
                              (e) => e['photo_id'] == pid,
                            ),
                          ),
                        )
                      : PhotoGrid(
                          userId: currentUserId!,
                          photos: photoResults,
                          selected: selectedPhotos,
                          onSelectChanged: _toggleSelect,
                          onDeleted: (pid) async => setState(
                            () => photoResults.removeWhere(
                              (e) => e['photo_id'] == pid,
                            ),
                          ),
                        ))
                : (listMode
                      ? PersonList(
                          persons: persons,
                          onDeleteFolder: (name) async {
                            if (currentUserId != null &&
                                currentUserId!.isNotEmpty) {
                              final ok = await PersonService.deletePersonFolder(
                                currentUserId!,
                                name,
                              );
                              if (ok) await _fetchPersons();
                            }
                          },
                        )
                      : PersonGrid(
                          persons: persons,
                          onDeleteFolder: (name) async {
                            if (currentUserId != null &&
                                currentUserId!.isNotEmpty) {
                              final ok = await PersonService.deletePersonFolder(
                                currentUserId!,
                                name,
                              );
                              if (ok) await _fetchPersons();
                            }
                          },
                        )),
          ),
        ],
      ),
    );
  }
}
