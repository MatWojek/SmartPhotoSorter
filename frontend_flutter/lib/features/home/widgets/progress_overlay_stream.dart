import 'dart:async';
import 'package:flutter/material.dart';

class ProgressOverlayStream extends StatefulWidget {
  final Stream<Map<String, dynamic>> events;
  final VoidCallback? onCancel;

  const ProgressOverlayStream({
    super.key,
    required this.events,
    this.onCancel,
  });

  @override
  State<ProgressOverlayStream> createState() => _ProgressOverlayStreamState();
}

class _ProgressOverlayStreamState extends State<ProgressOverlayStream> {
  StreamSubscription<Map<String, dynamic>>? _sub;

  Map<String, dynamic>? _lastEvent;
  bool _done = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sub = widget.events.listen((ev) {
      setState(() {
        _lastEvent = ev;
        _done = ev['status'] == 'done' || ev['status'] == 'cancelled';
        if (ev['status'] == 'error') {
          _errorMessage = (ev['message'] as String?) ?? 'Error';
        }
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lost connection to local progress stream.';
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = _lastEvent;
    final int current = (ev?['current'] ?? 0) is int
        ? (ev?['current'] ?? 0) as int
        : int.tryParse('${ev?['current'] ?? 0}') ?? 0;
    final int total = (ev?['total'] ?? 0) is int
        ? (ev?['total'] ?? 0) as int
        : int.tryParse('${ev?['total'] ?? 0}') ?? 0;
    final double? value = total > 0 ? current / total : null;

    final message = (ev?['message'] as String?) ?? 'Processing...';
    final photo = ev?['photo'] as String? ?? '';
    final dest = ev?['destination'] as String?;
    final status = ev?['status'] as String? ?? '';
    final person = ev?['person'] as String?;
    final confidence = ev?['match_confidence'];
    final summary = ev?['summary'] as Map<String, dynamic>?;
    final avgConf = summary?['avg_match_confidence'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _done ? 'Operation completed' : 'Operation progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: value),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.redAccent),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              if (photo.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dest != null ? '$photo → $dest' : photo,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text('Status: $status')),
                  const SizedBox(width: 8),
                  if (total > 0) Chip(label: Text('$current / $total')),
                  if (person != null && person.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Chip(label: Text('Person: $person')),
                  ],
                  if (confidence != null) ...[
                    const SizedBox(width: 8),
                    Chip(label: Text('Match: ${confidence.toString()}%')),
                  ],
                ],
              ),
              if (_done && avgConf != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Average match confidence: ${avgConf.toString()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (!_done) widget.onCancel?.call();
                    Navigator.of(context).maybePop();
                  },
                  child: Text(_done ? 'Close' : 'Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
