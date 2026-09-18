import os
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
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

_bearer = HTTPBearer(auto_error=False)
_unauthorized = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="인증이 필요합니다",
    headers={"WWW-Authenticate": "Bearer"},
)


def hash_password(raw: str) -> str:
    return bcrypt.hashpw(raw.encode(), bcrypt.gensalt()).decode()


def verify_password(raw: str, hashed: str) -> bool:
    return bcrypt.checkpw(raw.encode(), hashed.encode())


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
