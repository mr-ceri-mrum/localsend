import 'package:flutter/material.dart';
import 'package:localsend_app/config/ios_style.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/widget/dialogs/nearby_windows_peer_help_sheet.dart';

/// Dark “Share”-style shell used for the mobile send tab (matches compact grid + banner layout).
ThemeData sendTabMobileTheme() {
  const accent = IosStyle.accent;
  const bg = IosStyle.background;
  const surface = IosStyle.card;
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    cardColor: surface,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF0D0D0D),
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: IosStyle.text,
      surfaceContainerHighest: Color(0xFF242424),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF242424),
    ),
  );
}

class SendTabMobileHeader extends StatelessWidget {
  const SendTabMobileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = IosStyle.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        children: [
          iosWindowsMark(color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.appName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: IosStyle.text,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SendTabMobileSelectionGrid extends StatelessWidget {
  final List<FilePickerOption> options;
  final void Function(FilePickerOption option) onOptionTap;
  final Widget? extraTile;

  const SendTabMobileSelectionGrid({
    required this.options,
    required this.onOptionTap,
    this.extraTile,
    super.key,
  });

  static List<FilePickerOption> orderedOptions(List<FilePickerOption> platformOptions) {
    const order = [
      FilePickerOption.media,
      FilePickerOption.file,
      FilePickerOption.folder,
      FilePickerOption.clipboard,
      FilePickerOption.text,
      FilePickerOption.app,
    ];
    return order.where(platformOptions.contains).toList();
  }

  Color _tint(FilePickerOption o) {
    switch (o) {
      case FilePickerOption.media:
        return const Color(0xFF9B8CFF);
      case FilePickerOption.file:
        return const Color(0xFF6B9EFF);
      case FilePickerOption.clipboard:
        return const Color(0xFFFFA76B);
      case FilePickerOption.text:
        return const Color(0xFF6BFF9B);
      case FilePickerOption.folder:
        return const Color(0xFF88C4FF);
      case FilePickerOption.app:
        return const Color(0xFFFF8CE8);
    }
  }

  /// Short hint under the title (visual parity with the reference mock).
  String _hint(FilePickerOption o) {
    switch (o) {
      case FilePickerOption.media:
        return 'Photos & videos';
      case FilePickerOption.file:
        return 'Documents';
      case FilePickerOption.clipboard:
        return 'Clipboard content';
      case FilePickerOption.text:
        return 'Notes & links';
      case FilePickerOption.folder:
        return 'All files inside';
      case FilePickerOption.app:
        return 'APK / package';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: options.length + (extraTile == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index >= options.length) {
          return extraTile!;
        }
        final option = options[index];
        final tint = _tint(option);
        return Material(
          color: IosStyle.card,
          borderRadius: BorderRadius.circular(IosStyle.radiusMedium),
          child: InkWell(
            borderRadius: BorderRadius.circular(IosStyle.radiusMedium),
            onTap: () => onOptionTap(option),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(option.icon, color: tint, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: IosStyle.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hint(option),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SendTabMobileWifiBanner extends StatelessWidget {
  final VoidCallback onTroubleshoot;

  const SendTabMobileWifiBanner({
    required this.onTroubleshoot,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88A4FF);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: IosStyle.card,
          borderRadius: BorderRadius.circular(IosStyle.radiusMedium),
          border: Border.all(color: IosStyle.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.wifi_rounded, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.sendTab.help,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      height: 1.35,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: accent,
                ),
                onPressed: onTroubleshoot,
                child: Text(t.troubleshootPage.title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SendTabMobileNearbySectionTitle extends StatelessWidget {
  final bool scanning;
  final VoidCallback onWindowsPeerHelpTap;

  const SendTabMobileNearbySectionTitle({
    required this.scanning,
    required this.onWindowsPeerHelpTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88A4FF);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.sendTab.nearbyDevices.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Tooltip(
            message: t.sendTab.windowsPeerHelp.tooltip,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onWindowsPeerHelpTap,
                borderRadius: BorderRadius.circular(999),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: IosStyle.cardBorder,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: IosStyle.card),
                      ),
                      child: Text(
                        kWindowsPeerDownloadSiteLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: IosStyle.mutedTextStrong,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (scanning) ...[
            const SizedBox(width: 6),
            Text(
              '• ${t.sendTab.scan}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
