import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

/// An in-app player for recovered voice notes with a real amplitude
/// waveform (extracted from the actual audio file) instead of a plain
/// slider -- tap to play/pause, tap or drag the waveform to seek. Nothing
/// ever leaves the device or opens another app.
class VoiceMessagePlayer extends StatefulWidget {
  final String path;

  const VoiceMessagePlayer({super.key, required this.path});

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  static const _waveHeight = 34.0;
  static const _waveSpacing = 4.0;
  static const _buttonSize = 36.0;
  static const _buttonGap = 8.0;
  // The waveform fills up to 80% of whatever width is actually available
  // for it (the bubble's width minus the play button), instead of a fixed
  // size that looks cramped in a wide bubble or overflows a narrow one.
  //
  // This can't be measured live via LayoutBuilder: the bubble that hosts
  // this widget uses IntrinsicWidth to shrink-wrap short messages, and
  // IntrinsicWidth cannot contain a LayoutBuilder anywhere in its subtree
  // (computing intrinsics would require speculatively re-running that
  // layout callback). So it's derived from the screen width instead,
  // mirroring the same max-bubble-width math message_bubble.dart uses.
  static const _bubbleHorizontalPadding = 16.0;
  static const _widthFraction = 0.8;

  late final PlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _preparing = false;
  double? _waveWidth;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int>? _durationSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _controller = PlayerController();
    _stateSub = _controller.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _durationSub = _controller.onCurrentDurationChanged.listen((ms) {
      if (mounted) setState(() => _position = Duration(milliseconds: ms));
    });
    _completeSub = _controller.onCompletion.listen((_) async {
      await _controller.seekTo(0);
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  Future<void> _prepare(double waveWidth) async {
    if (_preparing) return;
    _preparing = true;
    try {
      await _controller.preparePlayer(
        path: widget.path,
        shouldExtractWaveform: true,
        noOfSamples: (waveWidth / _waveSpacing).floor().clamp(10, 300),
      );
      await _controller.setFinishMode(finishMode: FinishMode.pause);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState.isPlaying) {
      await _controller.pausePlayer();
    } else {
      await _controller.startPlayer();
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_off_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text('Voice message', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    final showingElapsed = _playerState.isPlaying || _position > Duration.zero;
    final label = showingElapsed
        ? _position
        : Duration(milliseconds: _ready ? _controller.maxDuration : 0);

    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleContentWidth = screenWidth * 0.8 - _bubbleHorizontalPadding;
    final waveWidth =
        ((bubbleContentWidth - _buttonSize - _buttonGap) * _widthFraction)
            .clamp(60.0, 500.0);

    if (_waveWidth == null) {
      _waveWidth = waveWidth;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare(waveWidth));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: _ready ? _togglePlay : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: _ready
                ? Icon(
                    _playerState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
          ),
        ),
        SizedBox(width: _buttonGap),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_ready)
              AudioFileWaveforms(
                size: Size(_waveWidth!, _waveHeight),
                playerController: _controller,
                waveformType: WaveformType.fitWidth,
                enableSeekGesture: true,
                playerWaveStyle: PlayerWaveStyle(
                  fixedWaveColor: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.35,
                  ),
                  liveWaveColor: theme.colorScheme.primary,
                  spacing: _waveSpacing,
                  waveThickness: 2.5,
                  showSeekLine: false,
                ),
              )
            else
              SizedBox(height: _waveHeight, width: waveWidth),
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 2),
              child: Text(
                _format(label),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
