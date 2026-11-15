import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_theme.dart';
import 'customers_screen.dart';
import 'vehicles_screen.dart';
import 'billing_dashboard_screen.dart';

// Reusable outline icons for the dashboard and navigation.
enum AutoCareIconType { service, car, people, addPerson, box, home, person }

class AutoCareLineIcon extends StatelessWidget {
  final AutoCareIconType type;
  final double size;
  final Color color;

  const AutoCareLineIcon({
    super.key,
    required this.type,
    this.size = 28,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AutoCareIconPainter(type: type, color: color),
        ),
      ),
    );
  }
}

class _AutoCareIconPainter extends CustomPainter {
  final AutoCareIconType type;
  final Color color;

  _AutoCareIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 64;

    canvas.save();

    canvas.translate(
      (size.width - 64 * scale) / 2,
      (size.height - 64 * scale) / 2,
    );

    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case AutoCareIconType.car:
        _car(canvas, paint);
        break;

      case AutoCareIconType.people:
        _people(canvas, paint);
        break;

      case AutoCareIconType.addPerson:
        _addPerson(canvas, paint);
        break;

      case AutoCareIconType.box:
        _box(canvas, paint);
        break;

      case AutoCareIconType.home:
        _home(canvas, paint);
        break;

      case AutoCareIconType.person:
        _person(canvas, paint);
        break;

      case AutoCareIconType.service:
        _service(canvas, paint);
        break;
    }

    canvas.restore();
  }

  void _car(Canvas canvas, Paint paint) {
    final roof = Path()
      ..moveTo(16, 29)
      ..cubicTo(20, 15, 22, 13, 32, 13)
      ..cubicTo(42, 13, 44, 15, 48, 29);

    canvas.drawPath(roof, paint);

    final body = Path()
      ..moveTo(14, 29)
      ..cubicTo(10, 30, 8, 34, 8, 40)
      ..lineTo(8, 50)
      ..quadraticBezierTo(8, 54, 12, 54)
      ..lineTo(16, 54)
      ..quadraticBezierTo(19, 54, 19, 49)
      ..lineTo(45, 49)
      ..quadraticBezierTo(45, 54, 48, 54)
      ..lineTo(52, 54)
      ..quadraticBezierTo(56, 54, 56, 50)
      ..lineTo(56, 40)
      ..cubicTo(56, 34, 54, 30, 50, 29)
      ..close();

    canvas.drawPath(body, paint);

    final windshield = Path()
      ..moveTo(16, 29)
      ..quadraticBezierTo(32, 32, 48, 29);

    canvas.drawPath(windshield, paint);

    canvas.drawLine(const Offset(12, 38), const Offset(21, 40), paint);

    canvas.drawLine(const Offset(43, 40), const Offset(52, 38), paint);

    canvas.drawLine(const Offset(27, 44), const Offset(37, 44), paint);

    canvas.drawLine(const Offset(10, 28), const Offset(5, 26), paint);

    canvas.drawLine(const Offset(54, 28), const Offset(59, 26), paint);
  }

  void _people(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(24, 20), 8, paint);

    final first = Path()
      ..moveTo(9, 51)
      ..lineTo(10, 45)
      ..cubicTo(12, 32, 36, 32, 38, 45)
      ..lineTo(39, 51);

    canvas.drawPath(first, paint);

    final secondHead = Path()
      ..moveTo(40, 13)
      ..cubicTo(51, 10, 55, 28, 43, 29);

    canvas.drawPath(secondHead, paint);

    final secondBody = Path()
      ..moveTo(43, 36)
      ..cubicTo(53, 35, 58, 41, 58, 51);

    canvas.drawPath(secondBody, paint);
  }

  void _person(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(32, 20), 9, paint);

    final body = Path()
      ..moveTo(14, 53)
      ..lineTo(15, 46)
      ..cubicTo(17, 31, 47, 31, 49, 46)
      ..lineTo(50, 53)
      ..close();

    canvas.drawPath(body, paint);
  }

  void _addPerson(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(24, 20), 8, paint);

    final body = Path()
      ..moveTo(9, 52)
      ..lineTo(10, 45)
      ..cubicTo(12, 32, 35, 32, 38, 43);

    canvas.drawPath(body, paint);

    canvas.drawLine(const Offset(48, 35), const Offset(48, 53), paint);

    canvas.drawLine(const Offset(39, 44), const Offset(57, 44), paint);
  }

  void _box(Canvas canvas, Paint paint) {
    final outline = Path()
      ..moveTo(32, 9)
      ..lineTo(53, 21)
      ..lineTo(53, 44)
      ..lineTo(32, 56)
      ..lineTo(11, 44)
      ..lineTo(11, 21)
      ..close();

    canvas.drawPath(outline, paint);

    final inside = Path()
      ..moveTo(11, 21)
      ..lineTo(32, 33)
      ..lineTo(53, 21)
      ..moveTo(32, 33)
      ..lineTo(32, 56)
      ..moveTo(22, 15)
      ..lineTo(43, 27);

    canvas.drawPath(inside, paint);
  }

  void _home(Canvas canvas, Paint paint) {
    final home = Path()
      ..moveTo(8, 29)
      ..lineTo(32, 9)
      ..lineTo(56, 29)
      ..moveTo(14, 25)
      ..lineTo(14, 54)
      ..lineTo(27, 54)
      ..lineTo(27, 38)
      ..lineTo(37, 38)
      ..lineTo(37, 54)
      ..lineTo(50, 54)
      ..lineTo(50, 25);

    canvas.drawPath(home, paint);
  }

  void _service(Canvas canvas, Paint paint) {
    canvas.save();
    canvas.translate(-1, -4);
    canvas.scale(0.85);
    _car(canvas, paint);
    canvas.restore();

    canvas.save();
    canvas.translate(47, 43);
    canvas.rotate(0.65);

    final tool = Path()
      ..moveTo(-5, -8)
      ..cubicTo(-9, -3, -7, 3, -3, 5)
      ..lineTo(-3, 15)
      ..quadraticBezierTo(0, 18, 3, 15)
      ..lineTo(3, 5)
      ..cubicTo(8, 2, 8, -4, 4, -8)
      ..lineTo(4, -2)
      ..lineTo(0, 1)
      ..lineTo(-4, -2)
      ..close();

    canvas.drawPath(tool, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AutoCareIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

// Reference-style dashboard.
class AnimatedDashboard extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  final ValueChanged<Widget> onOpen;

  const AnimatedDashboard({
    super.key,
    required this.onSelectTab,
    required this.onOpen,
  });

  @override
  State<AnimatedDashboard> createState() => _AnimatedDashboardState();
}

class _AnimatedDashboardState extends State<AnimatedDashboard>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _float;

  late final List<Animation<double>> _sections;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _customers;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vehicles;

  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _sections = List.generate(8, (index) {
      final start = index * 0.065;
      final end = math.min(start + 0.45, 1.0);

      return _entrance.drive(
        CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    _customers = FirebaseFirestore.instance.collection('customers').snapshots();

    _vehicles = FirebaseFirestore.instance.collection('vehicles').snapshots();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reduceMotion = MediaQuery.of(context).disableAnimations;

    if (_reduceMotion) {
      _entrance.value = 1;
      _float.stop();
      _float.value = 0;
    } else {
      if (!_started) {
        _entrance.forward();
      }

      if (!_float.isAnimating) {
        _float.repeat();
      }
    }

    _started = true;
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    final animation = _sections[index];

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AutoCareLineIcon(type: AutoCareIconType.service, size: 34),
            SizedBox(width: 10),
            Text(
              'AutoCare',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => widget.onSelectTab(4),
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accentSoft,
              child: Icon(Icons.person, color: AppColors.accent, size: 21),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reveal(0, _hero()),

                  const SizedBox(height: 24),

                  _reveal(1, _sectionTitle('Your workshop')),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _reveal(
                          2,
                          _statCard(
                            stream: _customers,
                            label: 'Customers',
                            icon: AutoCareIconType.people,
                            onTap: () => widget.onSelectTab(1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _reveal(
                          3,
                          _statCard(
                            stream: _vehicles,
                            label: 'Vehicles',
                            icon: AutoCareIconType.car,
                            onTap: () => widget.onSelectTab(2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  _reveal(4, _sectionTitle('Quick actions')),

                  const SizedBox(height: 14),

                  _reveal(
                    4,
                    _action(
                      title: 'Add a customer',
                      icon: const AutoCareLineIcon(
                        type: AutoCareIconType.addPerson,
                        size: 31,
                      ),
                      onTap: () => widget.onOpen(const AddCustomerScreen()),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _reveal(
                    5,
                    _action(
                      title: 'Register a vehicle',
                      icon: const AutoCareLineIcon(
                        type: AutoCareIconType.car,
                        size: 31,
                      ),
                      onTap: () => widget.onOpen(const AddVehicleScreen()),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _reveal(
                    6,
                    _action(
                      title: 'Manage spare parts',
                      icon: const AutoCareLineIcon(
                        type: AutoCareIconType.box,
                        size: 31,
                      ),
                      onTap: () => widget.onSelectTab(3),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _reveal(
                    7,
                    _action(
                      title: 'Bookings & Job Cards',
                      icon: const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.accent,
                        size: 27,
                      ),
                      onTap: () => widget.onSelectTab(2),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _reveal(
                    7,
                    _action(
                      title: 'Billing & payments',
                      icon: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.accent,
                        size: 27,
                      ),
                      onTap: () =>
                          widget.onOpen(const BillingDashboardScreen()),
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentSoft, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'YOUR WORKSHOP',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),

          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 320;

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Every vehicle.\nEvery detail.',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: compact ? 26 : 31,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _float,
                    child: AutoCareLineIcon(
                      type: AutoCareIconType.car,
                      size: compact ? 78 : 100,
                    ),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          math.sin(_float.value * 2 * math.pi) * 2.5,
                        ),
                        child: child,
                      );
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          const Text(
            'Keep your service centre organised.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerLeft,
            child: _TouchPopCard(
              onTap: () => widget.onSelectTab(2),
              backgroundColor: AppColors.accent,
              borderRadius: 14,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Open vehicles',
                  style: TextStyle(
                    color: AppColors.navigation,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String label,
    required AutoCareIconType icon,
    required VoidCallback onTap,
  }) {
    return _TouchPopCard(
      onTap: onTap,
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        child: Row(
          children: [
            AutoCareLineIcon(type: icon, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          '—',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 25,
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 30,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final count = snapshot.data!.docs.length;

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: count.toDouble()),
                        duration: _reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            '${value.round()}',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 5),

                  Text(
                    label,
                    style: const TextStyle(color: AppColors.text, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required String title,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return _TouchPopCard(
      onTap: onTap,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

// Touch pop animation before navigation.
class _TouchPopCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final Color backgroundColor;

  const _TouchPopCard({
    required this.child,
    required this.onTap,
    this.borderRadius = 20,
    this.backgroundColor = AppColors.surface,
  });

  @override
  State<_TouchPopCard> createState() => _TouchPopCardState();
}

class _TouchPopCardState extends State<_TouchPopCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  bool _busy = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scale = _controller.drive(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1,
            end: 1.035,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 45,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.035,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 55,
        ),
      ]),
    );
  }

  Future<void> _activate() async {
    if (_busy) return;

    if (MediaQuery.of(context).disableAnimations) {
      widget.onTap();
      return;
    }

    setState(() => _busy = true);

    try {
      await _controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }

    if (!mounted) return;

    setState(() => _busy = false);
    widget.onTap();
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;

    setState(() => _hovered = value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final active = _busy || _hovered;

    final isAccent = widget.backgroundColor == AppColors.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        scale: _hovered && !_busy && !reduceMotion ? 1.012 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 150),
        child: ScaleTransition(
          scale: _scale,
          child: Material(
            color: widget.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              side: BorderSide(
                color: active || isAccent ? AppColors.accent : AppColors.border,
                width: active ? 1.1 : 0.7,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _activate,
              splashColor: isAccent
                  ? const Color(0x221B242E)
                  : const Color(0x33A8C4D9),
              highlightColor: Colors.transparent,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
