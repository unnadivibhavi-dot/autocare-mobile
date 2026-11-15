import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'app_theme.dart';
import 'animated_dashboard.dart';
import 'customers_screen.dart';
import 'vehicles_screen.dart';
import 'inventory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AutoCareApp());
}

class AutoCareApp extends StatelessWidget {
  const AutoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AutoCare',
      theme: AutoCareTheme.theme,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

// Fade and slide entrance.
class Entrance extends StatefulWidget {
  final Widget child;

  const Entrance({super.key, required this.child});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }

    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

// Button press feedback.
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PressScale({super.key, required this.child, this.enabled = true});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;

    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && widget.enabled && !reduceMotion ? 0.97 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 130),
        child: widget.child,
      ),
    );
  }
}

// Login brand.
class AutoCareBrand extends StatefulWidget {
  const AutoCareBrand({super.key});

  @override
  State<AutoCareBrand> createState() => _AutoCareBrandState();
}

class _AutoCareBrandState extends State<AutoCareBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _controller,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border, width: 0.7),
            ),
            child: const Center(
              child: AutoCareLineIcon(type: AutoCareIconType.service, size: 60),
            ),
          ),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, math.sin(_controller.value * 2 * math.pi) * 3),
              child: child,
            );
          },
        ),

        const SizedBox(height: 20),

        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Auto',
                style: TextStyle(color: AppColors.text),
              ),
              TextSpan(
                text: 'Care',
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'GOOD SERVICE. EVERY MILE.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

// Firebase account state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();

    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to check your account. Restart the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data == null ? const AuthScreen() : const HomeScreen();
      },
    );
  }
}

// Login and Sign Up.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _hidePassword = true;

  String _authError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email.';

      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email or password is incorrect.';

      case 'email-already-in-use':
        return 'This email already has an account. Please sign in.';

      case 'weak-password':
        return 'Please choose a stronger password.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Try again later.';

      case 'network-request-failed':
        return 'Check your internet connection.';

      case 'operation-not-allowed':
        return 'Enable Email/Password in Firebase Authentication.';

      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _message(_authError(error));
      }
    } catch (_) {
      if (mounted) {
        _message('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLogin = !_isLogin;
      _password.clear();
      _confirm.clear();
      _formKey.currentState?.reset();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AutoCareBrand(),

                    const SizedBox(height: 36),

                    AnimatedSwitcher(
                      duration: duration,
                      child: Align(
                        key: ValueKey(_isLogin),
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLogin ? 'Welcome back.' : 'Let’s get started.',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin
                                  ? 'Your workshop, organised.'
                                  : 'Create your AutoCare account.',
                              style: const TextStyle(
                                color: AppColors.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _email,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email)
                                  ? null
                                  : 'Enter a valid email address.';
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _password,
                            enabled: !_loading,
                            obscureText: _hidePassword,
                            textInputAction: _isLogin
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onFieldSubmitted: (_) {
                              if (_isLogin) {
                                _submit();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _hidePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _hidePassword = !_hidePassword;
                                  });
                                },
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password.';
                              }

                              if (!_isLogin && value.length < 6) {
                                return 'Use at least 6 characters.';
                              }

                              return null;
                            },
                          ),

                          AnimatedSize(
                            duration: duration,
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.topCenter,
                            child: _isLogin
                                ? const SizedBox(
                                    width: double.infinity,
                                    height: 0,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: TextFormField(
                                      controller: _confirm,
                                      enabled: !_loading,
                                      obscureText: _hidePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) {
                                        _submit();
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Confirm password',
                                        prefixIcon: Icon(Icons.lock_outline),
                                      ),
                                      validator: (value) {
                                        return value != _password.text
                                            ? 'Passwords do not match.'
                                            : null;
                                      },
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 24),

                          PressScale(
                            enabled: !_loading,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.navigation,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isLogin
                                              ? 'Sign In'
                                              : 'Create Account',
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _loading ? null : _toggleMode,
                      child: Text(
                        _isLogin
                            ? 'New to AutoCare? Create an account'
                            : 'Already have an account? Sign in',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Main navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selected = 0;
  bool _loggingOut = false;

  final List<Widget?> _pages = List<Widget?>.filled(5, null);

  late final AnimationController _tabController;
  late final Animation<double> _tabOpacity;

  @override
  void initState() {
    super.initState();

    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );

    _tabOpacity = _tabController.drive(CurveTween(curve: Curves.easeOut));

    _pages[0] = AnimatedDashboard(onSelectTab: _selectTab, onOpen: _open);
  }

  void _selectTab(int index) {
    if (_selected == index) return;

    setState(() {
      _selected = index;

      if (_pages[index] == null) {
        switch (index) {
          case 1:
            _pages[index] = const CustomersScreen();
            break;

          case 2:
            _pages[index] = const VehiclesScreen();
            break;

          case 3:
            _pages[index] = const InventoryScreen();
            break;
        }
      }
    });

    if (MediaQuery.of(context).disableAnimations) {
      _tabController.value = 1;
    } else {
      _tabController.forward(from: 0);
    }
  }

  void _open(Widget screen) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => screen,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 320),
        reverseTransitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 230),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));

          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  NavigationDestination _destination({
    required String label,
    required AutoCareIconType type,
  }) {
    return NavigationDestination(
      label: label,
      icon: AutoCareLineIcon(type: type, size: 25, color: AppColors.muted),
      selectedIcon: AutoCareLineIcon(
        type: type,
        size: 25,
        color: AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: FadeTransition(
        opacity: _tabOpacity,
        child: IndexedStack(
          index: _selected,
          children: List.generate(5, (index) {
            final page = index == 4
                ? _accountPage()
                : _pages[index] ?? const SizedBox.shrink();

            return TickerMode(enabled: _selected == index, child: page);
          }),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.6)),
        ),
        child: NavigationBar(
          selectedIndex: _selected,
          onDestinationSelected: _selectTab,
          animationDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _destination(label: 'Home', type: AutoCareIconType.home),
            _destination(label: 'Customers', type: AutoCareIconType.people),
            _destination(label: 'Vehicles', type: AutoCareIconType.car),
            _destination(label: 'Parts', type: AutoCareIconType.box),
            _destination(label: 'Account', type: AutoCareIconType.person),
          ],
        ),
      ),
    );
  }

  Widget _accountPage() {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Your account')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.accentSoft,
                    child: AutoCareLineIcon(
                      type: AutoCareIconType.person,
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Your AutoCare account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),

                  const SizedBox(height: 32),

                  PressScale(
                    enabled: !_loggingOut,
                    child: FilledButton.icon(
                      onPressed: _loggingOut ? null : _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(_loggingOut ? 'Signing out...' : 'Sign Out'),
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
