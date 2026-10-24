// test/support/fake_bridge_server.dart
// A minimal fake A-Coder bridge for tests: pure Dart, dart:io HttpServer +
// WebSocketTransformer, implementing the protocol slice the app needs.
//
// Usage:
//   final server = FakeBridgeServer(token: 'secret');
//   await server.start(); // binds 127.0.0.1:0
//   ... drive the app against 127.0.0.1:${server.port} ...
//   await server.stop();

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FakeBridgeServer {
  FakeBridgeServer({this.token});

  final String? token;

  HttpServer? _server;
  final Set<WebSocket> _clients = <WebSocket>{};
  final List<Map<String, dynamic>> receivedCommands = <Map<String, dynamic>>[];
  final Map<String, Completer<Map<String, dynamic>>> _uiResponders =
      <String, Completer<Map<String, dynamic>>>{};

  bool _turnInProgress = false;
  final List<String> _steering = <String>[];

  int get port => _server!.port;
  String get host => InternetAddress.loopbackIPv4.address;
  Set<WebSocket> get clients => _clients;

  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    for (final ws in _clients.toList()) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  /// Broadcast an arbitrary envelope to all connected clients.
  void emit(Map<String, dynamic> event) {
    final line = jsonEncode(event);
    for (final ws in _clients) {
      try {
        ws.add(line);
      } catch (_) {}
    }
  }

  Future<void> _handleRequest(HttpRequest req) async {
    if (req.uri.path == '/health') {
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'status': 'ok'}));
      await req.response.close();
      return;
    }

    if (req.uri.path == '/info') {
      if (token != null && !_authOk(req)) {
        req.response.statusCode = HttpStatus.unauthorized;
        await req.response.close();
        return;
      }
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'version': 'fake-bridge',
        'name': 'fake',
        'id': 'fake-machine',
      }));
      await req.response.close();
      return;
    }

    if (req.uri.path != '/rpc') {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    if (token != null && !_authOk(req)) {
      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(req);
    _clients.add(socket);
    socket.listen(
      (message) => _onMessage(socket, message),
      onDone: () => _clients.remove(socket),
      onError: (_) => _clients.remove(socket),
    );
  }

  bool _authOk(HttpRequest req) {
    final header = req.headers.value(HttpHeaders.authorizationHeader);
    return header == 'Bearer $token';
  }

  void _onMessage(WebSocket socket, dynamic message) {
    late Map<String, dynamic> obj;
    try {
      obj = (jsonDecode(message as String) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    receivedCommands.add(obj);

    final type = obj['type'] as String? ?? '';
    final id = obj['id'] as String?;

    if (type == 'extension_ui_response') {
      final respId = obj['id'] as String?;
      if (respId != null && _uiResponders.containsKey(respId)) {
        _uiResponders.remove(respId)?.complete(obj);
      }
      return;
    }

    if (type == 'steer' && _turnInProgress) {
      _steering.add(obj['message'] as String? ?? '');
      if (id != null) {
        socket.add(jsonEncode({
          'id': id,
          'type': 'response',
          'command': 'steer',
          'success': true,
        }));
      }
      emit({'type': 'queue_update', 'steering': _steering, 'followUp': <String>[]});
      return;
    }

    if (id != null) {
      _autoRespond(socket, obj, id, type);
    }

    if (type == 'prompt') {
      // Fire the scripted turn without blocking the socket listener.
      // ignore: unawaited_futures, discarded_futures
      _runScriptedTurn(socket, obj);
    }
  }

  void _autoRespond(WebSocket socket, Map<String, dynamic> obj, String id, String type) {
    Map<String, dynamic> data = <String, dynamic>{};
    switch (type) {
      case 'get_state':
        data = {
          'model': {
            'id': 'fake-model',
            'name': 'Fake Model',
            'provider': 'fake',
            'contextWindow': 128000,
            'maxTokens': 8192,
            'input': <String>['text'],
            'reasoning': false,
            'cost': {'input': 0.0, 'output': 0.0, 'cacheRead': 0.0, 'cacheWrite': 0.0},
          },
          'thinkingLevel': 'low',
          'permissionMode': 'default',
          'planMode': false,
          'isStreaming': false,
          'isCompacting': false,
          'steeringMode': 'one-at-a-time',
          'followUpMode': 'one-at-a-time',
          'cwd': '/tmp/fake',
          'sessionFile': null,
          'sessionId': 'fake-session',
          'sessionName': 'fake session',
          'autoCompactionEnabled': true,
          'compactionAutoContinue': true,
          'messageCount': 0,
          'pendingMessageCount': 0,
        };
        break;
      case 'list_sessions':
        data = {
          'sessions': [
            {
              'path': '/tmp/fake/fake.jsonl',
              'id': 'fake-session',
              'cwd': '/tmp/fake',
              'name': 'fake session',
              'created': DateTime.now().toIso8601String(),
              'modified': DateTime.now().toIso8601String(),
              'messageCount': 0,
              'firstMessage': 'hello',
            },
          ],
        };
        break;
      case 'get_messages':
        data = {'messages': <Map<String, dynamic>>[]};
        break;
      case 'get_sessions_status':
        data = {'sessions': <Map<String, dynamic>>[]};
        break;
      default:
        break;
    }
    socket.add(jsonEncode({
      'id': id,
      'type': 'response',
      'command': type,
      'success': true,
      'data': data,
    }));
  }

  Future<void> _runScriptedTurn(WebSocket socket, Map<String, dynamic> prompt) async {
    _turnInProgress = true;
    _steering.clear();
    final userText = prompt['message'] as String? ?? '';
    // agent_start
    emit({'type': 'agent_start'});
    await Future<void>.delayed(Duration.zero);
    emit({'type': 'turn_start'});

    emit({
      'type': 'message_start',
      'message': _assistantMsg(''),
    });
    await Future<void>.delayed(Duration.zero);
    emit({
      'type': 'message_update',
      'message': _assistantMsg('Thinking about it…'),
      'assistantMessageEvent': {'type': 'text_delta'},
    });
    await Future<void>.delayed(Duration.zero);
    emit({
      'type': 'message_end',
      'message': _assistantMsg('Thinking about it…'),
    });

    // Permission-gated tool.
    final uiReqId = 'ui-${DateTime.now().microsecondsSinceEpoch}';
    final uiCompleter = Completer<Map<String, dynamic>>();
    _uiResponders[uiReqId] = uiCompleter;
    emit({
      'type': 'extension_ui_request',
      'id': uiReqId,
      'method': 'confirm',
      'kind': 'permission',
      'toolName': 'edit',
      'title': 'Allow edit?',
      'message': 'Apply edit to src/x.ts?',
    });

    // Wait for the client's answer (or time out gracefully).
    Map<String, dynamic>? answer;
    try {
      answer = await uiCompleter.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      answer = {'cancelled': true};
    }
    final confirmed = answer['confirmed'] == true;

    if (confirmed) {
      emit({
        'type': 'tool_execution_start',
        'toolCallId': 'tc-1',
        'toolName': 'edit',
        'args': {'path': 'src/x.ts', 'oldText': 'foo', 'newText': 'bar'},
      });
      await Future<void>.delayed(Duration.zero);
      emit({
        'type': 'tool_execution_end',
        'toolCallId': 'tc-1',
        'toolName': 'edit',
        'result': {
          'content': [
            {'type': 'text', 'text': 'edited 1 file'},
          ],
          'details': {
            'diff': '--- a/src/x.ts\n+++ b/src/x.ts\n@@ -1,3 +1,3 @@\n ctx\n-foo()\n+bar()\n',
          },
          'isError': false,
        },
        'isError': false,
      });
      await Future<void>.delayed(Duration.zero);
      emit({
        'type': 'message_start',
        'message': {
          'role': 'toolResult',
          'toolCallId': 'tc-1',
          'toolName': 'edit',
          'content': [
            {'type': 'text', 'text': 'edited 1 file'},
          ],
          'details': {
            'diff': '--- a/src/x.ts\n+++ b/src/x.ts\n@@ -1,3 +1,3 @@\n ctx\n-foo()\n+bar()\n',
          },
          'isError': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });
      await Future<void>.delayed(Duration.zero);
      emit({
        'type': 'message_end',
        'message': {
          'role': 'toolResult',
          'toolCallId': 'tc-1',
          'toolName': 'edit',
          'content': [
            {'type': 'text', 'text': 'edited 1 file'},
          ],
          'isError': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });
    }

    // Final assistant answer (may reflect steer).
    final suffix = _steering.isEmpty ? '' : ' (steered: ${_steering.join(', ')})';
    final finalText = userText.isEmpty
        ? 'Final answer.$suffix'
        : 'Final answer to: $userText$suffix';
    emit({
      'type': 'message_start',
      'message': _assistantMsg(finalText),
    });
    await Future<void>.delayed(Duration.zero);
    emit({
      'type': 'message_update',
      'message': _assistantMsg(finalText),
      'assistantMessageEvent': {'type': 'text_delta'},
    });
    await Future<void>.delayed(Duration.zero);
    emit({
      'type': 'message_end',
      'message': _assistantMsg(finalText),
    });

    emit({
      'type': 'turn_end',
      'message': _assistantMsg(finalText),
      'toolResults': <Map<String, dynamic>>[],
      'usage': {
        'input': 10,
        'output': 20,
        'cacheRead': 0,
        'cacheWrite': 0,
        'cost': {'total': 0.001},
      },
    });
    emit({
      'type': 'agent_end',
      'messages': <Map<String, dynamic>>[],
      'willRetry': false,
    });
    emit({'type': 'queue_update', 'steering': <String>[], 'followUp': <String>[]});
    _turnInProgress = false;
  }

  Map<String, dynamic> _assistantMsg(String text) => {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': text},
        ],
        'api': 'fake',
        'provider': 'fake',
        'model': 'fake-model',
        'usage': {
          'input': 0,
          'output': 0,
          'cacheRead': 0,
          'cacheWrite': 0,
        },
        'stopReason': 'stop',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
}
