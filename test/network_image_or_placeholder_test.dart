import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/constants/app_assets.dart';
import 'package:yalla_home/core/presentation/widgets/network_image_or_placeholder.dart';

void main() {
  testWidgets('placeholder decoding preserves its aspect ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkImageOrPlaceholder(
          url: null,
          placeholderAsset: AppAssets.defaultProduct,
          width: 100,
          height: 60,
          fit: BoxFit.contain,
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.policy, ResizeImagePolicy.fit);
    expect(provider.width, 200);
    expect(provider.height, 120);
    expect(image.fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });
}
