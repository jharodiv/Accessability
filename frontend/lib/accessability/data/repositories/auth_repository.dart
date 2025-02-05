import 'package:frontend/accessability/data/data_provider/auth_data_provider.dart';
import 'package:frontend/accessability/data/model/login_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  SharedPreferences? _sharedPrefs;
  final AuthDataProvider dataProvider;

  AuthRepository(this.dataProvider);

  //! Login
  Future<LoginModel> login(String email, String password) async {
    try {
      final data = await dataProvider.login(email, password);
      return LoginModel.fromJson(data);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }
}
