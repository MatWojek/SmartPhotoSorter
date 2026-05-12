import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalSortRun {
  final Process process;
  final Stream<Map<String, dynamic>> events;

  LocalSortRun({required this.process, required this.events});

  Future<void> stop() async {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
  }
}

class LocalSortService {
  static const String _pythonFromDefine = String.fromEnvironment(
    'LOCAL_SORT_PYTHON',
    defaultValue: '',
  );
  static const String _scriptFromDefine = String.fromEnvironment(
    'LOCAL_SORT_SCRIPT',
    defaultValue: '',
  );

  static String _defaultPython() {
    if (_pythonFromDefine.trim().isNotEmpty) return _pythonFromDefine.trim();
    if (Platform.isWindows) return 'python';
    return 'python3';
  }

  static String _defaultScriptPath() {
    if (_scriptFromDefine.trim().isNotEmpty) return _scriptFromDefine.trim();
    // In dev, Flutter runs with cwd=frontend_flutter.
    return '../backend/tools/local_sort_cli.py';
  }

  static Future<LocalSortRun> start({
    required Map<String, String> trainingFolders,
    required String unsortedFolder,
    required String outputBase,
    required String unknownFolder,
    required bool removeDuplicates,
    required bool sortPhotos,
    double matchThreshold = 0.35,
  }) async {
    final python = _defaultPython();
    final script = _defaultScriptPath();

    final args = <String>[
      script,
      '--training-json',
      jsonEncode(trainingFolders),
      '--unsorted-folder',
      unsortedFolder,
      '--output-base',
      outputBase,
      '--unknown-folder',
      unknownFolder,
      removeDuplicates ? '--remove-duplicates' : '--no-remove-duplicates',
      sortPhotos ? '--sort-photos' : '--no-sort-photos',
      '--match-threshold',
      matchThreshold.toString(),
    ];

    final proc = await Process.start(
      python,
      args,
      runInShell: true,
      workingDirectory: Directory.current.path,
    );

    final ctrl = StreamController<Map<String, dynamic>>(sync: true);

    void emit(Map<String, dynamic> ev) {
      if (!ctrl.isClosed) ctrl.add(ev);
    }

    // stdout: JSON events line-by-line
    proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          emit(Map<String, dynamic>.from(decoded));
        } else {
          emit({'status': 'log', 'message': trimmed});
        }
      } catch (_) {
        emit({'status': 'log', 'message': trimmed});
      }
    });

    // stderr: surface as log/error
    proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      emit({'status': 'stderr', 'message': trimmed});
    });

    // completion
    unawaited(proc.exitCode.then((code) {
      emit({'status': 'exit', 'exit_code': code});
      ctrl.close();
    }));

    return LocalSortRun(process: proc, events: ctrl.stream);
  }
}
