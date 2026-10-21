// lib/models/filter_result.dart
class FilterResult {
  final bool? activeOnly;
  final double? priceStart;
  final double? priceEnd;
  final String? vehicle;
  final bool? onlyDirect;
  final String? direction; // 'local' | 'outbound' | 'inbound'
  final String? from;
  final String? to;
  final DateTime? startDate;
  final DateTime? endDate;

  const FilterResult({
    this.activeOnly,
    this.priceStart,
    this.priceEnd,
    this.vehicle,
    this.onlyDirect,
    this.direction,
    this.from,
    this.to,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'activeOnly': activeOnly,
      'priceStart': priceStart,
      'priceEnd': priceEnd,
      'vehicle': vehicle,
      'onlyDirect': onlyDirect,
      'direction': direction,
      'from': from,
      'to': to,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory FilterResult.fromMap(Map? map) {
    if (map == null) return const FilterResult();
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return FilterResult(
      activeOnly: map['activeOnly'] as bool?,
      priceStart: (map['priceStart'] is num) ? (map['priceStart'] as num).toDouble() : null,
      priceEnd: (map['priceEnd'] is num) ? (map['priceEnd'] as num).toDouble() : null,
      vehicle: map['vehicle'] as String?,
      onlyDirect: map['onlyDirect'] as bool?,
      direction: map['direction'] as String?,
      from: map['from'] as String?,
      to: map['to'] as String?,
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
    );
  }
}
