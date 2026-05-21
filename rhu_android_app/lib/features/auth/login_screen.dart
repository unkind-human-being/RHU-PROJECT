import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  DateTime? _lastLoginAttempt;

  bool get _isLocalLoginReady {
    return _isValidEmail(_emailController.text.trim()) &&
        _passwordController.text.trim().length >= 8;
  }

  @override
  void initState() {
    super.initState();

    _emailController.addListener(_refreshUi);
    _passwordController.addListener(_refreshUi);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refreshUi);
    _passwordController.removeListener(_refreshUi);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refreshUi() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isLocalLoginReady) {
      _showError('Please enter a valid email and password first.');
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastAttempt = _lastLoginAttempt;

    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 2)) {
      _showError('Please wait a moment before trying again.');
      return;
    }

    _lastLoginAttempt = now;

    try {
      final AuthProvider authProvider = context.read<AuthProvider>();

      final bool success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${authProvider.userDisplayName}'),
            backgroundColor: const Color(0xFF0EA5E9),
          ),
        );

        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;
      }

      _showError(
        authProvider.errorMessage ?? 'Login failed. Please try again.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to login. Please try again.');
    }
  }

  Future<void> _openRegister() async {
    final bool passedCaptcha = await _showRobotCheckDialog();

    if (!mounted) {
      return;
    }

    if (!passedCaptcha) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamed('/register');
  }

  Future<bool> _showRobotCheckDialog() async {
    bool checked = false;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            void continueToRegister() {
              if (!checked) {
                return;
              }

              Navigator.of(dialogContext).pop(true);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setDialogState(() {
                        checked = !checked;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: checked
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFFE5E7EB),
                          width: checked ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: checked
                                  ? const Color(0xFF0EA5E9)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: checked
                                    ? const Color(0xFF0EA5E9)
                                    : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                            child: checked
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              "I'm not a robot",
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Column(
                            children: <Widget>[
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.verified_user_rounded,
                                  color: Color(0xFF0EA5E9),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Security',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please confirm before creating a public user account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: checked
                        ? const Color(0xFF0EA5E9)
                        : const Color(0xFF94A3B8),
                  ),
                  onPressed: checked ? continueToRegister : null,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  static bool _isValidEmail(String value) {
    return RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 820;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 980 : 480,
                  ),
                  child: isWide
                      ? Row(
                          children: <Widget>[
                            const Expanded(
                              child: _LoginHeroPanel(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _LoginCard(
                                formKey: _formKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                obscurePassword: _obscurePassword,
                                isLocalLoginReady: _isLocalLoginReady,
                                onTogglePassword: _togglePasswordVisibility,
                                onLogin: _handleLogin,
                                onRegister: _openRegister,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: <Widget>[
                            const _LoginHeroPanel(),
                            const SizedBox(height: 20),
                            _LoginCard(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              isLocalLoginReady: _isLocalLoginReady,
                              onTogglePassword: _togglePasswordVisibility,
                              onLogin: _handleLogin,
                              onRegister: _openRegister,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0EA5E9),
            Color(0xFF0284C7),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PortalBadge(),
          SizedBox(height: 28),
          _HeroIcon(),
          SizedBox(height: 20),
          Text(
            'Welcome to RHU Social Health',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Access health updates, appointments, messages, QR tickets, and RHU consultation services in one secure portal.',
            style: TextStyle(
              color: Color(0xFFE0F2FE),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 24),
          _HeroFeature(
            icon: Icons.event_available_rounded,
            text: 'Walk-in and online appointment support',
          ),
          SizedBox(height: 12),
          _HeroFeature(
            icon: Icons.qr_code_2_rounded,
            text: 'QR tickets and prescription notices',
          ),
          SizedBox(height: 12),
          _HeroFeature(
            icon: Icons.chat_bubble_rounded,
            text: 'Secure RHU messages and consultation updates',
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
        ),
      ),
      child: const Icon(
        Icons.health_and_safety_rounded,
        color: Colors.white,
        size: 44,
      ),
    );
  }
}

class _PortalBadge extends StatelessWidget {
  const _PortalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: const Text(
        'TAWI-TAWI RHU PORTAL',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLocalLoginReady,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLocalLoginReady;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (
        BuildContext context,
        AuthProvider authProvider,
        Widget? child,
      ) {
        final bool canSubmit = isLocalLoginReady && !authProvider.isLoading;

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(
              color: Color(0xFFBAE6FD),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Login',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your registered account details to continue.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[
                      AutofillHints.email,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'example@email.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[
                      AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) {
                      if (canSubmit) {
                        onLogin();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: onTogglePassword,
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  if (authProvider.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _InlineErrorMessage(
                      message: authProvider.errorMessage!,
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: canSubmit
                          ? const Color(0xFF0EA5E9)
                          : const Color(0xFF94A3B8),
                    ),
                    onPressed: canSubmit ? onLogin : null,
                    icon: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      authProvider.isLoading ? 'Logging in...' : 'Login',
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: authProvider.isLoading ? null : onRegister,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Create Public User Account'),
                  ),
                  const SizedBox(height: 18),
                  const _SecurityNote(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String? _validateEmail(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Email is required.';
    }

    final bool isValidEmail = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(text);

    if (!isValidEmail) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  static String? _validatePassword(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Password is required.';
    }

    if (text.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    return null;
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.security_rounded,
            color: Color(0xFF0EA5E9),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'For security, login will only continue after the email and password format are valid.',
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}