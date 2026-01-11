import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class FilterBottomSheet extends StatefulWidget {
  final String userId;
  const FilterBottomSheet({super.key, required this.userId});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  List<String> persons = [];
  final Set<String> selected = {};
  // space for features when the backend displays them:
  final Map<String, dynamic> attributes = {};

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.listPersons(widget.userId);
      persons = [for (final p in list) (p['name'] as String?) ?? ''].where((e) => e.isNotEmpty).toList();
    } catch (e) {
      error = 'Failed to download list of people';
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        : error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text('Filter photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('People', style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final name in persons)
                          CheckboxListTile(
                            value: selected.contains(name),
                            title: Text(name),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selected.add(name);
                                } else {
                                  selected.remove(name);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Facial features'),
                    subtitle: const Text('Coming soon - requires backend support'),
                    trailing: const Icon(Icons.lock),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => selected.clear());
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop<Map<String, dynamic>>(context, {
                              'persons': selected.toList(),
                              'attributes': attributes,
                            });
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: content,
        ),
      ),
    );
  }
}