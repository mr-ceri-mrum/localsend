import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AdMobBanner');

/// Reusable banner ad widget for mobile platforms.
///
/// Replace these test IDs with your own banner unit IDs before release.
const _androidBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
const _iosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';

/// Where to pin the banner when used as an overlay (does not reserve layout space).
enum AdMobBannerSlot { top, bottom }

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({
    this.slot = AdMobBannerSlot.bottom,
    super.key,
  });

  final AdMobBannerSlot slot;

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBanner());
  }

  @override
  void dispose() {
    final bannerAd = _bannerAd;
    if (bannerAd != null) {
      unawaited(bannerAd.dispose());
    }
    super.dispose();
  }

  Future<void> _loadBanner() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    final adUnitId = Platform.isAndroid ? _androidBannerUnitId : _iosBannerUnitId;

    final banner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }
          setState(() {
            _isLoaded = true;
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          _logger.warning('Banner failed to load: $error');
          unawaited(ad.dispose());
        },
      ),
    );

    unawaited(banner.load());
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final ad = SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );

    // Overlay: only wrap the real ad size; SafeArea avoids notch / home indicator.
    return Align(
      alignment: widget.slot == AdMobBannerSlot.top ? Alignment.topCenter : Alignment.bottomCenter,
      child: SafeArea(
        top: widget.slot == AdMobBannerSlot.top,
        bottom: widget.slot == AdMobBannerSlot.bottom,
        left: false,
        right: false,
        minimum: EdgeInsets.zero,
        child: ad,
      ),
    );
  }
}
