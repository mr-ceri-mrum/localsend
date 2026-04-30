import 'dart:async';

import 'package:localsend_app/pages/first_alias_setup_page.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// Replaces the entire navigator stack with the app root (same approach as [SendNotifier]
/// when resetting after an empty receiver selection). Avoids `popUntil` + route-name
/// mismatches that can leave a blank [RouterinoHome] shell or an empty route.
void replaceNavigatorStackWithAppRoot({required HomeTab homeTab}) {
  final ctx = Routerino.navigatorKey.currentContext;
  if (ctx == null) {
    return;
  }

  final requiresAlias = !RefenaScope.defaultRef.read(persistenceProvider).isAliasSetupCompleted();
  if (requiresAlias) {
    unawaited(ctx.pushRootImmediately(() => const FirstAliasSetupPage()));
  } else {
    unawaited(ctx.pushRootImmediately(() => HomePage(initialTab: homeTab, appStart: false)));
  }
}
