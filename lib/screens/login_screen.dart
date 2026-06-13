import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clientNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegistering = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  void _showConfigWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Supabase Credentials Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The application is ready to connect to Supabase, but the project credentials are not configured.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Please open:\nlib/services/supabase_config.dart\nand set your Supabase URL and Anon Key.',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            SizedBox(height: 12),
            Text(
              'In the meantime, you can log in as an offline guest using the "Touch ID Bypass" button below.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submit(TaskProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    if (!provider.isSupabaseConfigured) {
      _showConfigWarningDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final clientName = _clientNameController.text.trim();

    try {
      if (_isRegistering) {
        await provider.signUpWithSupabase(email, password, clientName: clientName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registration successful! Check your email or sign in.'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isRegistering = false;
          });
        }
      } else {
        await provider.signInWithSupabase(email, password, clientName: clientName);
        if (mounted && provider.isLoggedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${provider.clientName}!'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.split('Exception:').last.trim();
        }
        if (errorMsg.contains('AuthException')) {
          errorMsg = errorMsg.replaceAll(RegExp(r'AuthException \d+: '), '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $errorMsg'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Circles for Glow Effect (Premium Design)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary).withOpacity(0.12),
              ),
            ),
          ),
          
          // Login Form Body
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: size.width > 450 ? 420 : double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: AppTheme.glassDecoration(
                  isDark: isDark,
                  opacity: 0.75,
                  radius: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo & App Name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.spa, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FocusFlow',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8,
                                    ),
                              ),
                              Text(
                                'Simulate Workspace Sync',
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      
                      // Heading Text
                      Text(
                        _isRegistering ? 'Create Account' : 'Sign In',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegistering 
                            ? 'Start organizing tasks and reminders across your devices.'
                            : 'Enter credentials to load synced tasks.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (!provider.isSupabaseConfigured) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Supabase not configured. Tap Touch ID Bypass below for offline mode.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.amber[200] : Colors.amber[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Client Name input
                      const Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _clientNameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Acme Corp',
                          prefixIcon: Icon(Icons.business_outlined, size: 18),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Client Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Email input
                      const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'name@workspace.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password input
                      const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submit(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _isRegistering ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle register/login link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegistering = !_isRegistering;
                            });
                          },
                          child: Text(
                            _isRegistering
                                ? 'Already have an account? Sign In'
                                : "Don't have an account? Sign Up",
                            style: TextStyle(
                              color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 24),

                      // Bypass Mode / Offline mode button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Or log in via:',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.fingerprint, size: 16),
                            label: const Text('Touch ID Bypass', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final clientName = _clientNameController.text.trim();
                              provider.login('GuestUser', clientName: clientName.isNotEmpty ? clientName : 'Guest Client');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '* Note: Guest/Bypass tasks are saved temporarily. To sync across devices and prevent data loss, please Sign Up with an email account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
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
