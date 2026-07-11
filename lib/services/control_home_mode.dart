/// Explicit modes for the 爱车 (vehicle) home shell.
///
/// Replaces the coarse `showUnboundHome` bool so the control page can render
/// loading / need-login / unbound / bound without flashing the wrong shell.
enum ControlHomeMode {
  /// Session restore or first vehicle pull with nothing to show yet.
  loading,

  /// Not signed in and no local/cloud vehicle available.
  needLogin,

  /// Signed in (or otherwise resolved) but no usable current vehicle.
  unbound,

  /// Local garage vehicle and/or cloud selected vehicle is available.
  bound,
}

/// Pure resolver for [ControlHomeMode] — easy to unit-test without Flutter.
class ControlHomeModeResolver {
  const ControlHomeModeResolver._();

  static ControlHomeMode resolve({
    required bool signedIn,
    required bool hasLocalVehicle,
    required bool hasCloudVehicle,
    required bool cloudLoading,
  }) {
    final bound = hasLocalVehicle || (signedIn && hasCloudVehicle);
    if (bound) return ControlHomeMode.bound;
    if (cloudLoading && !hasLocalVehicle && !hasCloudVehicle) {
      return ControlHomeMode.loading;
    }
    if (!signedIn) return ControlHomeMode.needLogin;
    return ControlHomeMode.unbound;
  }
}
