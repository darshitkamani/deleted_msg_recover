import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Branded launch screen shown for a minimum stretch while [AppState.init]
/// runs in the background (see [_RootRouter] in app.dart) -- purely visual,
/// no business logic of its own.
///
/// The whole screen *is* a mock chat conversation (header, message bubbles,
/// composer) rather than a small floating card, so it reads as "this is the
/// app" from the very first frame. Inside it plays a tiny looping story: a
/// message arrives and gets deleted, this app recovers it, then shows it
/// also catches edits and new messages live -- the app's whole pitch, on
/// repeat for however long the splash actually stays up.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;

  late final AnimationController _storyController;

  // Scene windows within the looping story controller's 0..1 timeline.
  // Deliberately overlapping at the edges so consecutive scenes cross-fade
  // into each other instead of hard-cutting.
  static const _deletedWindow = (0.0, 0.38);
  static const _recoveredWindow = (0.30, 0.68);
  static const _liveWindow = (0.60, 1.0);

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
          ),
        );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
      ),
    );

    _storyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5400),
    )..repeat();
  }

  @override
  void dispose() {
    _introController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  /// Opacity for a scene active during [start]..[end] of the story
  /// timeline: 0 outside that window, fading in/out over the first/last
  /// ~18% of it, fully opaque in between.
  static double _sceneOpacity(double t, double start, double end) {
    if (t < start || t > end) return 0;
    final span = end - start;
    final fade = (span * 0.18).clamp(0.0, span / 2);
    if (t < start + fade) return (t - start) / fade;
    if (t > end - fade) return (end - t) / fade;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final deep = Color.lerp(scheme.primary, Colors.black, 0.25)!;
    final teal = Color.lerp(scheme.primary, Colors.cyan, 0.35)!;
    final bubbleMaxWidth = MediaQuery.sizeOf(context).width * 0.62;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [teal, scheme.primary, deep],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative watermark, matching the Recover tab's header so the
            // very first thing the user sees already looks like "this app".
            Positioned(
              right: -40,
              top: -30,
              child: Transform.rotate(
                angle: -0.35,
                child: Icon(
                  Icons.forum_rounded,
                  size: 220,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // The chat mock itself, filling the whole safe area -- header,
            // the looping scenes, a composer bar, then the tagline/loader
            // footer -- all in one normal-flow Column so nothing overlaps
            // regardless of screen height.
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.restore_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SlideTransition(
                          position: _textSlide,
                          child: FadeTransition(
                            opacity: _textOpacity,
                            child: Text(
                              l10n.appTitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Fixed-height scene area, top-aligned right under the
                  // header -- like a real conversation's first few messages
                  // -- instead of centering in whatever space is left, which
                  // left a huge empty gap on tall screens.
                  SizedBox(
                    height: 190,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: AnimatedBuilder(
                        animation: _storyController,
                        builder: (context, _) {
                          final t = _storyController.value;
                          return Stack(
                            alignment: Alignment.topLeft,
                            children: [
                              Opacity(
                                opacity: _sceneOpacity(
                                  t,
                                  _deletedWindow.$1,
                                  _deletedWindow.$2,
                                ),
                                child: _DeletedScene(
                                  local:
                                      ((t - _deletedWindow.$1) /
                                              (_deletedWindow.$2 -
                                                  _deletedWindow.$1))
                                          .clamp(0.0, 1.0),
                                  maxWidth: bubbleMaxWidth,
                                ),
                              ),
                              Opacity(
                                opacity: _sceneOpacity(
                                  t,
                                  _recoveredWindow.$1,
                                  _recoveredWindow.$2,
                                ),
                                child: _RecoveredScene(
                                  local:
                                      ((t - _recoveredWindow.$1) /
                                              (_recoveredWindow.$2 -
                                                  _recoveredWindow.$1))
                                          .clamp(0.0, 1.0),
                                  maxWidth: bubbleMaxWidth,
                                ),
                              ),
                              Opacity(
                                opacity: _sceneOpacity(
                                  t,
                                  _liveWindow.$1,
                                  _liveWindow.$2,
                                ),
                                child: _LiveScene(
                                  local:
                                      ((t - _liveWindow.$1) /
                                              (_liveWindow.$2 - _liveWindow.$1))
                                          .clamp(0.0, 1.0),
                                  maxWidth: bubbleMaxWidth,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _MockComposerBar(),
                    ),
                  ),
                  // Flexible gap: whatever room is left between the composer
                  // and the footer below, so the footer always sits near the
                  // true bottom of the screen without colliding with the
                  // composer above it.
                  const Expanded(child: SizedBox()),
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: deep.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AnimatedBuilder(
                            animation: _storyController,
                            builder: (context, _) {
                              final t = _storyController.value;
                              final label = t < _deletedWindow.$2
                                  ? l10n.splashTaglineDetecting
                                  : t < _recoveredWindow.$2
                                  ? l10n.splashTaglineRecovering
                                  : l10n.splashTaglineTracking;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                child: Text(
                                  label,
                                  key: ValueKey(label),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A translucent "type a message" pill mimicking the composer bar of a
/// real chat screen, purely decorative here.
class _MockComposerBar extends StatelessWidget {
  const _MockComposerBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: _barDecoration(Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.send_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _barDecoration(Color color) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(4));

/// Scene 1: an incoming bubble arrives, gets struck through, then collapses
/// into the app's grey "deleted message" placeholder with a trash icon.
class _DeletedScene extends StatelessWidget {
  final double local;
  final double maxWidth;

  const _DeletedScene({required this.local, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final arrive = (local / 0.3).clamp(0.0, 1.0);
    final strike = ((local - 0.3) / 0.25).clamp(0.0, 1.0);
    final collapse = ((local - 0.55) / 0.45).clamp(0.0, 1.0);

    return Align(
      alignment: Alignment.centerLeft,
      child: Opacity(
        opacity: arrive,
        child: Transform.translate(
          offset: Offset(-16 * (1 - arrive), 0),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Opacity(
                opacity: 1 - collapse,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      const Text(
                        'See you at the usual spot?',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF3C4650),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: strike,
                        alignment: Alignment.centerLeft,
                        child: Container(height: 1.6, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: collapse,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.7 + 0.3 * collapse,
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'This message was deleted',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scene 2: a "recovered" badge pops in, then the original message
/// reappears in a green-tinted bubble underneath it.
class _RecoveredScene extends StatelessWidget {
  final double local;
  final double maxWidth;

  const _RecoveredScene({required this.local, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final badgeScale = Curves.elasticOut.transform(
      (local / 0.45).clamp(0.0, 1.0),
    );
    final bubbleReveal = ((local - 0.4) / 0.6).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: badgeScale,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 7),
                Text(
                  'Recovered',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: bubbleReveal,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - bubbleReveal)),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'See you at the usual spot?',
                style: TextStyle(fontSize: 14.5, color: Color(0xFF2E4033)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scene 3: an outgoing bubble picks up an "(edited)" tag, then a fresh
/// incoming message pops in below with a pulsing unread badge -- this app
/// catching edits and new messages alike, live.
class _LiveScene extends StatelessWidget {
  final double local;
  final double maxWidth;

  const _LiveScene({required this.local, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final outgoingArrive = (local / 0.3).clamp(0.0, 1.0);
    final editedTag = ((local - 0.25) / 0.25).clamp(0.0, 1.0);
    final incomingArrive = ((local - 0.55) / 0.3).clamp(0.0, 1.0);
    final pulse = local > 0.55
        ? (0.5 + 0.5 * (1 - (((local - 0.55) * 6) % 1.0 - 0.5).abs() * 2))
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: outgoingArrive,
            child: Transform.translate(
              offset: Offset(16 * (1 - outgoingArrive), 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDAF1E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '6pm works for me!',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF1F3D33),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: editedTag,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: incomingArrive,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - incomingArrive)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Perfect, see you then 🙌',
                    style: TextStyle(fontSize: 14.5, color: Color(0xFF3C4650)),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: pulse,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
