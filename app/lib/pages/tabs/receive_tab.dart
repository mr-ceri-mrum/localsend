import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/column_list_view.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _QuickSaveMode {
  off,
  favorites,
  on,
}

class ReceiveTab extends StatelessWidget {
  const ReceiveTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(receiveTabVmProvider);
    final selectedQuickSaveMode = vm.quickSaveFromFavoritesSettings
        ? _QuickSaveMode.favorites
        : vm.quickSaveSettings
        ? _QuickSaveMode.on
        : _QuickSaveMode.off;
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    if (isMobile) {
      return _MobileReceiveLayout(vm: vm);
    }

    return Stack(
      children: [
        checkPlatform([TargetPlatform.macOS])
            ? SizedBox(height: 50, child: MoveWindow())
            : SizedBox(height: 0, width: 0), // makes the top part that's not occupied by another widget draggable
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: ColumnListView(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 18),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          InitialFadeTransition(
                            duration: const Duration(milliseconds: 300),
                            delay: const Duration(milliseconds: 200),
                            child: Consumer(
                              builder: (context, ref) {
                                final animations = ref.watch(animationProvider);
                                final activeTab = ref.watch(homePageControllerProvider.select((state) => state.currentTab));
                                return RotatingWidget(
                                  duration: const Duration(seconds: 15),
                                  spinning: vm.serverState != null && animations && activeTab == HomeTab.receive,
                                  child: const SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: LocalSendLogo(withText: false),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vm.serverState?.alias ?? vm.aliasSettings,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                InitialFadeTransition(
                                  duration: const Duration(milliseconds: 300),
                                  delay: const Duration(milliseconds: 500),
                                  child: Text(
                                    vm.serverState == null ? t.general.offline : vm.localIps.map((ip) => '#${ip.visualId}').toSet().join(' '),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Column(
                        children: [
                          Text(t.general.quickSave),
                          const SizedBox(height: 10),
                          SegmentedButton<_QuickSaveMode>(
                            multiSelectionEnabled: false,
                            emptySelectionAllowed: false,
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) async {
                              if (selection.contains(_QuickSaveMode.off)) {
                                await vm.onSetQuickSave(context, false);
                                if (context.mounted) {
                                  await vm.onSetQuickSaveFromFavorites(context, false);
                                }
                              } else if (selection.contains(_QuickSaveMode.favorites)) {
                                await vm.onSetQuickSave(context, false);
                                if (context.mounted) {
                                  await vm.onSetQuickSaveFromFavorites(context, true);
                                }
                              } else if (selection.contains(_QuickSaveMode.on)) {
                                await vm.onSetQuickSaveFromFavorites(context, false);
                                if (context.mounted) {
                                  await vm.onSetQuickSave(context, true);
                                }
                              }
                            },
                            selected: {
                              selectedQuickSaveMode,
                            },
                            segments: [
                              ButtonSegment(
                                value: _QuickSaveMode.off,
                                label: Text(t.receiveTab.quickSave.off),
                              ),
                              ButtonSegment(
                                value: _QuickSaveMode.favorites,
                                label: Text(t.receiveTab.quickSave.favorites),
                              ),
                              ButtonSegment(
                                value: _QuickSaveMode.on,
                                label: Text(t.receiveTab.quickSave.on),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ),
        _InfoBox(vm),
        _CornerButtons(showHistoryButton: vm.showHistoryButton),
      ],
    );
  }
}

class _MobileReceiveLayout extends StatelessWidget {
  final ReceiveTabVm vm;

  const _MobileReceiveLayout({
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final discoverable = vm.serverState == null
        ? t.general.offline
        : vm.localIps.isEmpty
        ? t.general.unknown
        : '#${vm.localIps.first.visualId}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: ListView(
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF8FA9FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8FA9FF),
                    ),
                  ),
                ),
                CustomIconButton(
                  onPressed: () async => context.push(() => const ReceiveHistoryPage()),
                  child: const Icon(Icons.history, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF0F1B1C),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2127),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(Icons.laptop_mac_rounded, size: 36, color: Color(0xFF8FA9FF)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.receiveTab.infoBox.alias.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: Color(0xFF8C93A1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vm.serverState?.alias ?? vm.aliasSettings,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 46,
                            height: 0.95,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00D38F),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                discoverable,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFAAB1BE),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ReceiveNetworkHeroIllustration(),
          ],
        ),
      ),
    );
  }
}

/// Isometric phone–router–laptop illustration for empty space on mobile Receive tab.
class _ReceiveNetworkHeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final side = maxW.clamp(200.0, 340.0);
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isDark ? const Color(0x221E2A3A) : const Color(0xFFF3F5F8),
                border: Border.all(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      'assets/img/receive_network_hero.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CornerButtons extends StatelessWidget {
  final bool showHistoryButton;

  const _CornerButtons({
    required this.showHistoryButton,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              opacity: showHistoryButton ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: CustomIconButton(
                onPressed: () async {
                  await context.push(() => const ReceiveHistoryPage());
                },
                child: const Icon(Icons.history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final ReceiveTabVm vm;

  const _InfoBox(this.vm);

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      crossFadeState: vm.showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      firstChild: Container(),
      secondChild: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.alias),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 30),
                        child: SelectableText(vm.serverState?.alias ?? '-'),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.ip),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vm.localIps.isEmpty) Text(t.general.unknown),
                          ...vm.localIps.map((ip) => SelectableText(ip)),
                        ],
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.port),
                      const SizedBox(width: 10),
                      SelectableText(vm.serverState?.port.toString() ?? '-'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
