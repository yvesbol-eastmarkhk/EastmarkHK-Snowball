import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'l10n/l10n_controller.dart';
import 'screens/home_screen.dart';
import 'widgets/splash_background.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the OS launch screen (iOS/Android) up until the first Flutter
  // splash frame is painted, then we take over with the real artwork.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const SnowballApp());
}

class SnowballApp extends StatefulWidget {
  const SnowballApp({super.key});

  @override
  State<SnowballApp> createState() => _SnowballAppState();
}

class _SnowballAppState extends State<SnowballApp> {
  late final L10nController _l10n = L10nController();
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B6E4F); // EastmarkHK green

    return MaterialApp(
      title: 'EastmarkHK Snowball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: _splashDone
          ? AnimatedBuilder(
              animation: _l10n,
              builder: (context, child) => HomeScreen(l10n: _l10n),
            )
          : _BootSplash(
              l10n: _l10n,
              onFinished: () => setState(() => _splashDone = true),
            ),
    );
  }
}

/// Full-screen desktop/mobile splash, held for 3 seconds after it is
/// actually painted (same timing as EastmarkHK e-Invoicing).
class _BootSplash extends StatefulWidget {
  const _BootSplash({required this.l10n, required this.onFinished});

  final L10nController l10n;
  final VoidCallback onFinished;

  @override
  State<_BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<_BootSplash> {
  static const _visibleFor = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // Start the 3s clock only after this splash is on screen — not from
    // engine startup, which made the artwork disappear almost immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _holdThenFinish());
  }

  Future<void> _holdThenFinish() async {
    if (!mounted) return;
    FlutterNativeSplash.remove();

    try {
      await precacheImage(
        AssetImage(SplashBackground.assetFor(context)),
        context,
      );
    } catch (_) {
      // Still hold 3 seconds on the brand-green fallback.
    }
    if (!mounted) return;

    await Future.wait([
      widget.l10n.init(),
      Future<void>.delayed(_visibleFor),
    ]);
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B6E4F),
      body: SplashBackground(),
    );
  }
}
