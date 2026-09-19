import 'package:flutter/material.dart';

import 'app.dart';
import 'data/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGoogleSignIn();
  // 저장된 토큰을 먼저 읽어야 첫 프레임에서 로그인 화면이 깜빡이지 않는다.
  await auth.restore();
  runApp(const CuratorApp());
}
