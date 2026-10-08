import 'package:preload_google_ads/preload_google_ads.dart';

import 'ads_service.dart';
import 'meta_ad_stats.dart';
import 'meta_ads_bridge.dart';
import 'meta_platform_view.dart';

/// A native ad slot that asks Meta Audience Network first and, if Meta errors
/// (or has no placement id configured), shows the package's preloaded AdMob
/// native ad in its place -- i.e. a drop-in replacement for
/// `PreloadGoogleAds.instance.showNativeAd(nativeADType: type)`.
///
/// The Meta ad is drawn natively (MetaAdViews.kt) inside the same sized,
/// decorated shell the AdMob slot uses, so the slot keeps one footprint
/// whichever network fills it.
class MetaFirstNativeAd extends StatefulWidget {
  const MetaFirstNativeAd({super.key, this.type = NativeADType.medium});

  final NativeADType type;

  @override
  State<MetaFirstNativeAd> createState() => _MetaFirstNativeAdState();
}

enum _Source { pending, meta, google }

class _MetaFirstNativeAdState extends State<MetaFirstNativeAd> {
  _Source _source = _Source.pending;
  String? _metaAdId;

  bool get _small => widget.type == NativeADType.small;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await AdsService.instance.config;
    if (!mounted) return;
    final placementId = _small
        ? config.metaNativeBannerPlacement
        : config.metaNativePlacement;
    if (placementId == null || !MetaAdsBridge.isSupported) {
      setState(() => _source = _Source.google);
      return;
    }

    final id = await MetaAdsBridge.loadNative(placementId, small: _small);
    if (!mounted) {
      if (id != null) MetaAdsBridge.destroy(id);
      return;
    }
    if (id == null) {
      MetaAdStats
          .instance[_small ? MetaAdFormat.nativeBanner : MetaAdFormat.native]
          .fallbacks
          .value++;
    }
    setState(() {
      _metaAdId = id;
      _source = id != null ? _Source.meta : _Source.google;
    });
  }

  @override
  void dispose() {
    final id = _metaAdId;
    if (id != null) MetaAdsBridge.destroy(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_source) {
      case _Source.google:
        return PreloadGoogleAds.instance.showNativeAd(
          nativeADType: widget.type,
        );
      case _Source.pending:
        // Held open at the ad's size so content doesn't jump when it lands.
        return _shell(context, child: const SizedBox.expand());
      case _Source.meta:
        return _shell(context, child: _metaView(context));
    }
  }

  /// Same box as the package's native slot (show_native.dart's _buildShell).
  Widget _shell(BuildContext context, {required Widget child}) {
    final style = NativeADStyle.instance;
    final isDark = style.isDarkMode(context: context);
    final decoration = (isDark && style.darkDecoration != null)
        ? style.darkDecoration
        : style.lightDecoration;
    return Container(
      decoration: decoration,
      constraints: _small
          ? style.smallConstraintsSize
          : style.mediumConstraintsSize,
      margin: style.margin,
      padding: style.padding,
      child: child,
    );
  }

  Widget _metaView(BuildContext context) {
    final style = NativeADStyle.instance.getCustomStyle(context: context);
    return MetaPlatformView(
      viewType: MetaAdsBridge.nativeViewType,
      creationParams: {
        'id': _metaAdId!,
        'titleColor': style.titleColor.toARGB32(),
        'bodyColor': style.bodyColor.toARGB32(),
        'tagBackground': style.tagBackground.toARGB32(),
        'tagForeground': style.tagForeground.toARGB32(),
        'buttonBackground': style.buttonBackground.toARGB32(),
        'buttonForeground': style.buttonForeground.toARGB32(),
        'buttonRadius': style.buttonRadius,
        'tagRadius': style.tagRadius,
      },
    );
  }
}
