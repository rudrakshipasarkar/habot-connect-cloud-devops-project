"""Deterministic Choice Yes/No validation rules.

Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from enum import Enum
import re
from typing import Any, Callable


class BinaryChoice(str, Enum):
    YES = "YES"
    NO = "NO"


@dataclass(frozen=True)
class Decision:
    code: str
    answer: BinaryChoice
    reason: str


Rule = Callable[[dict[str, Any]], Decision]
NAME_RE = re.compile(r"^[A-Za-z][A-Za-z .'-]{1,79}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
ALLOWED_REGIONS = {"UAE", "OTHER"}
ALLOWED_SUPPORT_TYPES = {
    "ACADEMIC",
    "BEHAVIOURAL",
    "COMMUNICATION",
    "MOBILITY",
    "OTHER",
}


def valid_name(payload: dict[str, Any]) -> Decision:
    value = payload.get("student_full_name", "")
    passed = isinstance(value, str) and bool(NAME_RE.fullmatch(value.strip()))
    return Decision(
        "D001",
        BinaryChoice.YES if passed else BinaryChoice.NO,
        "Name must be 2 to 80 permitted characters.",
    )


def valid_date_of_birth(payload: dict[str, Any]) -> Decision:
    try:
        born = date.fromisoformat(str(payload.get("date_of_birth", "")))
        today = date.today()
        age = (
            today.year - born.year - ((today.month, today.day) < (born.month, born.day))
        )
        passed = 3 <= age <= 21
    except ValueError:
        passed = False
    return Decision(
        "D002",
        BinaryChoice.YES if passed else BinaryChoice.NO,
        "Learner age must be between 3 and 21 years inclusive.",
    )


def valid_guardian_email(payload: dict[str, Any]) -> Decision:
    value = payload.get("guardian_email", "")
    passed = (
        isinstance(value, str) and len(value) <= 254 and bool(EMAIL_RE.fullmatch(value))
    )
    return Decision(
        "D003",
        BinaryChoice.YES if passed else BinaryChoice.NO,
        "Guardian email must be syntactically valid and at most 254 characters.",
    )


def valid_region(payload: dict[str, Any]) -> Decision:
    passed = payload.get("learner_region") in ALLOWED_REGIONS
    return Decision(
        "D004",
        BinaryChoice.YES if passed else BinaryChoice.NO,
        "Region must be UAE or OTHER.",
    )


def valid_consent(payload: dict[str, Any]) -> Decision:
    passed = payload.get("guardian_consent") is True
    return Decision(
        "D005",
        BinaryChoice.YES if passed else BinaryChoice.NO,
        "Explicit guardian consent must equal true.",
    )


def valid_support(payload: dict[str, Any]) -> Decision:
    required = payload.get("support_required")
    support_type = payload.get("support_type")
    passed = isinstance(required, bool) and (
        (required and support_type in ALLOWED_SUPPORT_TYPES)
        or (not required and support_type is None)
    )
    return Decision(
        "D006",
        BinaryChoice.YES if passed else BinaryChoice.NO,
        "Support type is required exactly when support_required is true.",
    )


RULES: tuple[Rule, ...] = (
    valid_name,
    valid_date_of_birth,
    valid_guardian_email,
    valid_region,
    valid_consent,
    valid_support,
)


def evaluate(payload: dict[str, Any]) -> tuple[Decision, ...]:
    return tuple(rule(payload) for rule in RULES)


def accepted(payload: dict[str, Any]) -> bool:
    return all(decision.answer is BinaryChoice.YES for decision in evaluate(payload))
