import 'package:preload_google_ads/preload_google_ads.dart';

import 'meta_ad_stats.dart';

/// Floating "Meta Ad Lab" debug overlay: a draggable button (Meta blue, so it
/// isn't confused with the package's indigo Ad Metrics Lab) that opens a
/// per-format table of Meta requests / loads / impressions / clicks / errors /
/// fallbacks to AdMob, the last Meta error, and a button for Google's AdMob
/// Ad Inspector.
///
/// Drawn by app.dart above every screen in debug builds, and in release only
/// while the `showAdMetricsLab` remote flag is on.
class MetaAdLab extends StatefulWidget {
  const MetaAdLab({super.key});

  @override
  State<MetaAdLab> createState() => _MetaAdLabState();
}

class _MetaAdLabState extends State<MetaAdLab> {
  static const _metaBlue = Color(0xFF0866FF);
  static const _buttonSize = 52.0;
  static const _panelWidth = 330.0;
  static const _panelHeight = 360.0;

  /// Starts on the right edge, below the Ad Metrics Lab button's (20, 140).
  Offset? _position;
  bool _open = false;
  String? _inspectorError;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final position = _position ??= Offset(size.width - _buttonSize - 20, 210);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        if (_open)
          Positioned(
            left: (size.width - _panelWidth - 10)
                .clamp(10.0, double.infinity)
                .toDouble(),
            top: position.dy + _buttonSize + 8 + _panelHeight > size.height
                ? (position.dy - _panelHeight - 8).clamp(10.0, size.height)
                : position.dy + _buttonSize + 8,
            child: _panel(context, isDark),
          ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            onPanUpdate: (details) => setState(() {
              _position = Offset(
                (position.dx + details.delta.dx)
                    .clamp(0.0, size.width - _buttonSize)
                    .toDouble(),
                (position.dy + details.delta.dy)
                    .clamp(0.0, size.height - _buttonSize)
                    .toDouble(),
              );
              _open = false;
            }),
            onTap: () => setState(() => _open = !_open),
            child: Container(
              width: _buttonSize,
              height: _buttonSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_metaBlue, Color(0xFF0050D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: _open
                  ? const Icon(Icons.close_rounded, color: Colors.white)
                  : const Text(
                      'META',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context, bool isDark) {
    final stats = MetaAdStats.instance;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _panelWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _metaBlue.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, size: 16, color: _metaBlue),
                const SizedBox(width: 6),
                const Text(
                  'Meta Ad Lab',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool?>(
                  valueListenable: stats.initialized,
                  builder: (_, ready, _) => switch (ready) {
                    true => _pill('SDK READY', Colors.green),
                    false => _pill('SDK FAILED', Colors.red),
                    null => _pill('SDK PENDING', Colors.grey),
                  },
                ),
                if (kDebugMode) ...[
                  const SizedBox(width: 4),
                  _pill('TEST ADS', Colors.orange),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _open = false),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Divider(height: 14),
            Row(
              children: [
                const Expanded(
                  flex: 4,
                  child: Text(
                    'FORMAT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _header('REQ', Colors.deepPurple),
                _header('LOAD', Colors.blue),
                _header('IMP', Colors.green),
                _header('CLK', Colors.teal),
                _header('FAIL', Colors.red),
                _header('→G', Colors.orange),
              ],
            ),
            const Divider(height: 8),
            for (final format in MetaAdFormat.values)
              _row(format, stats[format]),
            const Divider(height: 14),
            ValueListenableBuilder<String?>(
              valueListenable: stats.lastError,
              builder: (_, error, _) => Text(
                'Last error: ${error ?? '—'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: error == null ? Colors.grey : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _openAdInspector,
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text(
                'Open AdMob Ad Inspector',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_inspectorError != null) ...[
              const SizedBox(height: 6),
              Text(
                _inspectorError!,
                style: const TextStyle(fontSize: 10, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Google's own AdMob Ad Inspector. Opens on test devices only -- debug
  /// builds' device is registered in main.dart; a release build needs its
  /// device added as a test device in the AdMob console.
  void _openAdInspector() {
    setState(() => _inspectorError = null);
    MobileAds.instance.openAdInspector((error) {
      if (error != null && mounted) {
        setState(() => _inspectorError = 'Ad Inspector: ${error.message}');
      }
    });
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color),
    ),
  );

  Widget _header(String title, Color color) => Expanded(
    flex: 2,
    child: Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color),
    ),
  );

  Widget _row(MetaAdFormat format, MetaFormatStats stats) {
    return AnimatedBuilder(
      animation: stats.all,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                format.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _cell(stats.requests.value),
            _cell(stats.loaded.value),
            _cell(stats.impressions.value),
            _cell(stats.clicks.value),
            _cell(stats.failed.value, highlight: Colors.red),
            _cell(stats.fallbacks.value, highlight: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _cell(int value, {Color? highlight}) => Expanded(
    flex: 2,
    child: Text(
      '$value',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: value > 0 && highlight != null ? highlight : null,
      ),
    ),
  );
}
