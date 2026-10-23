import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/features/auth/presentation/views/login_view.dart';
import 'package:yalla_home/yalla_home_app.dart';

void main() {
  testWidgets(
    'courier routes, dialogs and sheets use the tablet portrait viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(const YallaHomeApp());
      expect(
        tester.getRect(find.byType(Navigator)),
        const Rect.fromLTWH(340, 0, 600, 800),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 600));
      final loginContext = tester.element(find.byType(LoginView));
      expect(MediaQuery.sizeOf(loginContext), const Size(600, 800));
      expect(Directionality.of(loginContext), TextDirection.rtl);
      expect(tester.takeException(), isNull);

      final dialogClosed = showDialog<void>(
        context: loginContext,
        builder: (context) {
          expect(MediaQuery.sizeOf(context), const Size(600, 800));
          return const AlertDialog(content: Text('Tablet dialog'));
        },
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byType(AlertDialog)).dx, 640);
      Navigator.of(loginContext).pop();
      await tester.pumpAndSettle();
      await dialogClosed;

      final sheetClosed = showModalBottomSheet<void>(
        context: loginContext,
        isScrollControlled: true,
        builder: (context) {
          expect(MediaQuery.sizeOf(context), const Size(600, 800));
          return const SizedBox(
            key: ValueKey('tablet_sheet'),
            width: double.infinity,
            height: 160,
          );
        },
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('tablet_sheet'))),
        const Rect.fromLTWH(340, 640, 600, 160),
      );
      Navigator.of(loginContext).pop();
      await tester.pumpAndSettle();
      await sheetClosed;

      tester.view.physicalSize = const Size(800, 1280);
      await tester.pump();
      expect(tester.getSize(find.byType(Navigator)), const Size(800, 1280));
      expect(MediaQuery.sizeOf(loginContext), const Size(800, 1280));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
