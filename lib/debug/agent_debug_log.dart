// #region agent log
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _kSessionId = 'bb1f91';
const String _kIngest =
    'http://127.0.0.1:7670/ingest/ba0ce984-ada1-4e2c-b358-ef441fcde417';
const String _kLogFileName = 'debug-bb1f91.log';

/// Debug-only NDJSON logging for Cursor session (no PII).
Future<void> agentDebugLog({
  required String location,
  required String message,
  String hypothesisId = 'A',
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) async {
  final payload = <String, dynamic>{
    'sessionId': _kSessionId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data ?? <String, dynamic>{},
    'runId': runId,
    'hypothesisId': hypothesisId,
  };
  final line = '${jsonEncode(payload)}\n';
  try {
    await http
        .post(
          Uri.parse(_kIngest),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': _kSessionId,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 2));
  } catch (_) {}
  try {
    final candidates = [
      File(_kLogFileName),
      File('${Directory.current.path}/$_kLogFileName'),
    ];
    for (final f in candidates) {
      try {
        await f.writeAsString(line, mode: FileMode.append, flush: true);
        break;
      } catch (_) {}
    }
  } catch (_) {}
}
// #endregion
