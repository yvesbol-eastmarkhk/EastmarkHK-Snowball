import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/client_report.dart';

/// On-device list of client reports. Never sent to a server.
class ClientReportStore {
  ClientReportStore._();

  static const _key = 'client_reports_v1';
  static const _seededKey = 'client_reports_sample_seeded_v1';

  static Future<List<ClientReport>> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _seedSampleIfNeeded(prefs);
    return _read(prefs);
  }

  static Future<void> upsert(ClientReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = _read(prefs);
    final index = reports.indexWhere((r) => r.id == report.id);
    final next = List<ClientReport>.from(reports);
    if (index >= 0) {
      next[index] = report;
    } else {
      next.insert(0, report);
    }
    next.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _write(prefs, next);
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = _read(prefs).where((r) => r.id != id).toList();
    await _write(prefs, reports);
  }

  static List<ClientReport> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => ClientReport.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(
    SharedPreferences prefs,
    List<ClientReport> reports,
  ) async {
    await prefs.setString(
      _key,
      jsonEncode(reports.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> _seedSampleIfNeeded(SharedPreferences prefs) async {
    if (prefs.getBool(_seededKey) == true) return;
    final existing = _read(prefs);
    if (existing.isEmpty) {
      await _write(prefs, [ClientReport.sample()]);
    }
    await prefs.setBool(_seededKey, true);
  }
}
