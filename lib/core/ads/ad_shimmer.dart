import 'package:flutter/material.dart';

/// A skeleton of an ad -- icon block, headline/body lines and, when there's
/// room, body text and a button -- swept by a shimmer highlight. Shown in a
/// Meta-first ad slot while its ad loads. Same look as preload_google_ads'
/// own native placeholder (show_native.dart, which keeps it private), so a
/// slot looks the same whichever network ends up filling it.
class AdShimmer extends StatefulWidget {
  const AdShimmer({super.key, required this.isDark});

  final bool isDark;

  @override
  State<AdShimmer> createState() => _AdShimmerState();
}

class _AdShimmerState extends State<AdShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark
        ? const Color(0xFF505058)
        : const Color(0xFFFEFEFF);
    final highlightColor = widget.isDark
        ? const Color(0xFF3C3C44)
        : const Color(0xFFEAEAEC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.15, 0.5, 0.85],
          transform: _SlidingGradient(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Short slots (small native, 50dp banner) get the one-row version.
          final compact = constraints.maxHeight < 150;
          final iconSize = compact
              ? (constraints.maxHeight - 24).clamp(16.0, 40.0)
              : 56.0;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                _block(width: iconSize, height: iconSize, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(width: double.infinity, height: 12),
                      if (constraints.maxHeight >= 60) ...[
                        const SizedBox(height: 8),
                        _block(width: 90, height: 10),
                      ],
                      if (!compact) ...[
                        const SizedBox(height: 16),
                        _block(width: double.infinity, height: 9),
                        const SizedBox(height: 6),
                        _block(width: double.infinity, height: 9),
                        const SizedBox(height: 6),
                        _block(width: 140, height: 9),
                        const SizedBox(height: 16),
                        _block(width: 96, height: 26, radius: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Solid white: the visible color comes from the ShaderMask gradient.
  Widget _block({
    required double width,
    required double height,
    double radius = 4,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Slides the highlight from fully off one side to fully off the other as
/// [slidePercent] goes 0..1.
class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (2 * slidePercent - 1), 0, 0);
}
