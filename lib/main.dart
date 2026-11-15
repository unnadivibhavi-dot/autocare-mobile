import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'customers_screen.dart';
import 'vehicles_screen.dart';
import 'inventory_screen.dart';

// Racing Green + Tangerine + warm Sand
class AppColors {
  static const racingGreen = Color(0xFF0F1B0C);
  static const slateGreen = Color(0xFF222F28);
  static const tangerine = Color(0xFFE05F16);
  static const burntOrange = Color(0xFFA24E03);
  static const sand = Color(0xFFE6B183);

  static const background = Color(0xFFE6B183);
  static const surface = Color(0xFFF0CAA7);
  static const field = Color(0xFFF5D9BE);
  static const softGreen = Color(0xFFD9D2AC);
  static const softOrange = Color(0xFFF1BF93);
  static const border = Color(0xFFAD805C);
  static const muted = Color(0xFF535142);
}

// Compatibility with earlier widgets
class RoadColors {
  static const background = AppColors.background;
  static const surface = AppColors.surface;
  static const field = AppColors.field;
  static const border = AppColors.border;
  static const brown = AppColors.burntOrange;
  static const text = AppColors.racingGreen;
  static const muted = AppColors.muted;
}

const appSystemStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.surface,
  systemNavigationBarIconBrightness: Brightness.dark,
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
          seedColor: AppColors.racingGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.racingGreen,
          onPrimary: AppColors.field,
          secondary: AppColors.burntOrange,
          onSecondary: AppColors.field,
          surface: AppColors.surface,
          onSurface: AppColors.racingGreen,
          outline: AppColors.border,
        );

    OutlineInputBorder border(Color color, [double width = 1]) {
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
        brightness: Brightness.light,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.background,
        dividerColor: AppColors.border,

        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.racingGreen,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: appSystemStyle,
          titleTextStyle: TextStyle(
            color: AppColors.racingGreen,
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
            side: const BorderSide(color: AppColors.border),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.field,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 19,
          ),
          labelStyle: const TextStyle(color: AppColors.muted),
          hintStyle: const TextStyle(color: AppColors.muted),
          prefixIconColor: AppColors.racingGreen,
          suffixIconColor: AppColors.muted,
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.racingGreen, 1.8),
          errorBorder: border(scheme.error),
          focusedErrorBorder: border(scheme.error, 1.8),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.racingGreen,
            foregroundColor: AppColors.field,
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.racingGreen,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.racingGreen),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.racingGreen,
          foregroundColor: AppColors.field,
          elevation: 2,
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.racingGreen,
        ),

        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.racingGreen,
          selectionColor: Color(0x44E6B183),
          selectionHandleColor: AppColors.racingGreen,
        ),

        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.slateGreen,
          contentTextStyle: TextStyle(color: AppColors.field),
          behavior: SnackBarBehavior.floating,
        ),

        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.softGreen,
          checkmarkColor: AppColors.racingGreen,
          labelStyle: const TextStyle(color: AppColors.racingGreen),
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

// Fade and slide entrance
class Entrance extends StatefulWidget {
  final Widget child;

  const Entrance({super.key, required this.child});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final curve = _controller.drive(CurveTween(curve: Curves.easeOutCubic));

    _opacity = curve;
    _position = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);
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
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
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
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && widget.enabled && !reduceMotion ? 0.98 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

// Animated logo
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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.racingGreen,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.car_repair_rounded,
              color: AppColors.sand,
              size: 49,
            ),
          ),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, math.sin(_controller.value * 2 * math.pi) * 3),
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
                style: TextStyle(color: AppColors.racingGreen),
              ),
              TextSpan(
                text: 'Care',
                style: TextStyle(color: AppColors.racingGreen),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'GOOD SERVICE. EVERY MILE.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
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
    final paint = Paint()..color = AppColors.tangerine;
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

// Login state
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

// Login and Sign Up
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
    if (_loading || !_formKey.currentState!.validate()) return;

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
      if (mounted) _message(_authError(error));
    } catch (_) {
      if (mounted) _message('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                              _isLogin ? 'Welcome back.' : 'Your next chapter.',
                              style: const TextStyle(
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin
                                  ? 'Everything your service centre needs, '
                                        'in one place.'
                                  : 'Create an account to get started '
                                        'with AutoCare.',
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

// Navigation shell
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;
  bool _loggingOut = false;

  final List<Widget?> _pages = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();

    _pages[0] = _Dashboard(onSelectTab: _selectTab, onOpen: _open);
  }

  void _selectTab(int index) {
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
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  void _open(Widget screen) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => screen,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        reverseTransitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));

          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selected,
        children: List.generate(5, (index) {
          final page = index == 4
              ? _accountPage()
              : _pages[index] ?? const SizedBox.shrink();

          return TickerMode(enabled: _selected == index, child: page);
        }),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.racingGreen,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                color: AppColors.racingGreen,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selected,
            onDestinationSelected: _selectTab,
            height: 70,
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
      icon: Icon(icon, color: AppColors.racingGreen),
      selectedIcon: Icon(selectedIcon, color: AppColors.sand),
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
                    backgroundColor: AppColors.racingGreen,
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.sand,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'You’re in the driver’s seat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(_loggingOut ? 'Signing out...' : 'Sign Out'),
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

// Home dashboard
class _Dashboard extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  final ValueChanged<Widget> onOpen;

  const _Dashboard({required this.onSelectTab, required this.onOpen});

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _customers;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vehicles;

  @override
  void initState() {
    super.initState();

    _customers = FirebaseFirestore.instance.collection('customers').snapshots();

    _vehicles = FirebaseFirestore.instance.collection('vehicles').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoCare'),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => widget.onSelectTab(4),
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.racingGreen,
              child: Icon(
                Icons.person_outline,
                color: AppColors.sand,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hero(),
                    const SizedBox(height: 28),
                    _heading('Your workshop', 'Live overview'),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _statCard(
                            stream: _customers,
                            label: 'Customers',
                            icon: Icons.people_outline,
                            onTap: () => widget.onSelectTab(1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            stream: _vehicles,
                            label: 'Vehicles',
                            icon: Icons.directions_car_outlined,
                            onTap: () => widget.onSelectTab(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _heading('Quick actions', 'Start here'),
                    const SizedBox(height: 14),
                    _action(
                      icon: Icons.person_add_alt_1,
                      title: 'Add a customer',
                      subtitle: 'Keep their details close at hand.',
                      onTap: () => widget.onOpen(const AddCustomerScreen()),
                    ),
                    const SizedBox(height: 10),
                    _action(
                      icon: Icons.add_road_rounded,
                      title: 'Register a vehicle',
                      subtitle: 'Connect a vehicle to its owner.',
                      onTap: () => widget.onOpen(const AddVehicleScreen()),
                    ),
                    const SizedBox(height: 10),
                    _action(
                      icon: Icons.inventory_2_outlined,
                      title: 'Manage spare parts',
                      subtitle: 'Check stock and add new parts.',
                      onTap: () => widget.onSelectTab(3),
                    ),
                    const SizedBox(height: 10),
                    _action(
                      icon: Icons.assignment_outlined,
                      title: 'Bookings & Job Cards',
                      subtitle: 'Open a vehicle to manage its service.',
                      onTap: () => widget.onSelectTab(2),
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

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.racingGreen,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.tangerine,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'THE ROAD AHEAD',
                style: TextStyle(
                  color: AppColors.sand,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.car_repair_rounded,
                color: AppColors.sand,
                size: 35,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Good service.\nGreat journeys.',
            style: TextStyle(
              color: AppColors.field,
              fontSize: 31,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'A clear view of your customers, vehicles '
            'and workshop essentials.',
            style: TextStyle(color: AppColors.sand, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => widget.onSelectTab(2),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sand,
              foregroundColor: AppColors.racingGreen,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Open vehicles'),
          ),
        ],
      ),
    );
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _statCard({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressScale(
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.racingGreen,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.sand, size: 22),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Unavailable',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    return Text(
                      '${snapshot.data!.docs.length}',
                      style: const TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return PressScale(
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.racingGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.sand, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.racingGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
