import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/map/viewmodels/map_viewmodel.dart';
// import 'features/map/views/map_page.dart'; // MapPage will be navigated to from LoginPage
import 'core/services/pocketbase_service.dart'; // Import the service
import 'features/auth/views/login_page.dart'; // Import the LoginPage

void main() {
  // You can provide the PocketBaseService here if you want a single instance
  // throughout the app, or let MapViewModel create its own.
  // For this example, MapViewModel creates its own, but providing it is often better.
  final pocketBaseService = PocketBaseService(); // Create a single instance

  runApp(
    MultiProvider( // Use MultiProvider to provide multiple services/viewmodels
      providers: [
        Provider<PocketBaseService>.value(value: pocketBaseService), // Provide PocketBaseService instance
        ChangeNotifierProvider(
          create: (context) => MapViewModel(pocketBaseService: pocketBaseService), // MapViewModel can still get it via constructor
        ),
      ],
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
      home: const LoginPage(), // LoginPage is now the initial view
    );
  }
}
