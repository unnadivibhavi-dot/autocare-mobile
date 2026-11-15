import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'customers_screen.dart';
import 'vehicles_screen.dart';
import 'inventory_screen.dart';
import 'animated_dashboard.dart';

// App colours
class AppColors {
  static const gold = Color(0xFFF7B22C);
  static const coffee = Color(0xFF3C312B);
  static const olive = Color(0xFF403E2D);
  static const beige = Color(0xFFD7C3A5);

  static const background = olive;
  static const surface = coffee;
  static const field = Color(0xFF494237);
  static const border = Color(0xFF81735E);
  static const text = Color(0xFFFFEED7);
  static const muted = beige;
}

class RoadColors {
  static const background = AppColors.background;
  static const surface = AppColors.surface;
  static const field = AppColors.field;
  static const border = AppColors.border;
  static const brown = AppColors.gold;
  static const text = AppColors.text;
  static const muted = AppColors.muted;
}

const appSystemStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: AppColors.coffee,
  systemNavigationBarIconBrightness: Brightness.light,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AutoCareApp());
}

class AutoCareApp extends StatelessWidget {
  const AutoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.gold,
          onPrimary: AppColors.coffee,
          secondary: AppColors.beige,
          onSecondary: AppColors.coffee,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          outline: AppColors.border,
          error: const Color(0xFFFFB4A9),
          onError: AppColors.coffee,
        );

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AutoCare',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.background,
        dividerColor: AppColors.border,

        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: appSystemStyle,
          titleTextStyle: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        cardTheme: CardThemeData(
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.border, width: 0.7),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.field,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 19,
          ),
          labelStyle: const TextStyle(color: AppColors.beige),
          hintStyle: const TextStyle(color: AppColors.beige),
          prefixIconColor: AppColors.beige,
          suffixIconColor: AppColors.beige,
          border: fieldBorder(AppColors.border),
          enabledBorder: fieldBorder(AppColors.border),
          focusedBorder: fieldBorder(AppColors.gold, 1.8),
          errorBorder: fieldBorder(scheme.error),
          focusedErrorBorder: fieldBorder(scheme.error, 1.8),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.coffee,
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.coffee,
          elevation: 2,
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.gold,
        ),

        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.gold,
          selectionColor: Color(0x55F7B22C),
          selectionHandleColor: AppColors.gold,
        ),

        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.coffee,
          contentTextStyle: TextStyle(color: AppColors.text),
          behavior: SnackBarBehavior.floating,
        ),

        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.field,
          checkmarkColor: AppColors.gold,
          labelStyle: const TextStyle(color: AppColors.text),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

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

// Screen entrance animation
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
      duration: const Duration(milliseconds: 650),
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
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

// Button press animation
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
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// Animated Login logo
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
      duration: const Duration(seconds: 4),
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
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.coffee,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: const Icon(
              Icons.car_repair_rounded,
              color: AppColors.gold,
              size: 50,
            ),
          ),
          builder: (context, child) {
            final wave = math.sin(_controller.value * 2 * math.pi);

            return Transform.translate(
              offset: Offset(0, wave * 4),
              child: child,
            );
          },
        ),

        const SizedBox(height: 18),

        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Auto',
                style: TextStyle(color: AppColors.text),
              ),
              TextSpan(
                text: 'Care',
                style: TextStyle(color: AppColors.gold),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 37,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'GOOD SERVICE. EVERY MILE.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.beige,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 22),

        ExcludeSemantics(
          child: SizedBox(
            width: 160,
            height: 5,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RoadPainter(_controller.value),
                    size: const Size(160, 5),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoadPainter extends CustomPainter {
  final double progress;

  _RoadPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.gold;

    const spacing = 28.0;

    for (
      double x = -spacing + progress * spacing;
      x < size.width;
      x += spacing
    ) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 1, 18, 3),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Firebase authentication state
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

// Login / Sign Up
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin
                                  ? 'Your workshop, organised.'
                                  : 'Create your AutoCare account.',
                              style: const TextStyle(
                                color: AppColors.beige,
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
                              if (_isLogin) _submit();
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
                                      onFieldSubmitted: (_) => _submit(),
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
                                        color: AppColors.coffee,
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

// Bottom navigation and page transitions
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
      duration: const Duration(milliseconds: 280),
      value: 1,
    );

    _tabOpacity = _tabController.drive(CurveTween(curve: Curves.easeOut));

    // Connect the new animated dashboard.
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

  void _open(Widget screen) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        reverseTransitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));

          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          border: Border(top: BorderSide(color: AppColors.border, width: 0.7)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.coffee,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.gold,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                color: selected ? AppColors.gold : AppColors.beige,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selected,
            onDestinationSelected: _selectTab,
            height: 70,
            animationDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _destination(
                'Home',
                Icons.grid_view_outlined,
                Icons.grid_view_rounded,
              ),
              _destination('Customers', Icons.people_outline, Icons.people),
              _destination(
                'Vehicles',
                Icons.directions_car_outlined,
                Icons.directions_car,
              ),
              _destination(
                'Parts',
                Icons.inventory_2_outlined,
                Icons.inventory_2,
              ),
              _destination('Account', Icons.person_outline, Icons.person),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _destination(
    String label,
    IconData icon,
    IconData selectedIcon,
  ) {
    return NavigationDestination(
      label: label,
      icon: Icon(icon, color: AppColors.beige),
      selectedIcon: Icon(selectedIcon, color: AppColors.coffee),
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
                    backgroundColor: AppColors.coffee,
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.gold,
                      size: 44,
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Your AutoCare account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.beige),
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
