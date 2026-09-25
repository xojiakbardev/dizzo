from app.core.security import create_access_token, decode_token, hash_password, verify_password


def test_password_hash_round_trip() -> None:
    password_hash = hash_password("correct horse battery staple")
    assert password_hash != "correct horse battery staple"
    assert verify_password("correct horse battery staple", password_hash)
    assert not verify_password("wrong password", password_hash)


def test_access_token_contains_user_id() -> None:
    token = create_access_token(42)
    assert decode_token(token) == 42
    assert decode_token(token, expected_type="refresh") is None
