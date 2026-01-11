import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/file_actions.dart';

class PhotoList extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> photos;
  final Future<void> Function(String photoId)? onDeleted;

  final Set<String> selected;
  final void Function(String photoId, bool selected)? onSelectChanged;

  const PhotoList({super.key, required this.userId, required this.photos, this.onDeleted, this.selected = const {}, this.onSelectChanged});
  @override
  State<PhotoList> createState() => _PhotoListState();
}

class _PhotoListState extends State<PhotoList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const Center(child: Text('No photos'));
    return Scrollbar(
      controller: _controller,
      child: ListView.separated(
        controller: _controller,
        itemCount: widget.photos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = widget.photos[i];
          final pid = p['photo_id'] as String;
          final filename = (p['filename'] as String?) ?? '(unknown)';
          final date = (p['date_taken'] as String?) ?? '';
          final path = (p['path'] as String?) ?? '';
          final url = ApiService.photoUrl(widget.userId, pid);
          final isSelected = widget.selected.contains(pid);
          return ListTile(
            minLeadingWidth: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (v) => widget.onSelectChanged?.call(pid, v ?? false),
                ),
                GestureDetector(
                  onLongPress: () => widget.onSelectChanged?.call(pid, true),
                  child: SizedBox(
                    width: 64, height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url, fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(filename),
            subtitle: Text([if (date.isNotEmpty) 'Date: $date', if (path.isNotEmpty) path].join(' • ')),
            trailing: widget.selected.isEmpty ? PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Open local file')),
                PopupMenuItem(value: 'reveal', child: Text('Reveal in folder')),
                PopupMenuItem(value: 'download', child: Text('Download')),
                PopupMenuItem(value: 'copy', child: Text('Copy path')),
                PopupMenuItem(value: 'delete', child: Text('Delete photo')),
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
                } else if (v == 'delete') {
                  final ok = await ApiService.deletePhoto(widget.userId, pid);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                    if (widget.onDeleted != null) await widget.onDeleted!(pid);
                  }
                }
              },
            ) : null,
          );
        },
      ),
    );
  }
}