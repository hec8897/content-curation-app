import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// 설정값은 env.json에서 온다. 실행할 때 파일을 넘겨야 한다:
//   flutter run -d "iPhone 17" --dart-define-from-file=env.json
// 항목 설명은 env.example.json 참고. 플래그를 빼면 값이 전부 빈 문자열이 되고,
// Google 버튼이 "클라이언트 ID를 설정하면 활성화됩니다" 안내로 바뀐다.
//
// 비밀값을 감추는 장치가 아니다 — String.fromEnvironment는 컴파일 타임에 인라인되므로
// 값은 빌드된 바이너리에 그대로 들어간다. 환경별로 값을 갈아끼우기 위한 것이다.
//
// serverClientId는 **웹 애플리케이션** 클라이언트 ID여야 하고 백엔드의 GOOGLE_CLIENT_ID와
// 같아야 한다. 이 값이 ID 토큰의 aud가 되고 서버가 그걸로 검증한다.
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

// iOS에서만 쓰인다. Info.plist의 역방향 URL scheme과 짝이며, 그쪽은 네이티브 빌드
// 설정이라 env로 옮길 수 없다 — iOS 클라이언트 ID를 바꾸면 양쪽을 같이 고쳐야 한다.
const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

// 비워두면 로컬 백엔드를 본다.
// 안드로이드 에뮬레이터에서 localhost는 에뮬레이터 자신이라 호스트를 10.0.2.2로 봐야 한다.
const _apiBaseOverride = String.fromEnvironment('API_BASE');

Uri _url(String path) => Uri.parse(
  (_apiBaseOverride.isNotEmpty
          ? _apiBaseOverride
          : Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000') +
      path,
);

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 서버 응답을 해석한다. FastAPI는 오류를 `{"detail": ...}`로 돌려준다.
Map<String, dynamic> _decode(http.Response res) {
  final body = res.body.isEmpty ? const <String, dynamic>{} : jsonDecode(res.body);
  if (res.statusCode >= 400) {
    final detail = body is Map ? body['detail'] : null;
    // 422는 detail이 필드별 오류 배열이라 그대로 보여주면 읽을 수 없다.
    throw ApiException(
      detail is String ? detail : '요청을 처리할 수 없습니다 (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
  return body as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
  final res = await http.post(
    _url(path),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  return _decode(res);
}

/// `GoogleSignIn`은 authenticate 전에 딱 한 번 초기화해야 한다.
Future<void> initGoogleSignIn() async {
  if (googleServerClientId.isEmpty) return;
  await GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS && googleIosClientId.isNotEmpty ? googleIosClientId : null,
    serverClientId: googleServerClientId,
  );
}

bool get googleSignInConfigured => googleServerClientId.isNotEmpty;

class Auth extends ChangeNotifier {
  static const _tokenKey = 'curator.token';
  static const _storage = FlutterSecureStorage();

  String? _token;
  String? get token => _token;
  bool get signedIn => _token != null;

  bool _busy = false;
  bool get busy => _busy;

  Future<void> restore() async {
    _token = await _storage.read(key: _tokenKey);
    notifyListeners();
  }

  /// 로그인·가입 공통 뒤처리. 서버가 준 우리 JWT를 저장한다.
  Future<void> _accept(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _token = token;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password) => _run(() async {
    await _accept(await _post('/auth/signup', {'email': email, 'password': password}));
  });

  Future<void> signInWithEmail(String email, String password) => _run(() async {
    await _accept(await _post('/auth/login', {'email': email, 'password': password}));
  });

  /// Google 계정으로 로그인한다. 사용자가 취소하면 아무 일도 일어나지 않는다.
  ///
  /// ID 토큰 검증은 서버가 한다 — 여기서 얻은 이메일을 서버에 보내 믿게 하는 구조가 아니다.
  Future<void> signInWithGoogle() => _run(() async {
    if (!googleSignInConfigured) {
      throw ApiException('Google 클라이언트 ID가 설정되지 않았습니다');
    }
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw ApiException('Google 로그인을 완료하지 못했습니다 (${e.code.name})');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // serverClientId가 비어 있거나 잘못되면 Google이 ID 토큰을 주지 않는다.
      throw ApiException('Google이 ID 토큰을 주지 않았습니다. serverClientId 설정을 확인해주세요');
    }
    await _accept(await _post('/auth/google', {'id_token': idToken}));
  });

  Future<void> signOut() async {
    await _storage.delete(key: _tokenKey);
    if (googleSignInConfigured) {
      await GoogleSignIn.instance.signOut();
    }
    _token = null;
    notifyListeners();
  }
}

final auth = Auth();
