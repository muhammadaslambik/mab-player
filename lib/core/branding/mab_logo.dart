import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'logo_data.dart';

final Uint8List _logoBytes = base64Decode(kLogoBase64);

/// Logo MAB-Player (tertanam di kode, tanpa aset tambahan).
class MabLogo extends StatelessWidget {
  const MabLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Image.memory(
        _logoBytes,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
}
