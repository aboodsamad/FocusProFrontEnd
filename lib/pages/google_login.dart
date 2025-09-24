import 'package:flutter/material.dart';
import '../services/signup.dart';

class GoogleLogin extends StatefulWidget {
  const GoogleLogin({super.key});

  @override
  State<GoogleLogin> createState() => _GoogleLoginState();
}

class _GoogleLoginState extends State<GoogleLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPassword = false;
  bool _isLoading = false;
  int _currentStep = 0; // 0: email, 1: password

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailNext() async {
    if (_emailController.text.isNotEmpty && 
        _emailController.text.contains('@')) {
      setState(() {
        _isLoading = true;
      });
      
      
      await Future.delayed(Duration(milliseconds: 800));
      
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

Future<void> _handleSignIn() async {
  setState(() { _isLoading = true; });

  try {
    final result = await ApiService.login(
      _emailController.text, 
      _passwordController.text
    );
    
    // Store token if needed
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.setString('token', result['token']);
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login Successful!'), backgroundColor: Colors.green),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
    );
  } finally {
    setState(() { _isLoading = false; });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Container(
              constraints: BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  padding: EdgeInsets.all(48.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Google Logo
                        Container(
                          height: 35,
                          child: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/2/2f/Google_2015_logo.svg',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFF4285f4),
                                    ),
                                  ),
                                  Text(
                                    'o',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFFea4335),
                                    ),
                                  ),
                                  Text(
                                    'o',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFFfbbc05),
                                    ),
                                  ),
                                  Text(
                                    'g',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFF4285f4),
                                    ),
                                  ),
                                  Text(
                                    'l',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFF34a853),
                                    ),
                                  ),
                                  Text(
                                    'e',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFFea4335),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        SizedBox(height: 27),

                        // Title
                        Text(
                          _currentStep == 0 ? 'Sign in' : 'Welcome',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF202124),
                          ),
                        ),

                        SizedBox(height: 8),

                        // Subtitle
                        Text(
                          _currentStep == 0 
                              ? 'Use your Google Account' 
                              : _emailController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5f6368),
                          ),
                        ),

                        SizedBox(height: 32),

                        // Email/Password Input
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          child: _currentStep == 0
                              ? Column(
                                  key: ValueKey('email'),
                                  children: [
                                    // Email Field
                                    Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF202124),
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Email or phone',
                                          labelStyle: TextStyle(
                                            color: Color(0xFF5f6368),
                                            fontSize: 16,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(
                                              color: Color(0xFFdadce0),
                                              width: 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(
                                              color: Color(0xFF1a73e8),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(
                                              color: Color(0xFFdadce0),
                                              width: 1,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 20,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 16),

                                    // Forgot email link
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          foregroundColor: Color(0xFF1a73e8),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          'Forgot email?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  key: ValueKey('password'),
                                  children: [
                                    // Password Field
                                    Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _passwordController,
                                        obscureText: !_showPassword,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF202124),
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Enter your password',
                                          labelStyle: TextStyle(
                                            color: Color(0xFF5f6368),
                                            fontSize: 16,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showPassword
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: Color(0xFF5f6368),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _showPassword = !_showPassword;
                                              });
                                            },
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(
                                              color: Color(0xFFdadce0),
                                              width: 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(
                                              color: Color(0xFF1a73e8),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: BorderSide(
                                              color: Color(0xFFdadce0),
                                              width: 1,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 20,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 16),

                                    // Forgot password link
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          foregroundColor: Color(0xFF1a73e8),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Create account / Back button
                            TextButton(
                              onPressed: _currentStep == 0
                                  ? () {}
                                  : () {
                                      setState(() {
                                        _currentStep = 0;
                                      });
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF1a73e8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                _currentStep == 0 ? 'Create account' : 'Back',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Next/Sign in button
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_currentStep == 0 ? _handleEmailNext : _handleSignIn),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF1a73e8),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _currentStep == 0 ? 'Next' : 'Sign in',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}