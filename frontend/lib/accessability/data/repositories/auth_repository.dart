import 'package:frontend/accessability/data/data_provider/auth_data_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  SharedPreferences? _sharedPrefs;
  final AuthDataProvider dataProvider;

  AuthRepository(this.dataProvider);
}
