import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keygen_provider.dart';
import '../widgets/animated_bottom_nav.dart';
import '../widgets/app_background.dart';
import 'accounts_screen.dart';
import 'exchange_screen.dart';
import 'keygen_screen.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String clientUrl;
  final String serverUrl;
  final void Function(String clientUrl, String serverUrl) onUrlsChanged;

  const HomeScreen({
    super.key,
    required this.clientUrl,
    required this.serverUrl,
    required this.onUrlsChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.isRestoring) {
          return const _RestoringScreen();
        }
        if (!provider.isAuthenticated) {
          if (provider.sessionExpired) {
            // Show a one-time notice that the session timed out.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session expired — please sign in again'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              provider.clearSessionExpired();
            });
          }
          return LoginScreen(onSettingsPressed: _openSettings);
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const Positioned.fill(child: AppBackground()),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      AccountsScreen(onSettingsPressed: _openSettings),
                      const KeygenScreen(),
                      const ExchangeScreen(),
                      const PairingScreen(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: AnimatedBottomNav(
            selectedIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: const [
              AnimatedBottomNavItem(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet,
                label: 'Accounts',
              ),
              AnimatedBottomNavItem(
                icon: Icons.key_outlined,
                selectedIcon: Icons.key,
                label: 'Keygen',
              ),
              AnimatedBottomNavItem(
                icon: Icons.swap_horiz_outlined,
                selectedIcon: Icons.swap_horiz,
                label: 'Exchange',
              ),
              AnimatedBottomNavItem(
                icon: Icons.people_outline,
                selectedIcon: Icons.people,
                label: 'Pairing',
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          clientUrl: widget.clientUrl,
          serverUrl: widget.serverUrl,
          onUrlsChanged: widget.onUrlsChanged,
        ),
      ),
    );
  }
}

/// Shown while the persisted JWT session is being verified at app start.
/// Prevents the brief flash of LoginScreen for authenticated users.
class _RestoringScreen extends StatelessWidget {
  const _RestoringScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF627EEA), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF627EEA).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
