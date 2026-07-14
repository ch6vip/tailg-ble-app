import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/add_vehicle_page.dart';
import '../pages/login_page.dart';
import '../services/official_cloud_service.dart';
import '../services/service_locator.dart';
import 'app_snack.dart';

/// Gate for vehicle-dependent features (location / battery / settings / …).
///
/// Returns `true` when the user is signed in and has a selected cloud vehicle.
/// Otherwise shows a snack and immediately navigates to login or add-vehicle
/// (no snack action — avoids double navigation).
bool requireCloudVehicle(
  BuildContext context, {
  bool offerLogin = true,
  bool offerAddVehicle = true,
  String? message,
}) {
  final state = AppServices.instance.officialCloudService.state;
  if (state.signedIn && state.selectedVehicle != null) {
    return true;
  }

  if (!state.signedIn) {
    AppSnack.info(context, message ?? OfficialCloudMessages.signInRequired);
    if (offerLogin) {
      unawaited(
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
      );
    }
    return false;
  }

  AppSnack.info(context, message ?? '暂无车辆，请先同步官方车辆');
  if (offerAddVehicle) {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AddVehiclePage())),
    );
  }
  return false;
}

/// Push [page] after an optional [requireCloudVehicle] gate.
///
/// Shared by control home service cards and the service hub grid.
void openCloudGatedPage(
  BuildContext context,
  Widget page, {
  bool requireVehicle = true,
}) {
  if (requireVehicle && !requireCloudVehicle(context)) return;
  unawaited(
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
  );
}
