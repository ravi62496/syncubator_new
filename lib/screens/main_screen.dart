import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/bottom_navbar.dart';
import 'home_screen.dart';
import 'monitoring_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    _pageController = PageController(initialPage: navProvider.currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NavigationProvider>(
        builder: (context, navProvider, child) {
          if (_pageController.hasClients) {
            final currentPage = _pageController.page?.round();
            if (currentPage != navProvider.currentIndex) {
              _pageController.animateToPage(
                navProvider.currentIndex,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutQuart,
              );
            }
          }

          return PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (navProvider.currentIndex != index) {
                navProvider.changePage(index);
              }
            },
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              HomeScreen(),
              MonitoringScreen(),
              SettingsScreen(),
            ],
          );
        },
      ),
      bottomNavigationBar: const BottomNavbar(),
    );
  }
}
