import 'package:flutter/material.dart';

import 'data/secure_api_config_store.dart';
import 'features/home_page.dart';
import 'features/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiangSiMaJingApp());
}

class LiangSiMaJingApp extends StatefulWidget {
  const LiangSiMaJingApp({super.key});

  @override
  State<LiangSiMaJingApp> createState() => _LiangSiMaJingAppState();
}

class _LiangSiMaJingAppState extends State<LiangSiMaJingApp> {
  final SecureApiConfigStore _store = SecureApiConfigStore();
  ApiConfig? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _store.read();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '两司马决策镜',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF725A3A)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD2B48C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _config == null
              ? SettingsPage(
                  store: _store,
                  firstRun: true,
                  onSaved: (config) => setState(() => _config = config),
                )
              : HomePage(
                  config: _config!,
                  store: _store,
                  onConfigChanged: (config) => setState(() => _config = config),
                ),
    );
  }
}
