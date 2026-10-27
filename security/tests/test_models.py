from unirent_security.models import ROLES, STATUSES, Account


def test_roles_and_statuses():
    assert ROLES == ("student", "moderator", "admin")
    assert "banned" in STATUSES
    assert Account.__table__.schema == "security"
