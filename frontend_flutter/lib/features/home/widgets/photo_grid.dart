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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
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
        itemCount: widget.photos.length,
        itemBuilder: (_, i) {
          final item = widget.photos[i];
          final pid = item['photo_id'] as String;
          final url = ApiService.photoUrl(widget.userId, pid);
          final path = item['path'] as String?;
          final isSelected = widget.selected.contains(pid);
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onLongPress: () => widget.onSelectChanged?.call(pid, true),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
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