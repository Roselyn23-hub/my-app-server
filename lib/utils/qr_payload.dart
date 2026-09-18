import 'dart:convert';

/// What actually gets encoded into (and read back out of) a document's
/// QR code.
///
/// The QR now carries a URL, e.g. https://my-app-server-w0ms.onrender.com/doc/abc123 —
/// not the document's title/type/route. A generic scanner (Google
/// Camera, Samsung Camera, any random QR app) recognizes this as a
/// link and offers to open it, instead of just dumping raw JSON text
/// on screen. Once app-links/universal-links are configured for the
/// domain, that same tap opens straight into this app; if the app
/// isn't installed, it falls back to a web page.
///
/// The "id" is still what the app uses to look up the LIVE
/// status/route from Supabase, since that data changes over time and
/// the QR itself is never re-printed.
class QrPayload {
  // Your live Render backend URL.
  // NOTE: if your Render URL ever changes (e.g. you rename the service
  // or redeploy under a different name), update this constant.
  static const String baseUrl = 'https://my-app-server-w0ms.onrender.com/doc/';

  final String id;
  final String title;
  final String documentType;
  final String createdBy;
  final String createdAt;
  final List<String> route; // office usernames, in order

  QrPayload({
    required this.id,
    required this.title,
    required this.documentType,
    required this.createdBy,
    required this.createdAt,
    required this.route,
  });

  /// Turns this into the URL string that gets encoded into the QR
  /// image. Only the ID travels in the QR now — title/type/createdBy/
  /// route are re-fetched live from the database after lookup, so
  /// nothing from this object other than `id` is actually needed here.
  String encode() {
    return '$baseUrl$id';
  }

  /// Extracts just the document ID from a scanned QR string.
  ///
  /// Handles three cases, in order, so old QR codes keep working:
  /// 1. New-style URL, e.g. https://my-app-server-w0ms.onrender.com/doc/abc123 -> abc123
  /// 2. Old-style JSON, e.g. {"id":"abc123",...} -> abc123
  /// 3. Old-style bare ID, e.g. abc123 -> abc123
  static String decodeId(String scanned) {
    final uri = Uri.tryParse(scanned);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    try {
      final map = jsonDecode(scanned);
      if (map is Map && map['id'] != null) {
        return map['id'].toString();
      }
    } catch (_) {
      // Not JSON either — treat as a bare ID below.
    }

    return scanned;
  }

  /// Full parse, for showing embedded data before/without a database
  /// call (e.g. an offline preview). Only works for old-style JSON QR
  /// codes, since new-style URL QR codes don't carry this data anymore
  /// — callers should look the document up by ID instead. Returns null
  /// for URL or bare-ID payloads.
  static QrPayload? tryParse(String scanned) {
    try {
      final map = jsonDecode(scanned);
      if (map is Map && map['id'] != null) {
        return QrPayload(
          id: map['id'].toString(),
          title: map['title']?.toString() ?? '',
          documentType: map['type']?.toString() ?? '',
          createdBy: map['createdBy']?.toString() ?? '',
          createdAt: map['createdAt']?.toString() ?? '',
          route: (map['route'] as List?)?.map((e) => e.toString()).toList() ?? [],
        );
      }
    } catch (_) {
      // Not JSON — new-style URL or old-style bare ID.
    }
    return null;
  }
}
