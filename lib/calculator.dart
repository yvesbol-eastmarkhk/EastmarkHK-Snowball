/// Core compound-interest calculation logic for EastmarkHK Snowball.
library;

enum CompoundingFrequency {
  annually(1, 'Annually'),
  semiAnnually(2, 'Semi-annually'),
  quarterly(4, 'Quarterly'),
  monthly(12, 'Monthly'),
  weekly(52, 'Weekly'),
  daily(365, 'Daily');

  final int periodsPerYear;
  final String label;
  const CompoundingFrequency(this.periodsPerYear, this.label);
}

enum ContributionFrequency {
  monthly(12, 'Monthly'),
  annually(1, 'Annually');

  final int periodsPerYear;
  final String label;
  const ContributionFrequency(this.periodsPerYear, this.label);
}

/// One row of the year-by-year growth table (rolled up from months).
class YearlyBreakdown {
  final int year;
  final double contributionsThisYear;
  final double interestThisYear;
  final double balanceEnd;

  const YearlyBreakdown({
    required this.year,
    required this.contributionsThisYear,
    required this.interestThisYear,
    required this.balanceEnd,
  });
}

/// One row of the month-by-month growth table.
class MonthlyBreakdown {
  final int year;
  final int month;
  final double contributionsThisMonth;
  final double interestThisMonth;
  final double balanceEnd;

  const MonthlyBreakdown({
    required this.year,
    required this.month,
    required this.contributionsThisMonth,
    required this.interestThisMonth,
    required this.balanceEnd,
  });
}

class CalculationResult {
  final double finalBalance;
  final double totalPrincipal;
  final double totalContributions;
  final double totalInterest;
  final List<YearlyBreakdown> yearly;
  final List<MonthlyBreakdown> monthly;

  const CalculationResult({
    required this.finalBalance,
    required this.totalPrincipal,
    required this.totalContributions,
    required this.totalInterest,
    required this.yearly,
    required this.monthly,
  });
}

/// Simulates growth month by month so the table and PDF can show a full
/// monthly breakdown. Interest is applied on compounding months (or as
/// weekly/daily steps rolled into that month); contributions are spread
/// evenly across the year.
CalculationResult calculateCompoundGrowth({
  required double principal,
  required double annualRatePercent,
  required int years,
  required CompoundingFrequency compounding,
  double contributionAmount = 0,
  ContributionFrequency contributionFrequency = ContributionFrequency.monthly,
}) {
  final double annualRate = annualRatePercent / 100;
  final int totalMonths = years * 12;
  final double contributionPerMonth =
      contributionAmount * contributionFrequency.periodsPerYear / 12.0;

  double balance = principal;
  double contributedSoFar = 0;
  final monthly = <MonthlyBreakdown>[];

  int weeklyApplied = 0;
  int dailyApplied = 0;
  final int totalWeeks = years * 52;
  final int totalDays = years * 365;

  for (int month = 1; month <= totalMonths; month++) {
    final int yearNumber = ((month - 1) ~/ 12) + 1;
    final int monthOfYear = ((month - 1) % 12) + 1;
    double monthInterest = 0;

    void applyPeriod(double periodRate) {
      final interest = balance * periodRate;
      monthInterest += interest;
      balance += interest;
    }

    switch (compounding) {
      case CompoundingFrequency.monthly:
        applyPeriod(annualRate / 12);
      case CompoundingFrequency.quarterly:
        if (month % 3 == 0) applyPeriod(annualRate / 4);
      case CompoundingFrequency.semiAnnually:
        if (month % 6 == 0) applyPeriod(annualRate / 2);
      case CompoundingFrequency.annually:
        if (month % 12 == 0) applyPeriod(annualRate);
      case CompoundingFrequency.weekly:
        final targetWeeks = ((month / totalMonths) * totalWeeks).round();
        final weeks = targetWeeks - weeklyApplied;
        weeklyApplied = targetWeeks;
        for (int i = 0; i < weeks; i++) {
          applyPeriod(annualRate / 52);
        }
      case CompoundingFrequency.daily:
        final targetDays = ((month / totalMonths) * totalDays).round();
        final days = targetDays - dailyApplied;
        dailyApplied = targetDays;
        for (int i = 0; i < days; i++) {
          applyPeriod(annualRate / 365);
        }
    }

    balance += contributionPerMonth;
    contributedSoFar += contributionPerMonth;

    monthly.add(MonthlyBreakdown(
      year: yearNumber,
      month: monthOfYear,
      contributionsThisMonth: contributionPerMonth,
      interestThisMonth: monthInterest,
      balanceEnd: balance,
    ));
  }

  final yearly = <YearlyBreakdown>[];
  for (int year = 1; year <= years; year++) {
    final rows = monthly.where((m) => m.year == year);
    yearly.add(YearlyBreakdown(
      year: year,
      contributionsThisYear:
          rows.fold<double>(0, (s, m) => s + m.contributionsThisMonth),
      interestThisYear: rows.fold<double>(0, (s, m) => s + m.interestThisMonth),
      balanceEnd: rows.isEmpty ? balance : rows.last.balanceEnd,
    ));
  }

  // When interest is applied only a few times a year, spread that year's
  // totals evenly so the monthly table still shows an estimate for each
  // month. Year-end totals stay exact.
  final displayMonthly = compounding.periodsPerYear < 12
      ? _evenMonthlyEstimates(yearly, principal)
      : monthly;

  return CalculationResult(
    finalBalance: balance,
    totalPrincipal: principal,
    totalContributions: contributedSoFar,
    totalInterest: balance - principal - contributedSoFar,
    yearly: yearly,
    monthly: displayMonthly,
  );
}

/// Spreads each year's contributions and interest across 12 months so the
/// table can show a monthly estimate even when compounding is annual,
/// semi-annual, or quarterly. Month 12 absorbs rounding so the year total
/// still matches.
List<MonthlyBreakdown> _evenMonthlyEstimates(
  List<YearlyBreakdown> yearly,
  double startingPrincipal,
) {
  final estimated = <MonthlyBreakdown>[];
  double start = startingPrincipal;
  for (final y in yearly) {
    final avgContribution = y.contributionsThisYear / 12;
    final avgInterest = y.interestThisYear / 12;
    double contributionLeft = y.contributionsThisYear;
    double interestLeft = y.interestThisYear;
    double running = start;
    for (int month = 1; month <= 12; month++) {
      final contribution =
          month == 12 ? contributionLeft : avgContribution;
      final interest = month == 12 ? interestLeft : avgInterest;
      contributionLeft -= contribution;
      interestLeft -= interest;
      running += contribution + interest;
      estimated.add(MonthlyBreakdown(
        year: y.year,
        month: month,
        contributionsThisMonth: contribution,
        interestThisMonth: interest,
        balanceEnd: month == 12 ? y.balanceEnd : running,
      ));
    }
    start = y.balanceEnd;
  }
  return estimated;
}

/// One row in the month-by-month table, including year-total rollups.
class BreakdownDisplayRow {
  final int year;
  final int? month;
  final double contributions;
  final double interest;
  final double balance;
  final bool isYearTotal;

  const BreakdownDisplayRow({
    required this.year,
    this.month,
    required this.contributions,
    required this.interest,
    required this.balance,
    required this.isYearTotal,
  });
}

/// Monthly estimates followed by a year-total row after each December.
List<BreakdownDisplayRow> breakdownTableRows(CalculationResult result) {
  final rows = <BreakdownDisplayRow>[];
  for (final y in result.yearly) {
    for (final m in result.monthly.where((m) => m.year == y.year)) {
      rows.add(BreakdownDisplayRow(
        year: m.year,
        month: m.month,
        contributions: m.contributionsThisMonth,
        interest: m.interestThisMonth,
        balance: m.balanceEnd,
        isYearTotal: false,
      ));
    }
    rows.add(BreakdownDisplayRow(
      year: y.year,
      month: null,
      contributions: y.contributionsThisYear,
      interest: y.interestThisYear,
      balance: y.balanceEnd,
      isYearTotal: true,
    ));
  }
  return rows;
}
