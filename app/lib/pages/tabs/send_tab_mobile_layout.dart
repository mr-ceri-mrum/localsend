import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/file_picker.dart';

/// Dark “Share”-style shell used for the mobile send tab (matches compact grid + banner layout).
ThemeData sendTabMobileTheme() {
  const accent = Color(0xFF88A4FF);
  const bg = Color(0xFF0D0D0D);
  const surface = Color(0xFF1A1A1A);
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
      onSurface: Color(0xFFE8E8E8),
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
    const accent = Color(0xFF88A4FF);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        children: [
          _WindowsMark(color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.appName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE8E8E8),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowsMark extends StatelessWidget {
  final Color color;

  const _WindowsMark({required this.color});

  @override
  Widget build(BuildContext context) {
    Widget cell() => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
    return SizedBox(
      width: 18,
      height: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [cell(), cell()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [cell(), cell()],
          ),
        ],
      ),
    );
  }
}

class SendTabMobileSelectionGrid extends StatelessWidget {
  final List<FilePickerOption> options;
  final void Function(FilePickerOption option) onOptionTap;

  const SendTabMobileSelectionGrid({
    required this.options,
    required this.onOptionTap,
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
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final tint = _tint(option);
        return Material(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
                      color: Color(0xFFE8E8E8),
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
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
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

  const SendTabMobileNearbySectionTitle({
    required this.scanning,
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
          if (scanning)
            Text(
              '• ${t.sendTab.scan}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
        ],
      ),
    );
  }
}
