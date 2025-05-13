import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../map/views/map_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final pocketBaseService = Provider.of<PocketBaseService>(context, listen: false);

        // Use PocketBaseService to authenticate
        bool loggedIn = await pocketBaseService.login(_emailController.text, _passwordController.text);

        if (loggedIn) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MapPage()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Login failed. Please check your credentials.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'An error occurred: ${e.toString()}';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (value) { if (value == null || value.isEmpty) { return 'Please enter your email'; } if (!value.contains('@')) { return 'Please enter a valid email'; } return null; }),
              const SizedBox(height: 16),
              TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true, validator: (value) { if (value == null || value.isEmpty) { return 'Please enter your password'; } return null; }),
              const SizedBox(height: 24),
              if (_isLoading) const CircularProgressIndicator() else ElevatedButton(onPressed: _login, child: const Text('Login')),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 16.0), child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        ),
      ),
    );
  }
}