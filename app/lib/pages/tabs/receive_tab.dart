import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab_vm.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ReceiveTab extends StatelessWidget {
  const ReceiveTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(receiveTabVmProvider);
    return _MobileReceiveLayout(vm: vm);
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
