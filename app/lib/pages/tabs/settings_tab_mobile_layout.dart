import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/language_page.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Dark settings shell (matches Send tab / mockup).
ThemeData settingsTabMobileTheme() {
  const accent = Color(0xFF6B9FFF);
  const bg = Color(0xFF0A0A0A);
  const surface = Color(0xFF161616);
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    cardColor: surface,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF0A0A0A),
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: Color(0xFFE8E8E8),
      surfaceContainerHighest: Color(0xFF242424),
      outline: Color(0xFF4A4A4A),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF0A0A0A);
        }
        return const Color(0xFFB0B0B0);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent;
        }
        return const Color(0xFF3A3A3A);
      }),
    ),
  );
}

class SettingsTabMobileView extends StatelessWidget {
  final SettingsTabVm vm;

  const SettingsTabMobileView({
    required this.vm,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final top = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8 + top, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _MobileSettingsHeader(),
              const SizedBox(height: 20),
              _sectionLabel(t.settingsTab.mobile.sectionGeneral),
              _SettingsCard(
                children: [
                  _NavRow(
                    icon: Icons.badge_rounded,
                    iconBg: const Color(0xFF5C6BC0),
                    label: t.settingsTab.network.alias,
                    value: vm.settings.alias,
                    onTap: () => _openAliasDialog(context, vm),
                  ),
                  _divider,
                  _NavRow(
                    icon: Icons.language_rounded,
                    iconBg: const Color(0xFFEC407A),
                    label: t.settingsTab.general.language,
                    value: vm.settings.locale?.humanName ?? t.settingsTab.general.languageOptions.system,
                    onTap: () => vm.onTapLanguage(context),
                  ),
                  _divider,
                  _ToggleRow(
                    icon: Icons.motion_photos_on_outlined,
                    iconBg: const Color(0xFF546E7A),
                    label: t.settingsTab.general.animations,
                    value: vm.settings.enableAnimations,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setEnableAnimations(b);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(t.settingsTab.mobile.sectionReceive),
              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.lock_rounded,
                    iconBg: const Color(0xFF7E57C2),
                    label: t.settingsTab.receive.requirePin,
                    value: vm.settings.receivePin != null,
                    onChanged: (b) async {
                      final currentPIN = vm.settings.receivePin;
                      if (currentPIN != null) {
                        await ref.notifier(settingsProvider).setReceivePin(null);
                      } else {
                        final String? newPin = await showDialog<String>(
                          context: context,
                          builder: (_) => const PinDialog(
                            obscureText: false,
                            generateRandom: false,
                          ),
                        );

                        if (newPin != null && newPin.isNotEmpty) {
                          await ref.notifier(settingsProvider).setReceivePin(newPin);
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _RestartServerButton(vm: vm),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}

Future<void> _openAliasDialog(BuildContext context, SettingsTabVm vm) async {
  final ref = context.ref;
  final controller = TextEditingController(text: vm.settings.alias);

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t.settingsTab.network.alias),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(dialogContext).pop(controller.text.trim()),
          decoration: InputDecoration(
            hintText: t.settingsTab.network.alias,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.general.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(t.general.save),
          ),
        ],
      );
    },
  );

  final alias = result?.trim() ?? '';
  if (alias.isEmpty || alias == vm.settings.alias) {
    return;
  }

  vm.aliasController.text = alias;
  await ref.notifier(settingsProvider).setAlias(alias);
}

class _RestartServerButton extends StatelessWidget {
  final SettingsTabVm vm;

  const _RestartServerButton({required this.vm});

  @override
  Widget build(BuildContext context) {
    final running = vm.serverState != null;
    const accent = Color(0xFF6B9FFF);

    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: running
            ? () {
                vm.onTapRestartServer(context);
              }
            : null,
        child: Opacity(
          opacity: running ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    t.settingsTab.mobile.restartServer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSettingsHeader extends StatelessWidget {
  const _MobileSettingsHeader();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6B9FFF);
    return Row(
      children: [
        const _WindowsMark(color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t.appName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B9FFF),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
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

Widget _sectionLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
      ),
    ),
  );
}

const _divider = Divider(height: 1, thickness: 1, color: Color(0xFF2A2A2A));

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              _IconCircle(bg: iconBg, icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE8E8E8),
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          _IconCircle(bg: iconBg, icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE8E8E8),
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final Color bg;
  final IconData icon;

  const _IconCircle({required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
