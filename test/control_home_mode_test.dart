import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/control_home_mode.dart';

void main() {
  group('ControlHomeModeResolver', () {
    test('bound when local vehicle exists', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: false,
          hasLocalVehicle: true,
          hasCloudVehicle: false,
          cloudLoading: false,
        ),
        ControlHomeMode.bound,
      );
    });

    test('bound when signed in with cloud vehicle', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: true,
          hasLocalVehicle: false,
          hasCloudVehicle: true,
          cloudLoading: false,
        ),
        ControlHomeMode.bound,
      );
    });

    test('bound wins over loading', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: true,
          hasLocalVehicle: false,
          hasCloudVehicle: true,
          cloudLoading: true,
        ),
        ControlHomeMode.bound,
      );
    });

    test('loading when cloud busy and no vehicle', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: true,
          hasLocalVehicle: false,
          hasCloudVehicle: false,
          cloudLoading: true,
        ),
        ControlHomeMode.loading,
      );
    });

    test('loading when unsigned, cloud busy, no local vehicle', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: false,
          hasLocalVehicle: false,
          hasCloudVehicle: false,
          cloudLoading: true,
        ),
        ControlHomeMode.loading,
      );
    });

    test('needLogin when not signed in and idle', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: false,
          hasLocalVehicle: false,
          hasCloudVehicle: false,
          cloudLoading: false,
        ),
        ControlHomeMode.needLogin,
      );
    });

    test('unbound when signed in without vehicle', () {
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: true,
          hasLocalVehicle: false,
          hasCloudVehicle: false,
          cloudLoading: false,
        ),
        ControlHomeMode.unbound,
      );
    });

    test('cloud vehicle alone without sign-in is not bound', () {
      // hasCloudVehicle is raw selectedVehicle != null; bound requires signedIn.
      expect(
        ControlHomeModeResolver.resolve(
          signedIn: false,
          hasLocalVehicle: false,
          hasCloudVehicle: true,
          cloudLoading: false,
        ),
        ControlHomeMode.needLogin,
      );
    });
  });
}
