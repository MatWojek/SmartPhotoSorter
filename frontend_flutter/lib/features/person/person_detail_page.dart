import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../services/api_service.dart';
import '../home/widgets/photo_grid.dart';
import '../home/widgets/photo_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonDetailPage extends StatefulWidget {
  final Person person;
  const PersonDetailPage({super.key, required this.person});
  @override State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  List<Map<String, dynamic>> photos = [];
  String? userId;
  bool listMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndPhotos();
  }

  Future<void> _loadUserIdAndPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('current_user_id');
    if (userId == null || userId!.isEmpty) return;
    final res = await ApiService.searchPhotosByPerson(userId!, widget.person.name);
    setState(() => photos = res);
  }

  @override
  Widget build(BuildContext context) {
    final canShow = userId != null && userId!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.name),
        actions: [
          IconButton(
            tooltip: 'Grid view',
            icon: const Icon(Icons.grid_view),
            onPressed: () => setState(() => listMode = false),
          ),
          IconButton(
            tooltip: 'List view',
            icon: const Icon(Icons.view_list),
            onPressed: () => setState(() => listMode = true),
          ),
        ],
      ),
      body: !canShow
          ? const Center(child: Text('Please log in to view photos'))
          : (listMode
              ? PhotoList(
                  userId: userId!,
                  photos: photos,
                  selected: const {},
                  onSelectChanged: (_, __) {},
                  onDeleted: (pid) async {
                    final ok = await ApiService.deletePhoto(userId!, pid);
                    if (ok) {
                      setState(() => photos.removeWhere((e) => e['photo_id'] == pid));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
                    }
                  },
                )
              : PhotoGrid(
                  userId: userId!,
                  photos: photos,
                  selected: const {},
                  onSelectChanged: (_, __) {},
                  onDeleted: (pid) async {
                    final ok = await ApiService.deletePhoto(userId!, pid);
                    if (ok) {
                      setState(() => photos.removeWhere((e) => e['photo_id'] == pid));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
                    }
                  },
                )),
    );
  }
}