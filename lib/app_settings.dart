class AppSettings {
  final String appName;
  final String? logoUrl;
  final String? email;
  final String? phone;

  const AppSettings({
    this.appName = 'My Admin App',
    this.logoUrl,
    this.email,
    this.phone,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      appName: map['appName'] as String? ?? 'My Admin App',
      logoUrl: map['logoUrl'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'logoUrl': logoUrl,
      'email': email,
      'phone': phone,
    };
  }
}