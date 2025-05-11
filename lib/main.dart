import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/map/viewmodels/map_viewmodel.dart';
import 'features/map/views/map_page.dart';
import 'core/services/pocketbase_service.dart'; // Import the service

void main() {
  // You can provide the PocketBaseService here if you want a single instance
  // throughout the app, or let MapViewModel create its own.
  // For this example, MapViewModel creates its own, but providing it is often better.
  final pocketBaseService = PocketBaseService();

  runApp(
    ChangeNotifierProvider(
      create: (context) => MapViewModel(pocketBaseService: pocketBaseService),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Map MVVM Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapPage(), // MapPage is now the view
    );
  }
}
