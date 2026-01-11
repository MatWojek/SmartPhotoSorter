import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/file_actions.dart';

class PhotoGrid extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> photos;
  final Future<void> Function(String photoId)? onDeleted;

  final Set<String> selected;
  final void Function(String photoId, bool selected)? onSelectChanged;

  const PhotoGrid({super.key, required this.userId, required this.photos, this.onDeleted, this.selected = const {}, this.onSelectChanged});
  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  final ScrollController _controller = ScrollController();
  Future<void> _moveToCollection(String photoId) async {
    final persons = await ApiService.listPersons(widget.userId);
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
                    DropdownMenuItem<String>(value: p['name'] as String, child: Text(p['name'] as String)),
                ],
                onChanged: (v) => selectedPerson = v,
              ),
            const SizedBox(height: 8),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Or new person name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, {"selected": selectedPerson ?? '', "new": ctrl.text.trim()}), child: const Text('Move')),
        ],
      ),
    );
    if (choice == null) return;
    final newName = (choice['new'] ?? '').trim();
    final name = (choice['selected'] != null && (choice['selected'] as String).isNotEmpty) ? choice['selected']! : newName;
    if (name == null || name.isEmpty) return;
    if (persons.whereType<Map<String, dynamic>>().every((p) => p['name'] != name)) {
      await ApiService.createPerson(widget.userId, name);
    }
    final ok = await ApiService.reassignPhoto(widget.userId, photoId, name);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved to $name')));
      if (widget.onDeleted != null) await widget.onDeleted!(photoId);
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _uniqueByPhotoId(List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> idx = {};
    for (final e in items) {
      final k = e['photo_id'] as String?;
      if (k != null) idx[k] = e;
    }
    return idx.values.toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _uniqueByPhotoId(widget.photos);
    if (photos.isEmpty) {
      return const Center(child: Text('No photos for the selected criteria'));
    }
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: GridView.builder(
        controller: _controller,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: photos.length,
        itemBuilder: (_, i) {
          final item = photos[i];
          final pid = item['photo_id'] as String;
          final url = ApiService.photoUrl(widget.userId, pid);
          final path = item['path'] as String?;
          final isSelected = widget.selected.contains(pid);
          return Stack(
            key: ValueKey(pid),
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                left: 8, top: 8,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (v) => widget.onSelectChanged?.call(pid, v ?? false),
                ),
              ),
              if (widget.selected.isEmpty)
                Positioned(
                  right: 8, top: 8,
                  child: PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('Open local file')),
                      PopupMenuItem(value: 'reveal', child: Text('Reveal in folder')),
                      PopupMenuItem(value: 'download', child: Text('Download')),
                      PopupMenuItem(value: 'copy', child: Text('Copy path')),
                      PopupMenuItem(value: 'move', child: Text('Move to collection')),
                      PopupMenuItem(value: 'delete', child: Text('Delete photo')),
                    ],
                    onSelected: (v) async {
                      if (v == 'open' && path != null && path.isNotEmpty) {
                        await openLocalFile(context, path);
                      } else if (v == 'reveal' && path != null && path.isNotEmpty) {
                        await revealInFolder(context, path);
                      } else if (v == 'download') {
                        await downloadPhotoUrl(context, Uri.parse(url));
                      } else if (v == 'copy' && path != null) {
                        await copyPath(context, path);
                      } else if (v == 'move') {
                        await _moveToCollection(pid);
                      } else if (v == 'delete') {
                        final ok = await ApiService.deletePhoto(widget.userId, pid);
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                          if (widget.onDeleted != null) await widget.onDeleted!(pid);
                        }
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}