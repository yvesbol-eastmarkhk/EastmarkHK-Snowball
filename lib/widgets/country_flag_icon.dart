import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

/// Country flag at a fixed size. Flag emojis do not render on Windows,
/// so this uses the same `country_flags` package as e-Invoicing.
class CountryFlagIcon extends StatelessWidget {
  const CountryFlagIcon({
    super.key,
    required this.countryCode,
    this.width = 28,
    this.height = 20,
    this.borderRadius = 4,
  });

  final String? countryCode;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final code = countryCode?.trim().toUpperCase();
    if (code == null || code.length < 2) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(
          Icons.flag_outlined,
          size: height * 0.85,
          color: Colors.grey.shade500,
        ),
      );
    }

    final theme = ImageTheme(
      width: width,
      height: height,
      shape: RoundedRectangle(borderRadius),
    );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _flag(code, theme),
      ),
    );
  }

  Widget _flag(String code, ImageTheme theme) {
    // The EU circle of stars is stored as currency EUR, not country EU.
    if (code == 'EU' || code == 'EUR') {
      return CountryFlag.fromCurrencyCode('EUR', theme: theme);
    }
    return CountryFlag.fromCountryCode(code, theme: theme);
  }
}
