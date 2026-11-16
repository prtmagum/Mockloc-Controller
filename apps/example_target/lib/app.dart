import 'package:flutter/material.dart';

import 'home_page.dart';

/// Package name dasar; dipakai sebagai User-Agent tile OpenStreetMap.
const appPackageName = 'id.replay.sample_target';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.flavor});

  final String flavor;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sample Target',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
        home: HomePage(flavor: flavor),
      );
}
