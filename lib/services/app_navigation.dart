import 'dart:async';

import 'package:flutter/material.dart';

import 'service_locator.dart';

/// Shared navigation helpers for cloud-only high-value paths.
///
/// Uses [AppServices] (not `main.dart`) so pages can import this without
/// creating service ↔ UI circular imports.
abstract final class AppNavigation {
  /// Bottom-nav index of the 爱车 (vehicle / control) tab.
  static const vehicleTabIndex = 1;

  /// Pop to the root shell, switch to the vehicle tab, and optionally refresh.
  ///
  /// Used after login success / select-vehicle so the user lands on bound or
  /// unbound home without tapping back repeatedly.
  static void returnToVehicleHome(
    BuildContext context, {
    bool refresh = true,
  }) {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((route) => route.isFirst);
    AppServices.instance.homeTabIndex.value = vehicleTabIndex;
    final cloud = AppServices.instance.officialCloudService;
    if (refresh && cloud.state.signedIn) {
      unawaited(
        cloud.refreshVehicles(silent: true, force: true),
      );
    }
  }

  /// After sign-out, keep the user on the vehicle tab (unbound / needLogin).
  static void focusVehicleTabAfterSignOut() {
    AppServices.instance.homeTabIndex.value = vehicleTabIndex;
  }
}
