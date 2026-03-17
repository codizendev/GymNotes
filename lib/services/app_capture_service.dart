import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class AppCaptureService {
  AppCaptureService._();

  static final GlobalKey boundaryKey = GlobalKey(debugLabel: 'app-root-boundary');

  static Future<Uint8List?> captureScreenshotPng({double pixelRatio = 2.0}) async {
    try {
      final context = boundaryKey.currentContext;
      if (context == null) return null;

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (error, stackTrace) {
      debugPrint('Screenshot capture failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
