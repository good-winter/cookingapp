// lib/features/auth/screens/login_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../providers/auth_provider.dart';

/// 大陆手机号的本地校验。
///
/// 只用来决定「获取验证码」按钮亮不亮，**不是权威校验** —— 服务端那份才是
/// （前端可以被绕过）。两处保持同一套规则即可，不必共享代码：
/// 真共用了反而会把两侧的演化绑死。
final _phonePattern = RegExp(r'^1[3-9]\d{9}$');

const int _codeLength = 6;

/// 手机号 + 短信验证码登录。
///
/// 单页两个输入框，不做「先填手机号 → 下一页填验证码」的两步式：这两步之间
/// 没有任何需要用户决策的东西，拆开只会多一个页面、多一份跨页状态。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _submitting = false;
  String? _error;

  /// 后端跑在 development 下时会回显验证码；生产环境恒为 null。
  String? _devCode;

  @override
  void initState() {
    super.initState();
    // 两个输入框的内容都参与「按钮能不能点」的判定，变了就得重建。
    _phone.addListener(_onInputChanged);
    _code.addListener(_onInputChanged);
  }

  void _onInputChanged() => setState(() {});

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _phoneValid => _phonePattern.hasMatch(_phone.text);

  bool get _canSendCode => _phoneValid && _countdown == 0 && !_sending;

  bool get _canSubmit =>
      _phoneValid && _code.text.length == _codeLength && !_submitting;

  /// 倒计时。秒数一律来自服务端（正常响应的 retryAfterSeconds，
  /// 或 429 时 details 里的同一个字段），**不硬编码 60** ——
  /// 窗口是服务端定的，前端自己猜一个数就会跟限流对不上。
  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _countdown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final result =
          await ref.read(authProvider.notifier).sendSmsCode(_phone.text);
      if (!mounted) return;
      setState(() {
        _devCode = result.devCode;
        _sending = false;
      });
      _startCountdown(result.retryAfterSeconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sending = false;
      });
      // 被限流时服务端会告诉我们还剩多少秒。用它把按钮锁住，
      // 否则按钮立刻恢复可点，用户连点几次只会再吃几个 429。
      final retry = e.details['retryAfterSeconds'];
      if (e.statusCode == 429 && retry is int && retry > 0) {
        _startCountdown(retry);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(authProvider.notifier)
          .signInWithSmsCode(phone: _phone.text, code: _code.text);

      // 成功后路由守卫会自动把页面换成主界面，这里不再 setState ——
      // 此刻本 widget 正被销毁，setState 会抛异常。
      if (!mounted) return;
      if (result.isNewUser) {
        // MaterialApp 自带根 ScaffoldMessenger，所以这条提示能跨页面存活。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.loginWelcomeNew)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🍳', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text(
                  l10n.loginTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                _buildCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            // 只让数字进来：手机号里混进空格或横杠之后，本地正则不匹配，
            // 用户会觉得「按钮怎么是灰的」却看不出哪里不对。
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: InputDecoration(
              labelText: l10n.loginPhoneLabel,
              hintText: l10n.loginPhoneHint,
              prefixText: '+86 ',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_codeLength),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.loginCodeLabel,
                    hintText: l10n.loginCodeHint,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 与输入框顶部对齐：按钮比输入框矮，不修正会显得悬空。
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: _canSendCode ? _sendCode : null,
                  child: Text(
                    _countdown > 0
                        ? l10n.loginResendIn(_countdown)
                        : l10n.loginSendCode,
                  ),
                ),
              ),
            ],
          ),
          if (_devCode != null) ...[
            const SizedBox(height: 12),
            // 常驻而不是 SnackBar：SnackBar 几秒后就没了，
            // 用户回头想再抄一遍验证码时反而看不到。
            Text(
              l10n.loginDevCodeHint(_devCode!),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.loginSubmit,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
