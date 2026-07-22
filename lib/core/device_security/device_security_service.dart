import 'device_security_models.dart';

abstract interface class DeviceSecurityService {
  DeviceSecurityReport? get currentReport;
  Stream<DeviceSecurityReport> get reportChanges;
  Future<void> initialize();
  Future<DeviceSecurityReport> refresh();
  Future<void> dispose();
}
