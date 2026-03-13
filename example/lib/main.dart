import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/app_logger.dart';

void main() {
  AppLogger.runWithLogger(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'device_topology_view Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const App(),
    );
  }
}
