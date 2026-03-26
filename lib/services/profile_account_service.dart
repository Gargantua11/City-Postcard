import 'backend_api_client.dart';

class ProfileAccountService {
  ProfileAccountService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<void> changeUsername(String username) async {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      throw const BackendApiException('请输入用户名');
    }

    await _apiClient.put(
      '/me/username',
      body: <String, dynamic>{'username': normalized},
      requireAuth: true,
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (oldPassword.isEmpty) {
      throw const BackendApiException('请输入旧密码');
    }
    if (newPassword.isEmpty) {
      throw const BackendApiException('请输入新密码');
    }
    if (confirmPassword.isEmpty) {
      throw const BackendApiException('请确认新密码');
    }

    await _apiClient.put(
      '/me/password',
      body: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      requireAuth: true,
    );
  }
}
