import 'package:flutter/material.dart';
import 'package:localsend_app/config/ios_style.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/dialogs/custom_bottom_sheet.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

/// Placeholder URL until a real download landing page is wired.
const String kWindowsPeerDownloadUrl = 'https://mr-ceri-mrum.github.io/windrop-site/';

/// Label shown on the nearby-devices hint chip.
const String kWindowsPeerDownloadSiteLabel = "Don't see?";

class NearbyWindowsPeerHelpSheet extends StatelessWidget {
  const NearbyWindowsPeerHelpSheet({super.key});

  static Future<void> open(BuildContext context) async {
    if (checkPlatformIsDesktop()) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.sendTab.windowsPeerHelp.title),
          content: Text(t.sendTab.windowsPeerHelp.description),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(t.general.close),
            ),
            TextButton(
              onPressed: () async {
                await _launchDownload();
                if (context.mounted) context.pop();
              },
              child: Text(t.sendTab.windowsPeerHelp.downloadCta),
            ),
          ],
        ),
      );
    } else {
      await context.pushBottomSheet(() => const NearbyWindowsPeerHelpSheet());
    }
  }

  static Future<void> _launchDownload() async {
    final uri = Uri.parse(kWindowsPeerDownloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return CustomBottomSheet(
      title: t.sendTab.windowsPeerHelp.title,
      description: t.sendTab.windowsPeerHelp.description,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxHeight < 360 ? 120.0 : 160.0;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(IosStyle.radiusMedium),
                    child: Container(
                      height: imageHeight,
                      color: Colors.black,
                      child: Image.asset(
                        'assets/img/receive_network_hero.png',
                        height: imageHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(IosStyle.radiusMedium),
                      ),
                    ),
                    onPressed: () async {
                      await _launchDownload();
                    },
                    child: Text(t.sendTab.windowsPeerHelp.downloadCta),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
