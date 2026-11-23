import 'package:flutter/material.dart';

import 'pages/account_page.dart';
import 'pages/search_page.dart';

class MiniApp extends StatelessWidget {
  const MiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MD3Music3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4C6FFF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4C6FFF),
        brightness: Brightness.dark,
      ),
      home: const MiniShell(),
    );
  }
}

class MiniShell extends StatefulWidget {
  const MiniShell({super.key});

  @override
  State<MiniShell> createState() => _MiniShellState();
}

class _MiniShellState extends State<MiniShell> {
  int _index = 0;
  final _pages = const [SearchPage(), AccountPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }
}
