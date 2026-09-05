import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/bowl_project.dart';
import 'state/local_store.dart';
import 'state/project_controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the autosaved design if one exists, otherwise start from the sample.
  BowlProject initial = BowlProject.sample();
  final saved = await LocalStore.read();
  if (saved != null && saved.isNotEmpty) {
    try {
      initial = BowlProject.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt autosave — fall back to the sample.
    }
  }

  runApp(
    ProviderScope(
      overrides: [initialProjectProvider.overrideWithValue(initial)],
      child: const BowlDesignerApp(),
    ),
  );
}
