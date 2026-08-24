/// Currencies offered in the picker. [flagCountry] is an ISO country
/// code, or `EUR` for the European Union flag.
class CurrencyOption {
  final String code;
  final String name;
  final String symbol;
  final String flagCountry;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flagCountry,
  });
}

const List<CurrencyOption> supportedCurrencies = [
  CurrencyOption(code: 'HKD', name: 'Hong Kong Dollar', symbol: r'HK$', flagCountry: 'HK'),
  CurrencyOption(code: 'USD', name: 'US Dollar', symbol: r'$', flagCountry: 'US'),
  CurrencyOption(code: 'EUR', name: 'Euro', symbol: '€', flagCountry: 'EUR'),
  CurrencyOption(code: 'GBP', name: 'British Pound', symbol: '£', flagCountry: 'GB'),
  CurrencyOption(code: 'BRL', name: 'Brazilian Real', symbol: r'R$', flagCountry: 'BR'),
  CurrencyOption(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flagCountry: 'CN'),
  CurrencyOption(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flagCountry: 'JP'),
  CurrencyOption(code: 'KRW', name: 'South Korean Won', symbol: '₩', flagCountry: 'KR'),
  CurrencyOption(code: 'SGD', name: 'Singapore Dollar', symbol: r'S$', flagCountry: 'SG'),
  CurrencyOption(code: 'AUD', name: 'Australian Dollar', symbol: r'A$', flagCountry: 'AU'),
  CurrencyOption(code: 'CAD', name: 'Canadian Dollar', symbol: r'C$', flagCountry: 'CA'),
  CurrencyOption(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', flagCountry: 'CH'),
  CurrencyOption(code: 'INR', name: 'Indian Rupee', symbol: '₹', flagCountry: 'IN'),
  CurrencyOption(code: 'MXN', name: 'Mexican Peso', symbol: r'MX$', flagCountry: 'MX'),
  CurrencyOption(code: 'THB', name: 'Thai Baht', symbol: '฿', flagCountry: 'TH'),
  CurrencyOption(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', flagCountry: 'ID'),
  CurrencyOption(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flagCountry: 'MY'),
  CurrencyOption(code: 'PHP', name: 'Philippine Peso', symbol: '₱', flagCountry: 'PH'),
  CurrencyOption(code: 'TWD', name: 'New Taiwan Dollar', symbol: r'NT$', flagCountry: 'TW'),
  CurrencyOption(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flagCountry: 'AE'),
  CurrencyOption(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flagCountry: 'SA'),
  CurrencyOption(code: 'ZAR', name: 'South African Rand', symbol: 'R', flagCountry: 'ZA'),
  CurrencyOption(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', flagCountry: 'SE'),
  CurrencyOption(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', flagCountry: 'NO'),
  CurrencyOption(code: 'DKK', name: 'Danish Krone', symbol: 'kr', flagCountry: 'DK'),
  CurrencyOption(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', flagCountry: 'PL'),
  CurrencyOption(code: 'TRY', name: 'Turkish Lira', symbol: '₺', flagCountry: 'TR'),
  CurrencyOption(code: 'NZD', name: 'New Zealand Dollar', symbol: r'NZ$', flagCountry: 'NZ'),
  CurrencyOption(code: 'VND', name: 'Vietnamese Dong', symbol: '₫', flagCountry: 'VN'),
];

CurrencyOption? currencyByCode(String code) {
  for (final c in supportedCurrencies) {
    if (c.code == code) return c;
  }
  return null;
}

String currencySymbol(String code) => currencyByCode(code)?.symbol ?? '$code ';
