import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

final _log = Logger('AdMob');

/// Initializes the Google Mobile Ads SDK on Android and iOS.
/// App IDs must be set in [AndroidManifest.xml] and [Info.plist] (see AdMob console).
Future<void> initMobileAdsIfMobile() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }
  try {
    await MobileAds.instance.initialize();
  } catch (e, st) {
    _log.warning('Mobile Ads initialization failed', e, st);
  }
}
