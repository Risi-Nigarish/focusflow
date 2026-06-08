import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/task_provider.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/supabase_config.dart';
import 'widgets/notification_banner.dart';
import 'screens/dashboard_screen.dart';
import 'screens/task_list_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TaskProvider()..init(),
      child: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'FocusFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getThemeData(false),
            darkTheme: AppTheme.getThemeData(true),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: provider.isLoggedIn ? const MainNavigationShell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  StreamSubscription<NotificationPayload>? _notificationSubscription;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TaskListScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Register global listener for in-app reminders
    _notificationSubscription = NotificationService().notificationsStream.listen((payload) {
      if (mounted) {
        final provider = Provider.of<TaskProvider>(context, listen: false);
        // Show visual slide-down overlay banner
        NotificationBanner.show(context, payload, provider.isDarkMode);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<TaskProvider>(context, listen: false);
      provider.cleanupCompletedTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;

    if (provider.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing FocusFlow...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Determine layout based on device screen width (Responsive Shell)
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                // Desktop left sidebar navigation
                _buildSidebar(isDark, provider),
                const VerticalDivider(width: 1),
                // Main content pane
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            )
          : SafeArea(
              child: IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
            ),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark 
                        ? AppTheme.darkBorder.withOpacity(0.5) 
                        : AppTheme.lightBorder.withOpacity(0.5),
                    width: 0.8,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                selectedItemColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                unselectedItemColor: Colors.grey,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontSize: 10),
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined),
                    activeIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.playlist_add_check_outlined),
                    activeIcon: Icon(Icons.playlist_add_check),
                    label: 'Tasks',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today_outlined),
                    activeIcon: Icon(Icons.calendar_today),
                    label: 'Calendar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
    );
  }

  // Sidebar widget for Desktop, Windows, Mac, Linux and Web viewports
  Widget _buildSidebar(bool isDark, TaskProvider provider) {
    return Container(
      width: 250,
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Brand Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.spa,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FocusFlow',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    Text(
                      provider.clientName ?? 'Default Client',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Navigation items list
          Expanded(
            child: ListView(
              children: [
                _buildSidebarItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSidebarItem(
                  index: 1,
                  icon: Icons.playlist_add_check_outlined,
                  activeIcon: Icons.playlist_add_check,
                  label: 'Workspace Tasks',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSidebarItem(
                  index: 2,
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today,
                  label: 'Visual Planner',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSidebarItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'App Settings',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Theme and profile section at the bottom
          const Divider(),
          const SizedBox(height: 8),
          
          // Theme Toggle Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Switch(
                value: isDark,
                onChanged: (_) => provider.toggleTheme(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // User Profile Row with Avatar & Logout Button
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                child: Text(
                  (provider.clientName ?? 'G')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.clientName ?? 'Default Client',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'User: ${provider.username ?? 'Guest'}',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                onPressed: () {
                  provider.logout();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out of workspace session.')),
                  );
                },
                tooltip: 'Log Out',
                splashRadius: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    final activeColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.white60 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
