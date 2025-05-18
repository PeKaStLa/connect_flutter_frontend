import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../map/views/map_page.dart'; // Single import for MapPage
import '../../map/viewmodels/map_viewmodel.dart'; // Import MapViewModel

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'testuser@example.com'); // Pre-fill for testing
  final _passwordController = TextEditingController(text: '12345678'); // Pre-fill for testing
  bool _isLoading = false;
  // String? _errorMessage; // This was in the original file you provided, but not in the diff version. Keeping it commented.

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  Future<void> _login() async {
    // Ensure focus is removed from text fields to hide keyboard
    _emailFocusNode.unfocus();
    _passwordFocusNode.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Get the PocketBaseService instance
      final pocketBaseService = Provider.of<PocketBaseService>(context, listen: false);

      // Perform actual authentication using the new login method from PocketBaseService
      bool loggedIn = await pocketBaseService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (loggedIn) {
        pocketBaseService.logger.i('Login successful via LoginPage for user: ${_emailController.text.trim()}');
        if (mounted) {
          // Get the ViewModel *before* navigation, using LoginPage's valid context
          final mapViewModel = Provider.of<MapViewModel>(context, listen: false);

          // Navigate to the main MapPage
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MapPage(isBackgroundMode: false)),
          );
          // After navigation, tell the MapViewModel to refresh its data now that we are logged in.
          // Adding a small delay to ensure the new page is settled before triggering refresh.
          // Now call refreshData on the obtained mapViewModel instance.
          // This avoids using LoginPage's context after it might have been disposed.
          Future.delayed(const Duration(milliseconds: 100), mapViewModel.refreshData);
        }
      } else {
        // Handle login failure (e.g., invalid credentials)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Failed: Invalid credentials or server error.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      // Handle other errors (e.g., network issues)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Layer 1: MapPage in background mode
          const MapPage(isBackgroundMode: true),
          
          // Layer 2: Login Form UI
          Center(
            child: SingleChildScrollView( // Good for small screens
              padding: const EdgeInsets.all(24.0), // Increased padding
              child: Card(
                elevation: 8.0, // Increased elevation for better pop
                color: Theme.of(context).cardColor.withValues(alpha: 0.95), // Slightly transparent card
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'ConnectApp Login', // App name or welcome message
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 28.0),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your email';
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            // Move focus to password field when "Next" is pressed
                            FocusScope.of(context).requestFocus(_passwordFocusNode);
                          },
                        ),
                        const SizedBox(height: 18.0),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                          obscureText: true,
                          textInputAction: TextInputAction.done, // Or TextInputAction.go
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password cannot be empty';
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            // Attempt login when "Done" or "Go" is pressed
                            if (!_isLoading) {
                              _login();
                            }
                          },
                        ),
                        const SizedBox(height: 28.0),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  textStyle: Theme.of(context).textTheme.titleMedium,
                                ),
                                onPressed: _isLoading ? null : _login, // Disable button when loading
                                child: const Text('Login'),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
