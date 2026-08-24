import 'package:flutter/material.dart';

/// Full-screen boot image, desktop or mobile depending on window size —
/// same layout rule as EastmarkHK e-Invoicing's SplashBackground.
class SplashBackground extends StatelessWidget {
  const SplashBackground({super.key});

  static const _brandGreen = Color(0xFF0B6E4F);

  static bool isWideLayout(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= 600 && size.width >= 700;
  }

  static String assetFor(BuildContext context) => isWideLayout(context)
      ? 'assets/splash_desktop.png'
      : 'assets/splash_mobile.png';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _brandGreen,
      child: Image.asset(
        assetFor(context),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: _brandGreen),
      ),
    );
  }
}
