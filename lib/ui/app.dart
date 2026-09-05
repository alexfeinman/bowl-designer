import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_page.dart';
import 'theme.dart';

class BowlDesignerApp extends ConsumerWidget {
  const BowlDesignerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Segmented Bowl Designer',
      debugShowCheckedModeBanner: false,
      theme: buildBowlTheme(Brightness.light),
      darkTheme: buildBowlTheme(Brightness.dark),
      themeMode: mode,
      home: const HomePage(),
    );
  }
}
