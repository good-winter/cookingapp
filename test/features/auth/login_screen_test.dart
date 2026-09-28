// test/features/auth/login_screen_test.dart

import 'package:cooking_app/core/network/api_exception.dart';
import 'package:cooking_app/core/storage/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_test_harness.dart';
import '../../helpers/fake_cooking_api.dart';

/// 两个输入框：0 是手机号，1 是验证码（与登录页里的顺序一致）。
Finder get _phoneField => find.byType(TextField).at(0);
Finder get _codeField => find.byType(TextField).at(1);

/// 按钮的 onPressed：null 表示不可点。
///
/// 按类型找而不是按文案：倒计时期间按钮文案会变成「60s 后重发」，
/// 提交期间会变成转圈 —— 按文案找会在这些状态下找不到按钮，
/// 而恰恰是这些状态最需要断言。
/// 登录页上 TextButton 只有「获取验证码」一个、ElevatedButton 只有「登录」一个。
VoidCallback? _sendButtonAction(WidgetTester tester) =>
    tester.widget<TextButton>(find.byType(TextButton)).onPressed;

VoidCallback? _submitButtonAction(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed;

Future<void> _fillPhone(WidgetTester tester, String phone) async {
  await tester.enterText(_phoneField, phone);
  await tester.pump();
}

Future<void> _fillCode(WidgetTester tester, String code) async {
  await tester.enterText(_codeField, code);
  await tester.pump();
}

void main() {
  group('路由守卫', () {
    testWidgets('未登录时停在登录页，且没有底部导航栏', (tester) async {
      await pumpApp(tester, signedIn: false);

      expect(find.text('手机号登录'), findsOneWidget);
      // 登录页注册在 ShellRoute **之外** —— 它不该有底部 Tab。
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    // 反方向也要守：否则冷启动带着会话时会先渲染登录页再跳走，闪一下。
    testWidgets('已登录时直接进主界面，不经过登录页', (tester) async {
      await pumpApp(tester);

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('手机号登录'), findsNothing);
    });
  });

  group('获取验证码', () {
    testWidgets('手机号不合法时按钮不可点', (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '12345');
      expect(_sendButtonAction(tester), isNull, reason: '手机号不合法就不该能点');

      await _fillPhone(tester, '13900000001');
      expect(_sendButtonAction(tester), isNotNull, reason: '合法手机号应可点');

      expect(api.sendSmsCodeCalls, 0, reason: '只改输入框不该发请求');
    });

    testWidgets('发送成功后按钮进入倒计时，秒数取自服务端的 retryAfterSeconds',
        (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '13900000001');
      await tester.tap(find.text('获取验证码'));
      await tester.pump();

      expect(api.sendSmsCodeCalls, 1);
      // FakeCookingApi 返回 60，倒计时应从它开始而不是某个硬编码常量。
      expect(find.text('60s 后重发'), findsOneWidget);
      expect(_sendButtonAction(tester), isNull, reason: '倒计时期间不可重发');

      // 走一秒，读数是活的。
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('59s 后重发'), findsOneWidget);

      // 让倒计时跑完，避免 Timer 泄漏影响后续断言。
      await tester.pump(const Duration(seconds: 60));
    });

    // 后端跑在 development 下会回显验证码。常驻显示而不是 SnackBar ——
    // SnackBar 几秒就没了，用户回头想再抄一遍反而看不到。
    testWidgets('开发模式提示只在服务端回显了 devCode 时出现', (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '13900000001');
      expect(find.textContaining('开发模式'), findsNothing, reason: '还没发就没有码');

      await tester.tap(find.text('获取验证码'));
      await tester.pump();
      expect(find.text('开发模式：验证码 123456'), findsOneWidget);

      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('生产环境（不回显 devCode）不显示开发模式提示', (tester) async {
      final api = FakeCookingApi()..devCode = null;
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '13900000001');
      await tester.tap(find.text('获取验证码'));
      await tester.pump();

      expect(find.textContaining('开发模式'), findsNothing);

      await tester.pump(const Duration(seconds: 60));
    });

    // 限流时服务端会连剩余秒数一起给。用它把按钮锁住，否则按钮立刻恢复可点，
    // 用户连点几次只是再吃几个 429。
    testWidgets('被限流时显示服务端文案，并按 retryAfterSeconds 锁住按钮',
        (tester) async {
      final api = FakeCookingApi()
        ..failNextSendCode = const ApiException(
          code: 'RATE_LIMITED',
          message: '验证码发送过于频繁，请稍后再试',
          statusCode: 429,
          details: {'retryAfterSeconds': 42},
        );
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '13900000001');
      await tester.tap(find.text('获取验证码'));
      await tester.pump();

      expect(find.text('验证码发送过于频繁，请稍后再试'), findsOneWidget);
      expect(find.text('42s 后重发'), findsOneWidget);

      await tester.pump(const Duration(seconds: 45));
    });
  });

  group('登录', () {
    testWidgets('验证码没填满时登录按钮不可点', (tester) async {
      await pumpApp(tester, api: FakeCookingApi(), signedIn: false);

      await _fillPhone(tester, '13900000001');
      await _fillCode(tester, '123');
      expect(_submitButtonAction(tester), isNull);

      await _fillCode(tester, '123456');
      expect(_submitButtonAction(tester), isNotNull);
    });

    // 文案直接取服务端下发的 message（契约保证它可直接展示），
    // 界面不按 code 分支 —— 与既有页面的做法一致。
    testWidgets('验证码错误时显示服务端文案，并留在登录页', (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '13900000001');
      await _fillCode(tester, '000000');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('验证码错误'), findsOneWidget);
      expect(find.text('手机号登录'), findsOneWidget, reason: '失败必须留在登录页');
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('登录成功后进入主界面，并把 token 落盘、装给网络层',
        (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api, signedIn: false);

      await _fillPhone(tester, '13900000001');
      await _fillCode(tester, '123456');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      // 守卫把页面换成了主界面
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('手机号登录'), findsNothing);

      expect(api.verifySmsCodeCalls, 1);
      // token 必须真的交给网络层 —— 只断言界面变了是不够的：
      // 界面变对而 token 没换，下一个请求就会以旧身份发出。
      expect(api.receivedTokens, contains('token-13900000001'));

      // 也必须落盘，否则冷启动又要重收一次验证码，登录页就白做了。
      final stored = await readStored(AuthStorage.storageKey);
      expect(stored?['token'], 'token-13900000001');
      expect(stored?['phone'], '13900000001');
    });
  });

  group('退出登录', () {
    // 退出入口在设置页最下面那张卡片里，测试视口（800×600）放不下，
    // 得先滚过去 —— 折叠区外的 ListView 子项根本没有 element，find 会返回 0 个。
    Future<void> scrollToSignOut(WidgetTester tester) async {
      await openTab(tester, Icons.settings_outlined);
      await tester.dragUntilVisible(
        find.text('退出登录'),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('设置页显示当前账号掩码与退出入口', (tester) async {
      await pumpApp(tester);
      await scrollToSignOut(tester);

      expect(find.text('138****8000'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });

    testWidgets('二次确认后回到登录页，并清掉本地会话', (tester) async {
      await pumpApp(tester);
      await scrollToSignOut(tester);

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      // 弹窗里「退出登录」既是标题也是确认按钮，这里要的是确认按钮 ——
      // 卡片里那行是 ListTile 的标题，不是 TextButton，所以不会误命中。
      await tester.tap(find.widgetWithText(TextButton, '退出登录'));
      await tester.pumpAndSettle();

      expect(find.text('手机号登录'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(await readStored(AuthStorage.storageKey), isNull);
    });

    testWidgets('取消则留在设置页，会话不动', (tester) async {
      await pumpApp(tester);
      await scrollToSignOut(tester);

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });
  });
}
