import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_lab_settings.dart';

/// Hidden dialog for switching the Ad Metrics Lab and Ad Inspector overlays on/off on
/// this device. Reached only by holding [AdLabDialogTrigger] for
/// [AdLabDialogTrigger.holdDuration], so it's internal-only and not
/// localized.
Future<void> showAdLabDialog(BuildContext context) {
  final settings = AdLabSettings.instance;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ad Metrics Lab'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: settings.showGoogleLab,
            builder: (context, value, _) => SwitchListTile(
              title: const Text('Google Ad Metrics Lab'),
              value: value,
              onChanged: settings.setGoogleLab,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: settings.showInspectorLab,
            builder: (context, value, _) => SwitchListTile(
              title: const Text('Ad Inspector'),
              value: value,
              onChanged: settings.setInspectorLab,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            settings.resetToRemote();
            Navigator.of(context).pop();
          },
          child: const Text('Use server config'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Opens [showAdLabDialog] once [child] has been held down for
/// [holdDuration]. Lifting the finger (or the gesture being cancelled) any
/// earlier does nothing extra -- [child]'s own tap handling is untouched,
/// except that the wrapped button should set a no-op `onLongPress` so a hold
/// doesn't also count as a tap when the finger is lifted.
class AdLabDialogTrigger extends StatefulWidget {
  const AdLabDialogTrigger({super.key, required this.child});

  static const holdDuration = Duration(seconds: 10);

  final Widget child;

  @override
  State<AdLabDialogTrigger> createState() => _AdLabDialogTriggerState();
}

class _AdLabDialogTriggerState extends State<AdLabDialogTrigger> {
  Timer? _timer;

  void _start(PointerDownEvent _) {
    _timer?.cancel();
    _timer = Timer(AdLabDialogTrigger.holdDuration, () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showAdLabDialog(context);
    });
  }

  void _cancel([PointerEvent? _]) {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _start,
      onPointerUp: _cancel,
      onPointerCancel: _cancel,
      child: widget.child,
    );
  }
}
