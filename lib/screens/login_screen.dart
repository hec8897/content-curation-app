import 'package:flutter/material.dart';

import '../data/api.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _attempt(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      // 서버가 안 떠 있으면 SocketException이 온다. 개발 중 가장 흔한 실패라 따로 안내한다.
      if (mounted) showToast(context, '서버에 연결할 수 없습니다. 백엔드가 실행 중인지 확인해주세요');
    }
  }

  void _submitEmail() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      showToast(context, '이메일과 비밀번호를 입력해주세요');
      return;
    }
    if (_signUp && password.length < 8) {
      showToast(context, '비밀번호는 8자 이상이어야 합니다');
      return;
    }
    _attempt(
      () => _signUp
          ? auth.signUpWithEmail(email, password)
          : auth.signInWithEmail(email, password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) {
            final busy = auth.busy;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 72),
                  Text('큐레이터', style: AppText.title3.c(AppColors.labelNormal)),
                  const SizedBox(height: 8),
                  Text(
                    '관심 키워드만 정해두면 읽을거리를 모아 보내드려요.',
                    style: AppText.body2.c(AppColors.labelAlt),
                  ),
                  const SizedBox(height: 40),

                  if (googleSignInConfigured)
                    OutlineButton(
                      label: 'Google로 계속하기',
                      leading: Image.asset('assets/google_g.png', width: 18, height: 18),
                      onTap: busy ? () {} : () => _attempt(auth.signInWithGoogle),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Google 로그인은 클라이언트 ID를 설정하면 활성화됩니다.\n'
                        'lib/data/api.dart의 googleServerClientId를 채워주세요.',
                        style: AppText.caption1.c(AppColors.labelAlt),
                      ),
                    ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.lineSolid, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('또는', style: AppText.caption1.c(AppColors.labelAssistive)),
                      ),
                      const Expanded(child: Divider(color: AppColors.lineSolid, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _Field(
                    controller: _email,
                    hint: '이메일',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _password,
                    hint: '비밀번호 (8자 이상)',
                    obscure: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: busy ? null : (_) => _submitEmail(),
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: busy ? '잠시만요…' : (_signUp ? '가입하고 시작하기' : '로그인'),
                    onTap: busy ? null : _submitEmail,
                  ),
                  const SizedBox(height: 8),
                  AppTextButton(
                    label: _signUp ? '이미 계정이 있어요' : '계정이 없어요, 가입할게요',
                    onTap: () => setState(() => _signUp = !_signUp),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
      style: AppText.body2.c(AppColors.labelNormal),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body2.c(AppColors.labelAssistive),
        filled: true,
        fillColor: AppColors.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lineSolid),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lineSolid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
