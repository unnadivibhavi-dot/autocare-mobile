import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'customers_screen.dart';
import 'vehicles_screen.dart';
import 'billing_dashboard_screen.dart';

class _DashboardColors {
  static const gold = Color(0xFFF7B22C);
  static const coffee = Color(0xFF3C312B);
  static const olive = Color(0xFF403E2D);
  static const beige = Color(0xFFD7C3A5);

  static const border = Color(0xFF81735E);
  static const text = Color(0xFFFFEED7);
}

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
  late final AnimationController _road;

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
      duration: const Duration(milliseconds: 1500),
    );

    _road = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _sections = List.generate(9, (index) {
      final start = index * 0.065;
      final end = math.min(start + 0.42, 1.0);

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
      _road.stop();
      _road.value = 0.5;
    } else {
      if (!_started) {
        _entrance.forward();
      }

      if (!_road.isAnimating) {
        _road.repeat();
      }
    }

    _started = true;
  }

  void _replay() {
    if (_reduceMotion) return;

    _entrance.forward(from: 0);
    _road.repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _road.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    final animation = _sections[index];

    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Auto',
                style: TextStyle(color: _DashboardColors.text),
              ),
              TextSpan(
                text: 'Care',
                style: TextStyle(color: _DashboardColors.gold),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Replay animations',
            onPressed: _reduceMotion ? null : _replay,
            icon: const Icon(
              Icons.replay_rounded,
              color: _DashboardColors.beige,
            ),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () => widget.onSelectTab(4),
            icon: const CircleAvatar(
              radius: 17,
              backgroundColor: _DashboardColors.coffee,
              child: Icon(
                Icons.person_outline,
                color: _DashboardColors.gold,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reveal(0, _hero()),

                  const SizedBox(height: 26),

                  _reveal(1, _heading('Your workshop', 'Live overview')),

                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _reveal(
                          2,
                          _statCard(
                            stream: _customers,
                            label: 'Customers',
                            icon: Icons.people_outline,
                            onTap: () => widget.onSelectTab(1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _reveal(
                          3,
                          _statCard(
                            stream: _vehicles,
                            label: 'Vehicles',
                            icon: Icons.directions_car_outlined,
                            onTap: () => widget.onSelectTab(2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  _reveal(4, _heading('Quick actions', 'Manage your day')),

                  const SizedBox(height: 20),

                  _reveal(
                    4,
                    _action(
                      icon: Icons.person_add_alt_1,
                      title: 'Add a customer',
                      subtitle: 'Save customer contact details.',
                      onTap: () => widget.onOpen(const AddCustomerScreen()),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _reveal(
                    5,
                    _action(
                      icon: Icons.add_road_rounded,
                      title: 'Register a vehicle',
                      subtitle: 'Connect a vehicle to its owner.',
                      onTap: () => widget.onOpen(const AddVehicleScreen()),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _reveal(
                    6,
                    _action(
                      icon: Icons.inventory_2_outlined,
                      title: 'Manage spare parts',
                      subtitle: 'Check stock and add new parts.',
                      onTap: () => widget.onSelectTab(3),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _reveal(
                    7,
                    _action(
                      icon: Icons.assignment_outlined,
                      title: 'Bookings & Job Cards',
                      subtitle: 'Manage each vehicle’s service.',
                      onTap: () => widget.onSelectTab(2),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _reveal(
                    8,
                    _action(
                      icon: Icons.receipt_long_outlined,
                      title: 'Billing & payments',
                      subtitle: 'View invoices and received payments.',
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

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _DashboardColors.coffee,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _DashboardColors.border, width: 0.7),
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
                  color: _DashboardColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'YOUR WORKSHOP COMPANION',
                  style: TextStyle(
                    color: _DashboardColors.beige,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Every vehicle.\nEvery detail.',
            style: TextStyle(
              color: _DashboardColors.text,
              fontSize: 31,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Keep your customers, service jobs and '
            'workshop essentials organised.',
            style: TextStyle(
              color: _DashboardColors.beige,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 20),

          _animatedRoad(),

          const SizedBox(height: 20),

          _TouchPopCard(
            onTap: () => widget.onSelectTab(2),
            borderRadius: 16,
            backgroundColor: _DashboardColors.gold,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: _DashboardColors.coffee,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Open vehicles',
                    style: TextStyle(
                      color: _DashboardColors.coffee,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedRoad() {
    return ExcludeSemantics(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: _DashboardColors.olive,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _road,
              builder: (context, child) {
                final progress = _road.value;

                final carX = -44 + (constraints.maxWidth + 88) * progress;

                final fade = math
                    .min(progress / 0.12, (1 - progress) / 0.12)
                    .clamp(0.0, 1.0)
                    .toDouble();

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DrivingRoadPainter(progress),
                      ),
                    ),
                    Positioned(
                      left: carX,
                      top: 10,
                      child: Opacity(
                        opacity: fade,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _DashboardColors.coffee,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _DashboardColors.gold),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: _DashboardColors.gold,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
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
          style: const TextStyle(color: _DashboardColors.beige, fontSize: 12),
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
    return _TouchPopCard(
      onTap: onTap,
      borderRadius: 22,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _DashboardColors.gold, size: 27),

            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unavailable',
                    style: TextStyle(
                      color: _DashboardColors.beige,
                      fontSize: 11,
                    ),
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

                final count = snapshot.data!.docs.length;

                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: count.toDouble()),
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '${value.round()}',
                      style: const TextStyle(
                        color: _DashboardColors.text,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: const TextStyle(
                color: _DashboardColors.beige,
                fontSize: 12,
              ),
            ),
          ],
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
    return _TouchPopCard(
      onTap: onTap,
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _DashboardColors.olive,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _DashboardColors.gold, size: 23),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _DashboardColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _DashboardColors.beige,
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
              color: _DashboardColors.beige,
            ),
          ],
        ),
      ),
    );
  }
}

// Road animation
class _DrivingRoadPainter extends CustomPainter {
  final double progress;

  _DrivingRoadPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = const Color(0x667D715A)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, 9), Offset(size.width, 9), edgePaint);

    canvas.drawLine(
      Offset(0, size.height - 9),
      Offset(size.width, size.height - 9),
      edgePaint,
    );

    final dashPaint = Paint()..color = _DashboardColors.gold;

    const spacing = 38.0;
    final shift = -progress * spacing;

    for (double x = shift; x < size.width; x += spacing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height / 2 - 1.5, 22, 3),
          const Radius.circular(2),
        ),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DrivingRoadPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Android touch pop animation.
// The page opens only after the animation finishes.
class _TouchPopCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final Color backgroundColor;

  const _TouchPopCard({
    required this.child,
    required this.onTap,
    this.borderRadius = 20,
    this.backgroundColor = _DashboardColors.coffee,
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
      duration: const Duration(milliseconds: 240),
    );

    _scale = _controller.drive(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1,
            end: 1.045,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 45,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.045,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 55,
        ),
      ]),
    );
  }

  Future<void> _activate() async {
    if (_busy) return;

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (reduceMotion) {
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
    final isGold = widget.backgroundColor == _DashboardColors.gold;

    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        scale: _hovered && !_busy && !reduceMotion ? 1.015 : 1,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? const Color(0x44000000)
                      : const Color(0x00000000),
                  blurRadius: active ? 18 : 0,
                  offset: Offset(0, active ? 8 : 0),
                ),
              ],
            ),
            child: Material(
              color: widget.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                side: BorderSide(
                  color: active || isGold
                      ? _DashboardColors.gold
                      : _DashboardColors.border,
                  width: active ? 1.2 : 0.7,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _activate,
                splashColor: isGold
                    ? const Color(0x223C312B)
                    : const Color(0x33F7B22C),
                highlightColor: Colors.transparent,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
