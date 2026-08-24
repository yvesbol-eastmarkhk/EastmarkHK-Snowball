import 'dart:convert';

import 'package:http/http.dart' as http;

/// One quote: 1 [from] = [rate] [to]. Only this pair is requested.
class ExchangeQuote {
  final String from;
  final String to;
  final double rate;
  final DateTime asOf;
  final String source;

  const ExchangeQuote({
    required this.from,
    required this.to,
    required this.rate,
    required this.asOf,
    required this.source,
  });
}

/// Fetches a live rate for exactly two currencies (investment → customer
/// reference). Tries the ECB Frankfurter API first (pair-only request),
/// then open.er-api.com if that pair is not listed there.
class ExchangeRateService {
  ExchangeRateService._();

  static Future<ExchangeQuote> quote({
    required String from,
    required String to,
  }) async {
    final a = from.toUpperCase();
    final b = to.toUpperCase();
    if (a == b) {
      return ExchangeQuote(
        from: a,
        to: b,
        rate: 1,
        asOf: DateTime.now(),
        source: 'same',
      );
    }

    try {
      return await _frankfurter(a, b);
    } catch (_) {
      return _openErApi(a, b);
    }
  }

  static Future<ExchangeQuote> _frankfurter(String from, String to) async {
    final uri = Uri.https('api.frankfurter.app', '/latest', {
      'from': from,
      'to': to,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Frankfurter ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw Exception('Unexpected exchange-rate payload.');
    final rates = decoded['rates'];
    if (rates is! Map || rates[to] == null) {
      throw Exception('No $from→$to rate from Frankfurter.');
    }
    final rate = (rates[to] as num).toDouble();
    final dateRaw = decoded['date']?.toString();
    final asOf = dateRaw == null ? DateTime.now() : DateTime.tryParse(dateRaw) ?? DateTime.now();
    return ExchangeQuote(
      from: from,
      to: to,
      rate: rate,
      asOf: asOf,
      source: 'ECB',
    );
  }

  static Future<ExchangeQuote> _openErApi(String from, String to) async {
    final uri = Uri.https('open.er-api.com', '/v6/latest/$from');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Exchange API ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw Exception('Unexpected exchange-rate payload.');
    final rates = decoded['rates'];
    if (rates is! Map || rates[to] == null) {
      throw Exception('No $from→$to rate available.');
    }
    final rate = (rates[to] as num).toDouble();
    final dateRaw = decoded['time_last_update_utc']?.toString();
    final asOf = dateRaw == null
        ? DateTime.now()
        : DateTime.tryParse(dateRaw) ?? DateTime.now();
    return ExchangeQuote(
      from: from,
      to: to,
      rate: rate,
      asOf: asOf,
      source: 'open.er-api.com',
    );
  }
}
