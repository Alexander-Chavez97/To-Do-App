import 'package:flutter/material.dart';
import '../services/auth_service.dart'; // <-- 1. IMPORT ADDED

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); // <-- Instantiate the service

  bool _isLogin = true;
  bool _isLoading = false; // <-- 2. LOADING STATE ADDED

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // A helper function to show error pop-ups at the bottom of the screen
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.replaceAll('Exception: ', ''),
        ), // Cleans up the text
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. THE UPDATED BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    // If loading is true, disable the button to prevent double-clicks
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();

                            // Basic validation
                            if (email.isEmpty || password.isEmpty) {
                              _showError("Please fill in all fields.");
                              return;
                            }

                            // Start the loading spinner
                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              if (_isLogin) {
                                await _authService.signInWithEmailPassword(
                                  email,
                                  password,
                                );
                              } else {
                                await _authService.signUpWithEmailPassword(
                                  email,
                                  password,
                                );
                              }
                              // SUCCESS! The StreamBuilder in main.dart will take over from here.
                            } catch (e) {
                              // If Firebase rejects the login, show the error
                              _showError(e.toString());
                            } finally {
                              // Stop the loading spinner (only if the screen is still visible)
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                    // Swap the text for a loading circle if _isLoading is true
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isLogin ? 'Login' : 'Sign Up',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Login",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
