#!/usr/bin/env bash
set -euo pipefail
# Shared by the apply-fixes cases: a tiny Python user service with unittest
# tests and one commit. Sourced by each case's fixture.sh.
git init -q
git config user.name "Dev"
git config user.email "dev@example.com"
echo "__pycache__/" > .gitignore

cat > store.py <<'PY'
class UserStore:
    def __init__(self):
        self._users = {}

    def save(self, user_id, email):
        self._users[user_id] = {"id": user_id, "email": email.lower()}

    def find_by_email(self, email):
        email = email.lower()
        return next((u for u in self._users.values() if u["email"] == email), None)
PY

cat > service.py <<'PY'
from store import UserStore


class UserService:
    def __init__(self, store: UserStore):
        self.store = store

    def register(self, user_id, email, notify=False, retries=3, timeout=30):
        if self.store.find_by_email(email):
            raise ValueError("email taken")
        self.store.save(user_id, email)

    def find_by_email(self, email):
        return self.store.find_by_email(email)
PY

cat > app.py <<'PY'
from service import UserService
from store import UserStore

service = UserService(UserStore())


def signup(user_id, email):
    service.register(user_id, email)
    return service.find_by_email(email)
PY

cat > test_users.py <<'PY'
import unittest

from app import signup
from service import UserService
from store import UserStore


class UsersTest(unittest.TestCase):
    def test_signup_returns_user(self):
        self.assertEqual(signup(1, "A@x.io")["email"], "a@x.io")

    def test_duplicate_email_rejected_case_insensitively(self):
        s = UserService(UserStore())
        s.register(1, "a@x.io")
        with self.assertRaises(ValueError):
            s.register(2, "A@X.io")


if __name__ == "__main__":
    unittest.main()
PY

perl -pi -e 's/return service\.find_by_email\(email\)$/return service.find_by_email(email)["user"]/' app.py
git add -A && git commit -qm "user service"
