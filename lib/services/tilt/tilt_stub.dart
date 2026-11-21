/// Halli tækis er bara lesinn í vafraútgáfunni enn sem komið er.
class DeviceTilt {
  const DeviceTilt._();

  /// `true` ef vafrinn þarf leyfi notanda áður en halli er lesinn (iPhone).
  static bool get needsPermission => false;

  static bool get available => false;

  static Future<bool> requestPermission() async => false;

  /// Hlustar á halla. [onTilt] fær hliðarhalla í gráðum (vinstri neikvæður).
  /// Skilar falli sem hættir að hlusta.
  static void Function() listen(void Function(double degrees) onTilt) => () {};
}
