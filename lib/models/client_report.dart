import '../calculator.dart';

enum ReportMode { project, goal }

/// A named client growth report stored only on this device.
class ClientReport {
  static const sampleId = 'sample-chen-wei';

  final String id;
  final String clientName;
  final String notes;
  final ReportMode mode;
  final double principal;
  final double annualRatePercent;
  final int years;
  final CompoundingFrequency compounding;
  final bool addContributions;
  final double contributionAmount;
  final ContributionFrequency contributionFrequency;
  final double? targetBalance;
  final String investCurrency;
  final String referenceCurrency;
  final DateTime updatedAt;

  const ClientReport({
    required this.id,
    required this.clientName,
    this.notes = '',
    this.mode = ReportMode.project,
    required this.principal,
    required this.annualRatePercent,
    required this.years,
    this.compounding = CompoundingFrequency.monthly,
    this.addContributions = false,
    this.contributionAmount = 0,
    this.contributionFrequency = ContributionFrequency.monthly,
    this.targetBalance,
    required this.investCurrency,
    required this.referenceCurrency,
    required this.updatedAt,
  });

  bool get isSample => id == sampleId;

  bool get isDualCurrency =>
      investCurrency.toUpperCase() != referenceCurrency.toUpperCase();

  static String newId() =>
      'r-${DateTime.now().microsecondsSinceEpoch}';

  ClientReport copyWith({
    String? id,
    String? clientName,
    String? notes,
    ReportMode? mode,
    double? principal,
    double? annualRatePercent,
    int? years,
    CompoundingFrequency? compounding,
    bool? addContributions,
    double? contributionAmount,
    ContributionFrequency? contributionFrequency,
    double? targetBalance,
    bool clearTarget = false,
    String? investCurrency,
    String? referenceCurrency,
    DateTime? updatedAt,
  }) {
    return ClientReport(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      notes: notes ?? this.notes,
      mode: mode ?? this.mode,
      principal: principal ?? this.principal,
      annualRatePercent: annualRatePercent ?? this.annualRatePercent,
      years: years ?? this.years,
      compounding: compounding ?? this.compounding,
      addContributions: addContributions ?? this.addContributions,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      contributionFrequency:
          contributionFrequency ?? this.contributionFrequency,
      targetBalance:
          clearTarget ? null : (targetBalance ?? this.targetBalance),
      investCurrency: investCurrency ?? this.investCurrency,
      referenceCurrency: referenceCurrency ?? this.referenceCurrency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ClientReport duplicated({required String copySuffix}) {
    return copyWith(
      id: newId(),
      clientName: '$clientName ($copySuffix)',
      updatedAt: DateTime.now(),
    );
  }

  CalculationResult calculate() {
    return calculateCompoundGrowth(
      principal: principal,
      annualRatePercent: annualRatePercent,
      years: years,
      compounding: compounding,
      contributionAmount: addContributions ? contributionAmount : 0,
      contributionFrequency: contributionFrequency,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'notes': notes,
        'mode': mode.name,
        'principal': principal,
        'annualRatePercent': annualRatePercent,
        'years': years,
        'compounding': compounding.name,
        'addContributions': addContributions,
        'contributionAmount': contributionAmount,
        'contributionFrequency': contributionFrequency.name,
        'targetBalance': targetBalance,
        'investCurrency': investCurrency,
        'referenceCurrency': referenceCurrency,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClientReport.fromJson(Map<String, dynamic> json) {
    T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is! String) return fallback;
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    return ClientReport(
      id: json['id'] as String? ?? newId(),
      clientName: json['clientName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      mode: enumByName(ReportMode.values, json['mode'], ReportMode.project),
      principal: (json['principal'] as num?)?.toDouble() ?? 0,
      annualRatePercent: (json['annualRatePercent'] as num?)?.toDouble() ?? 0,
      years: (json['years'] as num?)?.toInt() ?? 1,
      compounding: enumByName(
        CompoundingFrequency.values,
        json['compounding'],
        CompoundingFrequency.monthly,
      ),
      addContributions: json['addContributions'] as bool? ?? false,
      contributionAmount: (json['contributionAmount'] as num?)?.toDouble() ?? 0,
      contributionFrequency: enumByName(
        ContributionFrequency.values,
        json['contributionFrequency'],
        ContributionFrequency.monthly,
      ),
      targetBalance: (json['targetBalance'] as num?)?.toDouble(),
      investCurrency: json['investCurrency'] as String? ?? 'HKD',
      referenceCurrency: json['referenceCurrency'] as String? ?? 'USD',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Dual-currency Hong Kong client — seeded once so a reviewer (or first
  /// launch) sees the actual product, not an empty calculator.
  static ClientReport sample() {
    return ClientReport(
      id: sampleId,
      clientName: 'Chen Wei',
      notes:
          'Hong Kong client. Figures stay in HKD; the PDF also presents them in USD.',
      mode: ReportMode.project,
      principal: 500000,
      annualRatePercent: 6.5,
      years: 10,
      compounding: CompoundingFrequency.monthly,
      addContributions: true,
      contributionAmount: 8000,
      contributionFrequency: ContributionFrequency.monthly,
      investCurrency: 'HKD',
      referenceCurrency: 'USD',
      updatedAt: DateTime.now(),
    );
  }
}
