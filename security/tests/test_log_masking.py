import logging

from unirent_security.log_masking import MaskingFilter, mask_text


def _record(msg, *args, **extra) -> logging.LogRecord:
    record = logging.LogRecord("t", logging.INFO, __file__, 1, msg, args, None)
    for key, value in extra.items():
        setattr(record, key, value)
    MaskingFilter().filter(record)
    return record


def test_emails_phones_and_tokens_are_masked():
    text = mask_text(
        "asha@college.edu called +919876543210 with Bearer abc.def.ghi and "
        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl"
    )
    assert "asha@" not in text and "a••••@college.edu" in text
    assert "9876543210" not in text and "3210" in text
    assert "abc.def.ghi" not in text and "eyJ" not in text


def test_extra_fields_and_args_are_masked():
    record = _record(
        "login for %s",
        "ravi@college.edu",
        password="hunter2-secret",
        body={"hostel_name": "Ganga", "room_number": "214", "title": "Camera"},
        phone="9876543210",
    )
    assert "ravi@" not in record.getMessage()
    assert record.password == "[redacted]"
    assert record.body == {
        "hostel_name": "[redacted]",
        "room_number": "[redacted]",
        "title": "Camera",
    }
    assert record.phone.endswith("3210") and "98765" not in record.phone


def test_ordinary_numbers_are_left_alone():
    assert mask_text("booked 3 items for 24 hours, total 30000 paise") == (
        "booked 3 items for 24 hours, total 30000 paise"
    )
