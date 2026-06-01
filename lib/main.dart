import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/keygen_provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';

const _kClientUrlKey = 'client_url';
const _kServerUrlKey = 'server_url';
const _kDefaultClientUrl = 'http://localhost:8080';
const _kDefaultServerUrl = 'https://mpcoven.net/api';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Load persisted URLs before first build so the configured client (e.g.
  // :8081 for participant B) survives restarts.
  String clientUrl = _kDefaultClientUrl;
  String serverUrl = _kDefaultServerUrl;
  try {
    final prefs = await SharedPreferences.getInstance();
    clientUrl = prefs.getString(_kClientUrlKey) ?? _kDefaultClientUrl;
    serverUrl = prefs.getString(_kServerUrlKey) ?? _kDefaultServerUrl;
  } catch (_) {}
  runApp(MPCKeygenApp(initialClientUrl: clientUrl, initialServerUrl: serverUrl));
}

class MPCKeygenApp extends StatefulWidget {
  final String initialClientUrl;
  final String initialServerUrl;

  const MPCKeygenApp({
    super.key,
    this.initialClientUrl = _kDefaultClientUrl,
    this.initialServerUrl = _kDefaultServerUrl,
  });

  @override
  State<MPCKeygenApp> createState() => _MPCKeygenAppState();
}

class _MPCKeygenAppState extends State<MPCKeygenApp> {
  late String _clientUrl = widget.initialClientUrl;
  late String _serverUrl = widget.initialServerUrl;
  late ApiService _apiService;
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    _apiService = ApiService(baseUrl: _clientUrl, serverUrl: _serverUrl);
    _provider = AppProvider(apiService: _apiService);
    _provider.restoreSession();
  }

  void _updateUrls(String clientUrl, String serverUrl) {
    setState(() {
      _clientUrl = clientUrl;
      _serverUrl = serverUrl;
      _apiService.dispose();
      _initServices();
    });
    // Persist so the configuration survives app restarts.
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kClientUrlKey, clientUrl);
      prefs.setString(_kServerUrlKey, serverUrl);
    });
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: MaterialApp(
        title: 'mpcoven',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: HomeScreen(
          clientUrl: _clientUrl,
          serverUrl: _serverUrl,
          onUrlsChanged: _updateUrls,
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF627EEA),
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
