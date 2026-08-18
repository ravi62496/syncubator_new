import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;

/// Loads the Syncubator Pi's self-signed certificate once at startup and
/// exposes a single shared, trusted HTTP client for the whole app to reuse
/// — for both regular JSON API calls and the MJPEG camera stream.
///
/// IMPORTANT: this trusts ONLY this exact certificate (pinned by its bytes),
/// not certificates in general. That's the safe way to talk to a
/// self-signed server. Do NOT replace this with a blanket
/// `badCertificateCallback: (cert, host, port) => true` — that would accept
/// ANY certificate from ANY server, which defeats the point of using HTTPS
/// at all and would leave the app vulnerable to a man-in-the-middle
/// impersonating the Pi.
class SecureHttpClient {
  SecureHttpClient._();

  static http.Client? _client;
  static Completer<http.Client>? _initializing;

  /// Call this once, early in main(), before runApp(). Awaiting this in
  /// main() guarantees the client is ready before any screen tries to use
  /// SecureHttpClient.instance.
  static Future<void> init() async {
    if (_client != null) return;
    if (_initializing != null) {
      await _initializing!.future;
      return;
    }
    _initializing = Completer<http.Client>();
    try {
      final certData = await rootBundle.load('assets/certs/syncubator.crt');
      final context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(certData.buffer.asUint8List());

      final rawClient = HttpClient(context: context);
      final wrapped = io_client.IOClient(rawClient);

      _client = wrapped;
      _initializing!.complete(wrapped);
    } catch (e, st) {
      _initializing!.completeError(e, st);
      rethrow;
    }
  }

  /// The shared trusted client. Throws a clear error if init() wasn't
  /// awaited first, rather than silently falling back to an untrusted
  /// client that would just fail TLS validation anyway.
  static http.Client get instance {
    final client = _client;
    if (client == null) {
      throw StateError(
        'SecureHttpClient.init() must be awaited in main() before '
            'SecureHttpClient.instance is used anywhere in the app.',
      );
    }
    return client;
  }
}