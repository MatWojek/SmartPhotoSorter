import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

class ProgressOverlay extends StatefulWidget {
  final String wsUrl;
  final Uri sseUri;

  const ProgressOverlay({super.key, required this.wsUrl, required this.sseUri});

  @override
  State<ProgressOverlay> createState() => _ProgressOverlayState();
}

class _ProgressOverlayState extends State<ProgressOverlay> {
  IOWebSocketChannel? _channel;
  http.Client? _httpClient;
  StreamSubscription<String>? _sseSub;

  Map<String, dynamic>? _lastEvent;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startWsOrSse(widget.wsUrl, widget.sseUri);
  }

  void _startWsOrSse(String wsUrl, Uri sseUri) {
    try {
      _channel = IOWebSocketChannel.connect(wsUrl);
      _channel!.stream.listen(
        (data) => _onEvent(data as String),
        onError: (_) async {
          await _startSse(sseUri);
        },
        cancelOnError: true,
      );
    } catch (_) {
      _startSse(sseUri);
    }
  }

  Future<void> _startSse(Uri sseUri) async {
    _httpClient = http.Client();
    final req = http.Request('GET', sseUri);
    final resp = await _httpClient!.send(req);
    _sseSub = resp.stream
        .transform(const Utf8Decoder())
        .transform(const LineSplitter())
        .listen((line) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        _onEvent(jsonStr);
      }
    }, onError: (_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _onEvent(String data) {
    final ev = jsonDecode(data) as Map<String, dynamic>;
    setState(() {
      _lastEvent = ev;
      _done = (ev['status'] == 'done');
    });
    if (_done) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _sseSub?.cancel();
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = _lastEvent;
    final int current = (ev?['current'] ?? 0) as int;
    final int total = (ev?['total'] ?? 0) as int;
    final double? value = total > 0 ? current / total : null;
    final message = ev?['message'] as String? ?? 'Processing...';
    final photo = ev?['photo'] as String? ?? '';
    final dest = ev?['destination'] as String?;
    final status = ev?['status'] as String? ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Operation progress', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: value),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 4),
              if (photo.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dest != null ? '$photo → $dest' : photo,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text('Status: $status')),
                  const SizedBox(width: 8),
                  if (total > 0) Chip(label: Text('$current / $total')),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}