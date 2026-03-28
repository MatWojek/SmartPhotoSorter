import 'package:flutter/material.dart';
import '../../../services/image_service.dart';
import '../../../services/person_service.dart';
import '../../../utils/file_actions.dart';

class PhotoList extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> photos;
  final Future<void> Function(String photoId)? onDeleted;

  final Set<String> selected;
  final void Function(String photoId, bool selected)? onSelectChanged;

  const PhotoList({
    super.key,
    required this.userId,
    required this.photos,
    this.onDeleted,
    this.selected = const {},
    this.onSelectChanged,
  });
  @override
  State<PhotoList> createState() => _PhotoListState();
}

class _PhotoListState extends State<PhotoList> {
  Future<void> _moveToCollection(String photoId) async {
    // Fetch persons
    final persons = await PersonService.listPersons(widget.userId);
    String? selectedPerson;
    final ctrl = TextEditingController();
    final choice = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move to collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (persons.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Existing person'),
                items: [
                  for (final p in persons)
                    DropdownMenuItem<String>(
                      value: p['name'] as String,
                      child: Text(p['name'] as String),
                    ),
                ],
                onChanged: (v) => selectedPerson = v,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Or new person name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              "selected": selectedPerson ?? '',
              "new": ctrl.text.trim(),
            }),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final newName = (choice['new'] ?? '').trim();
    final name =
        (choice['selected'] != null &&
            (choice['selected'] as String).isNotEmpty)
        ? choice['selected']!
        : newName;
    if (name.isEmpty) return;
    if (persons.whereType<Map<String, dynamic>>().every(
      (p) => p['name'] != name,
    )) {
      await PersonService.createPerson(widget.userId, name);
    }
    final ok = await ImageService.reassignPhoto(widget.userId, photoId, name);
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Moved to $name')));
      if (widget.onDeleted != null) await widget.onDeleted!(photoId);
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _uniqueByPhotoId(
    List<Map<String, dynamic>> items,
  ) {
    final Map<String, Map<String, dynamic>> idx = {};
    for (final e in items) {
      final k = e['photo_id'] as String?;
      if (k != null) idx[k] = e;
    }
    return idx.values.toList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _uniqueByPhotoId(widget.photos);
    if (photos.isEmpty) return const Center(child: Text('No photos'));
    return Scrollbar(
      child: ListView.separated(
        itemCount: photos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = photos[i];
          final pid = p['photo_id'] as String;
          final filename = (p['filename'] as String?) ?? '(unknown)';
          final date = (p['date_taken'] as String?) ?? '';
          final path = (p['path'] as String?) ?? '';
          final url = ImageService.photoUrl(widget.userId, pid);
          final isSelected = widget.selected.contains(pid);
          return ListTile(
            key: ValueKey(pid),
            minLeadingWidth: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (v) =>
                      widget.onSelectChanged?.call(pid, v ?? false),
                ),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (ctx, err, stack) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(filename),
            subtitle: Text(
              [
                if (date.isNotEmpty) 'Date: $date',
                if (path.isNotEmpty) path,
              ].join(' • '),
            ),
            trailing: widget.selected.isEmpty
                ? PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'open',
                        child: Text('Open local file'),
                      ),
                      PopupMenuItem(
                        value: 'reveal',
                        child: Text('Reveal in folder'),
                      ),
                      PopupMenuItem(value: 'download', child: Text('Download')),
                      PopupMenuItem(value: 'copy', child: Text('Copy path')),
                      PopupMenuItem(
                        value: 'move',
                        child: Text('Move to collection'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete photo'),
                      ),
                    ],
                    onSelected: (v) async {
                      if (v == 'open' && path.isNotEmpty) {
                        await openLocalFile(context, path);
                      } else if (v == 'reveal' && path.isNotEmpty) {
                        await revealInFolder(context, path);
                      } else if (v == 'download') {
                        await downloadPhotoUrl(context, Uri.parse(url));
                      } else if (v == 'copy' && path.isNotEmpty) {
                        await copyPath(context, path);
                      } else if (v == 'move') {
                        await _moveToCollection(pid);
                      } else if (v == 'delete') {
                        final ok = await ImageService.deletePhoto(
                          widget.userId,
                          pid,
                        );
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Deleted')),
                          );
                          if (widget.onDeleted != null)
                            await widget.onDeleted!(pid);
                        }
                      }
                    },
                  )
                : null,
          );
        },
      ),
    );
  }
}
