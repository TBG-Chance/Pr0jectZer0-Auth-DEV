import 'login_models.dart';

abstract interface class LoginService {
  Future<DashboardLoginChallenge> parseChallenge(String payload);

  Future<void> approve(DashboardLoginChallenge challenge);
}
