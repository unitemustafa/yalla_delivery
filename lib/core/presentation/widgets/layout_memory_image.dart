import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Decode attachment bytes to their display size, preserving aspect ratio.
class LayoutMemoryImage extends StatelessWidget {
  const LayoutMemoryImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.errorBuilder,
  });
  final Uint8List bytes;
  final double? width, height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        int bound(double extent) => extent.isFinite && extent > 0
            ? (extent * ratio).round().clamp(1, 2048)
            : 2048;
        return Image(
          image: ResizeImage(
            MemoryImage(bytes),
            width: bound(constraints.maxWidth),
            height: bound(constraints.maxHeight),
            policy: ResizeImagePolicy.fit,
          ),
          fit: fit,
          alignment: alignment,
          semanticLabel: semanticLabel,
          gaplessPlayback: true,
          errorBuilder: errorBuilder,
        );
      },
    ),
  );
}
