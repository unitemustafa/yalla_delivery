import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/auth_session.dart';

typedef AuthenticatedImageLoader = Future<Uint8List> Function(String url);

/// Loads private API media with the current Bearer-token session.
class AuthenticatedNetworkImage extends StatefulWidget {
  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    required this.placeholderAsset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.loader,
  });

  final String? url;
  final String placeholderAsset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;
  final AuthenticatedImageLoader? loader;

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState extends State<AuthenticatedNetworkImage> {
  Future<Uint8List>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _prepareImage();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.loader != widget.loader) {
      _prepareImage();
    }
  }

  void _prepareImage() {
    final url = widget.url?.trim() ?? '';
    _imageFuture = url.isEmpty
        ? null
        : (widget.loader ?? AuthSession.instance.getBytes)(url);
  }

  @override
  Widget build(BuildContext context) {
    final future = _imageFuture;
    if (future == null) return _placeholder();

    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            semanticLabel: widget.semanticLabel,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        }
        if (snapshot.hasError) return _placeholder();
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget _placeholder() {
    return Image.asset(
      widget.placeholderAsset,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      semanticLabel: widget.semanticLabel,
    );
  }
}
