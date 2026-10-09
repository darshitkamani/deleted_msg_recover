import 'package:preload_google_ads/preload_google_ads.dart';

import '../native_bridge.dart';

/// Floating "Ad Inspector" debug overlay: a draggable button (green, so it
/// isn't confused with the package's indigo Ad Metrics Lab) that opens a small
/// panel with this device's advertising ID and a button for Google's AdMob Ad
/// Inspector -- the tool for checking mediation (which ad source, e.g. Meta
/// Audience Network bidding, filled each request; single-ad-source testing).
///
/// Drawn by app.dart above every screen while AdLabSettings.showInspectorLab
/// is on.
class AdInspectorLab extends StatefulWidget {
  const AdInspectorLab({super.key});

  @override
  State<AdInspectorLab> createState() => _AdInspectorLabState();
}

class _AdInspectorLabState extends State<AdInspectorLab> {
  static const _green = Color(0xFF1E8E3E);
  static const _buttonSize = 52.0;
  static const _panelWidth = 300.0;
  static const _panelHeight = 150.0;

  /// Starts on the right edge, below the Ad Metrics Lab button's (20, 140).
  Offset? _position;
  bool _open = false;
  String? _inspectorError;

  /// This device's advertising ID, for registering it as a test device (AdMob
  /// Settings -> Test devices, Meta Monetization Manager -> Integration ->
  /// Testing). Fetched once.
  late final Future<String?> _advertisingId = NativeBridge.getAdvertisingId();

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
            child: _panel(isDark),
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
                  colors: [Color(0xFF34A853), _green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                _open ? Icons.close_rounded : Icons.search_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _panelWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: _green),
                const SizedBox(width: 6),
                const Text(
                  'Ad Inspector',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
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
            _advertisingIdRow(),
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

  /// Advertising ID with a copy button -- the ID AdMob's and Meta's test
  /// device lists ask for (not the hashed AdMob test device id in main.dart).
  Widget _advertisingIdRow() {
    return FutureBuilder<String?>(
      future: _advertisingId,
      builder: (context, snapshot) {
        final id = snapshot.data;
        final label = switch (snapshot.connectionState) {
          ConnectionState.done => id ?? 'unavailable (deleted in Settings?)',
          _ => 'loading…',
        };
        return Row(
          children: [
            Expanded(
              child: Text(
                'Ad ID: $label',
                maxLines: 2,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            if (id != null)
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: id));
                  debugPrint('Advertising ID: $id');
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('Advertising ID copied')),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.copy_rounded, size: 16, color: _green),
                ),
              ),
          ],
        );
      },
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
}
