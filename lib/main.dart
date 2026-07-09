import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/navigation_provider.dart';
import 'providers/weight_provider.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/raspberry_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_colors.dart';
import 'widgets/bottom_navbar.dart';

void main() {
  runApp(const SyncubatorApp());
}

class SyncubatorApp extends StatelessWidget {
  const SyncubatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => WeightProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Syncubator',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);

    final pages = [
      const HomeScreen(),
      const HistoryScreen(),
      const RaspberryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[navigationProvider.currentIndex],
      bottomNavigationBar: const BottomNavbar(),
    );
  }
}