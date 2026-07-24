String _resolveApiBaseUrl() {
  const envValue = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (envValue.isNotEmpty) return envValue;
  return 'https://api.topshirdi.uz';
}

final String apiBaseUrl = _resolveApiBaseUrl();
const String sessionStorageKey = 'road_test_session';
