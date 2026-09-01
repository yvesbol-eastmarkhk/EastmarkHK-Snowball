import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eastmarkhk_snowball/calculator.dart';
import 'package:eastmarkhk_snowball/models/client_report.dart';
import 'package:eastmarkhk_snowball/services/client_report_store.dart';

void main() {
  test('monthly compounding grows a principal', () {
    final result = calculateCompoundGrowth(
      principal: 10000,
      annualRatePercent: 12,
      years: 1,
      compounding: CompoundingFrequency.monthly,
    );
    expect(result.finalBalance, greaterThan(10000));
    expect(result.yearly, hasLength(1));
    expect(result.monthly, hasLength(12));
  });

  test('goal contribution is zero when principal already reaches the target', () {
    final needed = requiredContributionForGoal(
      principal: 100000,
      annualRatePercent: 5,
      years: 10,
      compounding: CompoundingFrequency.monthly,
      targetBalance: 100000,
    );
    expect(needed, 0);
  });

  test('goal contribution reaches the target balance', () {
    const principal = 50000.0;
    const rate = 6.0;
    const years = 8;
    const target = 120000.0;
    final needed = requiredContributionForGoal(
      principal: principal,
      annualRatePercent: rate,
      years: years,
      compounding: CompoundingFrequency.monthly,
      targetBalance: target,
      contributionFrequency: ContributionFrequency.monthly,
    );
    expect(needed, isNotNull);
    expect(needed!, greaterThan(0));
    final result = calculateCompoundGrowth(
      principal: principal,
      annualRatePercent: rate,
      years: years,
      compounding: CompoundingFrequency.monthly,
      contributionAmount: needed,
      contributionFrequency: ContributionFrequency.monthly,
    );
    expect(result.finalBalance, closeTo(target, 1));
  });

  test('sample client report is dual-currency HKD to USD', () {
    final sample = ClientReport.sample();
    expect(sample.isDualCurrency, isTrue);
    expect(sample.investCurrency, 'HKD');
    expect(sample.referenceCurrency, 'USD');
    expect(sample.clientName, isNotEmpty);
    expect(sample.calculate().finalBalance, greaterThan(sample.principal));
  });

  test('client report store seeds a sample once and round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await ClientReportStore.load();
    expect(first, isNotEmpty);
    expect(first.first.isSample, isTrue);

    final extra = first.first.duplicated(copySuffix: 'copy');
    await ClientReportStore.upsert(extra);
    final second = await ClientReportStore.load();
    expect(second.length, 2);

    await ClientReportStore.delete(extra.id);
    final third = await ClientReportStore.load();
    expect(third.length, 1);
    expect(third.first.isSample, isTrue);
  });
}
