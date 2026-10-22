import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/ui/widgets/common.dart';

void main() {
  testWidgets('noavatar.svg 使用内置默认头像', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Avatar(
            url: 'https://pc.sysbbs.com/data/avatar/noavatar.svg',
            name: '张三',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, defaultAvatarAsset);
  });

  testWidgets('没有头像地址时使用内置默认头像', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Avatar(name: '李四')),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, defaultAvatarAsset);
  });
}
