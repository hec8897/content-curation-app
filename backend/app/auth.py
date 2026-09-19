import logging
import os
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient, PyJWKClientError
from sqlalchemy.orm import Session

from .db import get_db
from .models import User

# ponytail: 개발용 고정 시크릿. 배포할 땐 JWT_SECRET을 환경변수로 반드시 주입한다.
SECRET = os.environ.get("JWT_SECRET", "dev-only-secret-do-not-deploy")
ALGORITHM = "HS256"

# ponytail: 30일 액세스 토큰 하나. 리프레시·회전·서버측 폐기가 없어서 유출되면 만료까지 유효하다.
# 실사용자가 붙으면 짧은 액세스 토큰 + 리프레시 회전으로 올린다.
TOKEN_TTL = timedelta(days=30)

BCRYPT_MAX_BYTES = 72

# Google ID 토큰의 aud로 기대하는 값. **웹** 클라이언트 ID이며 비밀값이 아니다 —
# 앱 바이너리에 그대로 들어가는 공개 식별자다. Flutter의 googleServerClientId와 같아야 한다.
GOOGLE_CLIENT_ID = os.environ.get(
    "GOOGLE_CLIENT_ID",
    "725501602680-sev9pma2r0nvr2h5n34bk6k5sjgt7920.apps.googleusercontent.com",
)

_bearer = HTTPBearer(auto_error=False)
_unauthorized = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="인증이 필요합니다",
    headers={"WWW-Authenticate": "Bearer"},
)


def hash_password(raw: str) -> str:
    return bcrypt.hashpw(raw.encode(), bcrypt.gensalt()).decode()


def verify_password(raw: str, hashed: str | None) -> bool:
    # Google로만 가입한 계정은 password_hash가 없다. 비밀번호 로그인을 시도하면 그냥 실패다.
    if hashed is None:
        return False
    return bcrypt.checkpw(raw.encode(), hashed.encode())


# ponytail: google-auth 라이브러리를 안 쓴다. PyJWT의 PyJWKClient가 이미 있고 서명 검증에
# 필요한 게 그것뿐이다. 대신 Google 특유의 조건(iss 두 형태, email_verified)은 직접 확인한다.
_google_jwks = PyJWKClient("https://www.googleapis.com/oauth2/v3/certs")

# Google은 두 형태를 모두 발급한다. jwt.decode의 issuer 인자는 문자열 하나만 받아서 직접 검사한다.
_GOOGLE_ISSUERS = frozenset({"accounts.google.com", "https://accounts.google.com"})

_bad_google_token = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED, detail="Google 토큰을 검증할 수 없습니다"
)

_log = logging.getLogger("curator.google_auth")


def _log_rejection(id_token: str, exc: Exception) -> None:
    """거절 이유를 남긴다. 검증에 실패한 토큰은 내용을 신뢰할 수 없으므로 진단용으로만 쓴다.

    이 로그가 없으면 401의 원인(aud 불일치·만료·서명)을 구분할 방법이 없다.
    """
    try:
        unverified = jwt.decode(id_token, options={"verify_signature": False})
        detail = f"aud={unverified.get('aud')} iss={unverified.get('iss')}"
    except jwt.PyJWTError:
        detail = "디코딩 불가 (JWT 형식이 아님)"
    _log.warning("Google ID 토큰 거절: %s / %s: %s", detail, type(exc).__name__, exc)


def verify_google_id_token(id_token: str) -> tuple[str, str]:
    """Google ID 토큰을 검증하고 (google_sub, email)을 돌려준다.

    클라이언트가 보낸 이메일을 믿으면 누구나 남의 계정으로 로그인할 수 있다.
    신뢰 경계는 여기이고, 이메일은 반드시 이 토큰에서만 꺼낸다.
    """
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "GOOGLE_CLIENT_ID가 비어 있어 Google 로그인을 처리할 수 없습니다",
        )
    try:
        signing_key = _google_jwks.get_signing_key_from_jwt(id_token)
        claims = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=GOOGLE_CLIENT_ID,
            options={"require": ["exp", "iat", "sub", "aud", "iss"]},
        )
    except (jwt.PyJWTError, PyJWKClientError) as exc:
        _log_rejection(id_token, exc)
        raise _bad_google_token

    if claims["iss"] not in _GOOGLE_ISSUERS:
        raise _bad_google_token
    # 미인증 이메일을 받아주면 남의 이메일로 계정을 선점할 수 있다.
    if not claims.get("email_verified") or not claims.get("email"):
        raise _bad_google_token
    return claims["sub"], claims["email"].lower()


def create_token(user_id: uuid.UUID) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"sub": str(user_id), "iat": now, "exp": now + TOKEN_TTL},
        SECRET,
        algorithm=ALGORITHM,
    )


def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if creds is None:
        raise _unauthorized
    try:
        payload = jwt.decode(creds.credentials, SECRET, algorithms=[ALGORITHM])
        user_id = uuid.UUID(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise _unauthorized
    user = db.get(User, user_id)
    if user is None:
        raise _unauthorized
    return user
