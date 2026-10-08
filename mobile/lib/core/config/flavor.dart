enum AppFlavor {
  dev,
  staging,
  prod,
}

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.cdnBaseUrl,
    required this.enableLogging,
  });

  final AppFlavor flavor;
  final String appName;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String cdnBaseUrl;
  final bool enableLogging;

  bool get isDev => flavor == AppFlavor.dev;
  bool get isStaging => flavor == AppFlavor.staging;
  bool get isProd => flavor == AppFlavor.prod;

  static AppConfig? _instance;
  static AppConfig get instance => _instance!;

  static void initialize(AppConfig config) {
    _instance = config;
  }
}
