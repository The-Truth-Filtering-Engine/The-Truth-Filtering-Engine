import 'package:flutter/material.dart';
import '../../../main.dart'; // MainShell

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  bool isLogin = true;
  bool isPasswordVisible = false;
  bool isPasswordConfirmVisible = false;

  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  final nickController = TextEditingController();
  final signupEmailController = TextEditingController();
  final signupPasswordController = TextEditingController();
  final signupPasswordConfirmController = TextEditingController();

  String? loginEmailError;
  String? loginPasswordError;

  String? nickError;
  String? signupEmailError;
  String? signupPasswordError;
  String? signupPasswordConfirmError;

  final mainColor = const Color(0xFF1D9E75);

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    nickController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    signupPasswordConfirmController.dispose();
    super.dispose();
  }

  bool get isEmailValid {
    final email = isLogin
        ? loginEmailController.text.trim()
        : signupEmailController.text.trim();
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  int get passwordStrength {
    final pw = signupPasswordController.text;
    int score = 0;
    if (pw.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
    return score;
  }

  void login() {
    setState(() {
      loginEmailError = null;
      loginPasswordError = null;
      if (loginEmailController.text.trim().isEmpty || !isEmailValid) {
        loginEmailError = '유효한 이메일을 입력해 주세요.';
      }
      if (loginPasswordController.text.isEmpty) {
        loginPasswordError = '비밀번호를 입력해 주세요.';
      }
    });

    if (loginEmailError != null || loginPasswordError != null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인 성공! 환영합니다 👋')),
    );

    // 메인 화면으로 이동 (뒤로가기 불가)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
    // TODO: Supabase 로그인 연결
  }

  void signup() {
    setState(() {
      nickError = null;
      signupEmailError = null;
      signupPasswordError = null;
      signupPasswordConfirmError = null;

      if (nickController.text.trim().isEmpty) {
        nickError = '닉네임을 입력해 주세요.';
      }
      if (signupEmailController.text.trim().isEmpty || !isEmailValid) {
        signupEmailError = '유효한 이메일을 입력해 주세요.';
      }
      if (signupPasswordController.text.length < 8) {
        signupPasswordError = '비밀번호는 8자 이상이어야 합니다.';
      }
      if (signupPasswordController.text !=
          signupPasswordConfirmController.text) {
        signupPasswordConfirmError = '비밀번호가 일치하지 않습니다.';
      }
    });

    if (nickError != null ||
        signupEmailError != null ||
        signupPasswordError != null ||
        signupPasswordConfirmError != null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원가입 완료! 이메일을 확인해 주세요.')),
    );

    setState(() => isLogin = true);
    // TODO: Supabase 회원가입 연결
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDDE7E1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logo(),
                  const SizedBox(height: 24),
                  _tabs(),
                  const SizedBox(height: 24),
                  isLogin ? _loginForm() : _signupForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: mainColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.layers_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 12),
        const Text(
          '진실의 입',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E2A24),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '광고 리뷰를 걸러내는 AI 엔진',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7A72)),
        ),
      ],
    );
  }

  Widget _tabs() {
    return Row(
      children: [
        _tabButton('로그인', true),
        _tabButton('회원가입', false),
      ],
    );
  }

  Widget _tabButton(String text, bool loginTab) {
    final selected = isLogin == loginTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isLogin = loginTab),
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? mainColor : const Color(0xFFDDE7E1),
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? mainColor : const Color(0xFF6B7A72),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Column(
      children: [
        _inputField(
          label: '이메일',
          hint: 'you@example.com',
          controller: loginEmailController,
          errorText: loginEmailError,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _inputField(
          label: '비밀번호',
          hint: '비밀번호',
          controller: loginPasswordController,
          errorText: loginPasswordError,
          obscureText: !isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF6B7A72),
            ),
            onPressed: () =>
                setState(() => isPasswordVisible = !isPasswordVisible),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('비밀번호 재설정 기능 연결 예정')),
            ),
            child: Text('비밀번호 찾기 ↗',
                style: TextStyle(color: mainColor, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 6),
        _primaryButton('로그인', login),
        const SizedBox(height: 18),
        _divider(),
        const SizedBox(height: 18),
        _googleButton(),
      ],
    );
  }

  Widget _signupForm() {
    return Column(
      children: [
        _inputField(
          label: '닉네임',
          hint: '사용할 이름',
          controller: nickController,
          errorText: nickError,
        ),
        const SizedBox(height: 14),
        _inputField(
          label: '이메일',
          hint: 'you@example.com',
          controller: signupEmailController,
          errorText: signupEmailError,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _inputField(
          label: '비밀번호',
          hint: '8자 이상',
          controller: signupPasswordController,
          errorText: signupPasswordError,
          obscureText: !isPasswordVisible,
          onChanged: (_) => setState(() {}),
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF6B7A72),
            ),
            onPressed: () =>
                setState(() => isPasswordVisible = !isPasswordVisible),
          ),
        ),
        const SizedBox(height: 8),
        _passwordStrengthBar(),
        const SizedBox(height: 14),
        _inputField(
          label: '비밀번호 확인',
          hint: '비밀번호 재입력',
          controller: signupPasswordConfirmController,
          errorText: signupPasswordConfirmError,
          obscureText: !isPasswordConfirmVisible,
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordConfirmVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: const Color(0xFF6B7A72),
            ),
            onPressed: () => setState(
                () => isPasswordConfirmVisible = !isPasswordConfirmVisible),
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton('회원가입', signup),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _divider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('또는',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7A72))),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _googleButton() {
    return OutlinedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 로그인 연결 예정')),
      ),
      icon: const Icon(Icons.g_mobiledata, size: 28),
      label: const Text('Google로 계속하기'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E2A24),
        minimumSize: const Size(double.infinity, 46),
        side: const BorderSide(color: Color(0xFFDDE7E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? errorText,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A72))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            errorText: errorText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDE7E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: mainColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE24B4A)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE24B4A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStrengthBar() {
    final score = passwordStrength;
    String label = '';
    Color color = const Color(0xFFDDE7E1);

    if (score == 1) {
      label = '약함';
      color = const Color(0xFFE24B4A);
    } else if (score == 2) {
      label = '보통';
      color = const Color(0xFFEF9F27);
    } else if (score == 3) {
      label = '강함';
      color = const Color(0xFF63B220);
    } else if (score == 4) {
      label = '매우 강함';
      color = mainColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
              4,
              (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                      decoration: BoxDecoration(
                        color: i < score ? color : const Color(0xFFDDE7E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7A72))),
        ],
      ],
    );
  }
}
