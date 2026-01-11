import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';

class FolderDropZone extends StatefulWidget {
  final void Function(String path)? onFolderSelected;
  final String? selectedPath; 
  final VoidCallback? onClearSelected; 

  const FolderDropZone({
    super.key, 
    this.onFolderSelected,
    this.selectedPath,
    this.onClearSelected,
  });

  @override
  State<FolderDropZone> createState() => _FolderDropZoneState();
}

class _FolderDropZoneState extends State<FolderDropZone> {
  bool _dragging = false;
  String? _defaultFolder;

  @override
  void initState() {
    super.initState();
    // Try to auto-detect the default folder and select it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _defaultFolder = await _findDefaultFolder();
      if (_defaultFolder != null && (widget.selectedPath == null || widget.selectedPath!.isEmpty)) {
        // Automatically use the default folder, even if empty.
        widget.onFolderSelected?.call(_defaultFolder!);
      }
    });
  }

  Future<bool> _folderHasImages(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    final exts = <String>{'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp', '.tiff'};
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final name = entity.path.toLowerCase();
          if (exts.any((e) => name.endsWith(e))) return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> _validateAndSelect(BuildContext context, String path) async {
    final ok = await _folderHasImages(path);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The folder does not contain supported photos (jpg, png, bmp, webp, itp.).')),
      );
      return;
    }
    widget.onFolderSelected?.call(path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected folder: $path')),
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Choose',
      initialDirectory: _defaultFolder,
    );
    if (path == null) return;
    await _validateAndSelect(context, path);
  }

  void _handleDrop(DropDoneDetails details, BuildContext context) {
    final dir = details.files.map((x) => x.path).firstWhere(
      (p) => Directory(p).existsSync(),
      orElse: () => '',
    );
    if (dir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drop folder (not file)')),
      );
      return;
    }
    _validateAndSelect(context, dir);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (d) {
          setState(() => _dragging = false);
          _handleDrop(d, context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _dragging ? color : color, width: _dragging ? 3 : 2),
            color: _dragging ? color : Colors.transparent,
          ),
          child: InkWell(
            onTap: () => _pickDirectory(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.drive_folder_upload, size: 30, color: color),
                  const SizedBox(height: 8),
                  if (widget.selectedPath != null) ...[
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Chip(
                        avatar: const Icon(Icons.folder, size: 18),
                        label: Tooltip(
                          message: widget.selectedPath!,
                          child: Text(widget.selectedPath!, overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: widget.onClearSelected,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _findDefaultFolder() async {
    // Candidates relative to typical dev run locations
    final candidates = <String>[
      '${Directory.current.path}${Platform.pathSeparator}backend${Platform.pathSeparator}smartphotosorterdb',
      '${Directory.current.parent.path}${Platform.pathSeparator}backend${Platform.pathSeparator}smartphotosorterdb',
      'backend${Platform.pathSeparator}smartphotosorterdb',
      'smartphotosorterdb',
    ];
    for (final p in candidates) {
      final d = Directory(p);
      if (await d.exists()) return d.path;
    }
    // Fallback to user's Pictures if available
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final pics = Directory('$home${Platform.pathSeparator}Pictures');
      if (await pics.exists()) return pics.path;
    }
    return null;
  }
}