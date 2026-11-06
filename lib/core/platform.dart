import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// True di Android/iOS (aplikasi terpasang di ponsel/tablet).
final bool isMobilePlatform = Platform.isAndroid || Platform.isIOS;

enum FormFactor { phone, tablet, desktop }

/// Bentuk perangkat: ditentukan oleh platform, bukan hanya lebar jendela.
/// Desktop selalu desktop (walau jendelanya dikecilkan); ponsel selalu ponsel.
FormFactor formFactorOf(BuildContext context) {
  if (!isMobilePlatform) return FormFactor.desktop;
  return MediaQuery.sizeOf(context).shortestSide < 600
      ? FormFactor.phone
      : FormFactor.tablet;
}
