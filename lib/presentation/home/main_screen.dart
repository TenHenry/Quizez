import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'decks_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// Tell the Home and Statistics screens to reload their numbers when the user comes back to them.
  final _homeRefresh = ValueNotifier<int>(0);
  final _statsRefresh = ValueNotifier<int>(0);

  late final List<Widget> _screens = [
    HomeScreen(onOpenCards: () => _selectTab(1), refresh: _homeRefresh),
    const DecksScreen(),
    StatsScreen(refresh: _statsRefresh),
    const SettingsScreen(),
  ];

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _homeRefresh.value++;
    if (index == 2) _statsRefresh.value++;
  }

  @override
  void dispose() {
    _homeRefresh.dispose();
    _statsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade400,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_filled),
            label: 'Cards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}