import 'package:flutter/material.dart';

import 'src/controller_model.dart';
import 'src/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final model = ControllerModel()..init();
  runApp(ControllerApp(model: model));
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key, required this.model});

  final ControllerModel model;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MockLoc Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFFD32F2F)),
        darkTheme: ThemeData(colorSchemeSeed: const Color(0xFFD32F2F), brightness: Brightness.dark),
        home: HomePage(model: model),
      );
}
