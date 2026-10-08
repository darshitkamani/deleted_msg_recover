import 'package:preload_google_ads/preload_google_ads.dart';

import 'ads_service.dart';
import 'meta_ad_stats.dart';
import 'meta_ads_bridge.dart';
import 'meta_platform_view.dart';

/// The two banner sizes, each matching both networks' own size.
enum MetaBannerSize {
  /// Meta's BANNER_HEIGHT_50 / AdMob's 320x50 banner.
  standard(50),

  /// Meta's RECTANGLE_HEIGHT_250 / AdMob's 300x250 medium rectangle.
  mediumRectangle(250);

  const MetaBannerSize(this.height);

  final double height;
}

/// A banner slot: Meta Audience Network first, and an AdMob banner
/// (`bannerId`) only if Meta errors or has no placement id for this [size].
/// Loaded when the slot is built, not preloaded. Each network follows its own
/// switch (`showMetaBanner` / `showBanner`); collapses to nothing if both are
/// off or neither fills.
class MetaFirstBannerAd extends StatefulWidget {
  const MetaFirstBannerAd({super.key, this.size = MetaBannerSize.standard});

  final MetaBannerSize size;

  @override
  State<MetaFirstBannerAd> createState() => _MetaFirstBannerAdState();
}

class _MetaFirstBannerAdState extends State<MetaFirstBannerAd> {
  String? _metaAdId;
  BannerAd? _googleAd;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await AdsService.instance.config;
    if (!mounted) return;
    final mediumRectangle = widget.size == MetaBannerSize.mediumRectangle;
    final metaPlacementId = mediumRectangle
        ? config.metaMediumRectanglePlacement
        : config.metaBannerPlacement;
    if (metaPlacementId != null) {
      final id = await MetaAdsBridge.loadBanner(
        metaPlacementId,
        mediumRectangle: mediumRectangle,
      );
      if (!mounted) {
        if (id != null) MetaAdsBridge.destroy(id);
        return;
      }
      if (id != null) {
        setState(() => _metaAdId = id);
        return;
      }
      MetaAdStats
          .instance[mediumRectangle
              ? MetaAdFormat.mediumRectangle
              : MetaAdFormat.banner]
          .fallbacks
          .value++;
    }

    final googleId = config.googleBannerId;
    if (googleId == null) {
      setState(() => _failed = true);
      return;
    }
    BannerAd(
      adUnitId: googleId,
      size: mediumRectangle ? AdSize.mediumRectangle : AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _googleAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob banner failed to load: $error');
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    final id = _metaAdId;
    if (id != null) MetaAdsBridge.destroy(id);
    _googleAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    final metaId = _metaAdId;
    final googleAd = _googleAd;
    final Widget child;
    if (metaId != null) {
      child = MetaPlatformView(
        viewType: MetaAdsBridge.bannerViewType,
        creationParams: {'id': metaId},
      );
    } else if (googleAd != null) {
      child = Center(
        child: SizedBox(
          width: googleAd.size.width.toDouble(),
          height: googleAd.size.height.toDouble(),
          child: AdWidget(ad: googleAd),
        ),
      );
    } else {
      // Still loading: hold the space so content below doesn't jump.
      child = const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: widget.size.height,
      child: child,
    );
  }
}
