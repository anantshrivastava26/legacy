import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models.dart';

class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();

  User? user;
  List<FamilySummary> families = [];
  bool initializing = true;

  bool get isLoggedIn => user != null;

  Future<void> init() async {
    await api.loadTokens();
    if (api.hasSession) {
      try {
        final res = await api.get('/api/auth/me');
        user = User.fromJson(res['user']);
        await refreshFamilies();
      } catch (_) {
        await api.clearTokens();
      }
    }
    initializing = false;
    notifyListeners();
  }

  Future<void> register(
      String displayName, String email, String password) async {
    final res = await api.post('/api/auth/register', {
      'displayName': displayName,
      'email': email,
      'password': password,
    });
    await api.saveTokens(res['accessToken'], res['refreshToken']);
    user = User.fromJson(res['user']);
    await refreshFamilies();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    await api.saveTokens(res['accessToken'], res['refreshToken']);
    user = User.fromJson(res['user']);
    await refreshFamilies();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.clearTokens();
    user = null;
    families = [];
    notifyListeners();
  }

  Future<void> refreshFamilies() async {
    final res = await api.get('/api/families');
    families = (res['families'] as List)
        .map((e) => FamilySummary.fromJson(e))
        .toList();
    notifyListeners();
  }

  Future<FamilySummary> createFamily(String name, String? description) async {
    await api.post('/api/families', {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    await refreshFamilies();
    return families.last;
  }

  Future<void> joinFamily(String inviteCode) async {
    await api.post('/api/families/join', {'inviteCode': inviteCode});
    await refreshFamilies();
  }
}
