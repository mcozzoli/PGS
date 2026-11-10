import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Errore applicativo con messaggio leggibile (come l'`api()` del portale).
class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Lanciata su 401 quando c'era un token: sessione scaduta.
class SessionExpired extends ApiException {
  SessionExpired() : super('Sessione scaduta', 401);
}

/// Client HTTP per l'API del portale basketsalgen.
class Api {
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final uri = Uri.parse('${Config.apiRoot}$path');
    late http.Response res;
    try {
      final b = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: _headers, body: b);
          break;
        case 'PUT':
          res = await http.put(uri, headers: _headers, body: b);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: _headers, body: b);
          break;
        default:
          res = await http.get(uri, headers: _headers);
      }
    } catch (_) {
      throw ApiException('Connessione non riuscita. Controlla la rete.');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (res.statusCode == 401 && token != null) {
      throw SessionExpired();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Errore';
      throw ApiException(msg, res.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final r = await request(path);
    return (r is Map) ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }
}
