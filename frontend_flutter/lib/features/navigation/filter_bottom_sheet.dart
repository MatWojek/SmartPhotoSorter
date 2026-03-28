import 'package:flutter/material.dart';
import '../../services/person_service.dart';

class FilterBottomSheet extends StatefulWidget {
  final String userId;
  const FilterBottomSheet({super.key, required this.userId});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  List<Map<String, dynamic>> persons = [];
  final Set<String> selectedPersons = {};
  // attribute-based filters
  final Set<String> selectedEyeColors = {};
  final Set<String> selectedHairColors = {};
  // available attribute values based on loaded persons
  final Set<String> _availableEyeColors = {};
  final Set<String> _availableHairColors = {};
  // attributes map returned to the caller
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
      final list = await PersonService.listPersons(widget.userId);
      if (!mounted) return;
      setState(() {
        persons = [for (final p in list) (p as Map<String, dynamic>)];
        _availableEyeColors
          ..clear()
          ..addAll(
            persons
                .map((p) => (p['eye_color'] as String?)?.toLowerCase() ?? '')
                .where((v) => v.isNotEmpty),
          );
        _availableHairColors
          ..clear()
          ..addAll(
            persons
                .map((p) => (p['hair_color'] as String?)?.toLowerCase() ?? '')
                .where((v) => v.isNotEmpty),
          );

        // keep selections only for values that are actually present
        selectedEyeColors.removeWhere((c) => !_availableEyeColors.contains(c));
        selectedHairColors.removeWhere(
          (c) => !_availableHairColors.contains(c),
        );
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Failed to download list of people';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // only expose eye/hair filters when we actually have such data
    final List<String> eyeOptions = [
      'blue',
      'brown',
      'green',
    ].where((c) => _availableEyeColors.contains(c)).toList();
    final List<String> hairOptions = [
      'blond',
      'brown',
      'black',
    ].where((c) => _availableHairColors.contains(c)).toList();

    final content = loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!),
            ),
          )
        : Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Filter photos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'People',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      for (final p in persons)
                        CheckboxListTile(
                          value: selectedPersons.contains(p['name'] as String?),
                          title: Text((p['name'] as String?) ?? ''),
                          onChanged: (v) {
                            final name = (p['name'] as String?) ?? '';
                            if (name.isEmpty) return;
                            setState(() {
                              if (v == true) {
                                selectedPersons.add(name);
                              } else {
                                selectedPersons.remove(name);
                              }
                            });
                          },
                        ),
                      const Divider(),
                      if (eyeOptions.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Eye color',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        for (final c in eyeOptions)
                          CheckboxListTile(
                            value: selectedEyeColors.contains(c),
                            title: Text(
                              '${c[0].toUpperCase()}${c.substring(1)} eyes',
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selectedEyeColors.add(c);
                                } else {
                                  selectedEyeColors.remove(c);
                                }
                              });
                            },
                          ),
                      ],
                      if (hairOptions.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Hair color',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        for (final c in hairOptions)
                          CheckboxListTile(
                            value: selectedHairColors.contains(c),
                            title: Text(
                              '${c[0].toUpperCase()}${c.substring(1)} hair',
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selectedHairColors.add(c);
                                } else {
                                  selectedHairColors.remove(c);
                                }
                              });
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedPersons.clear();
                          selectedEyeColors.clear();
                          selectedHairColors.clear();
                        });
                      },
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Build effective persons list: if none explicitly selected,
                        // derive it from eye/hair color filters.
                        final Set<String> effectivePersons = {
                          ...selectedPersons,
                        };
                        if (effectivePersons.isEmpty &&
                            (selectedEyeColors.isNotEmpty ||
                                selectedHairColors.isNotEmpty)) {
                          for (final p in persons) {
                            final name = (p['name'] as String?) ?? '';
                            if (name.isEmpty) continue;
                            final eye =
                                (p['eye_color'] as String?)?.toLowerCase() ??
                                '';
                            final hair =
                                (p['hair_color'] as String?)?.toLowerCase() ??
                                '';
                            final matchesEye =
                                selectedEyeColors.isEmpty ||
                                selectedEyeColors.contains(eye);
                            final matchesHair =
                                selectedHairColors.isEmpty ||
                                selectedHairColors.contains(hair);
                            if (matchesEye && matchesHair) {
                              effectivePersons.add(name);
                            }
                          }
                        }
                        attributes['eye_colors'] = selectedEyeColors.toList();
                        attributes['hair_colors'] = selectedHairColors.toList();
                        Navigator.pop<Map<String, dynamic>>(context, {
                          'persons': effectivePersons.toList(),
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: content,
        ),
      ),
    );
  }
}
