import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/source_provider.dart';
import 'pages/main_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/login_page.dart';

class NovriidaaApp extends StatelessWidget {
  const NovriidaaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SourceProvider()),
      ],
      child: Consumer2<ThemeProvider, UserProvider>(
        builder: (context, themeProvider, userProvider, child) {
          return MaterialApp(
            title: 'NovReader',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainPage(),
            routes: {
              '/search': (context) => const SearchPage(),
              '/settings': (context) => const SettingsPage(),
              '/login': (context) => const LoginPage(),
            },
          );
        },
      ),
    );
  }
}
