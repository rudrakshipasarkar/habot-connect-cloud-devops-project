"""Pure mapping functions for the validated Pub/Sub event.

Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
"""

from __future__ import annotations
import json
from typing import Any

BIGQUERY_FIELDS = (
    "schema_version",
    "event_id",
    "submitted_at",
    "student_full_name",
    "date_of_birth",
    "guardian_email",
    "learner_region",
    "guardian_consent",
    "support_required",
    "support_type",
    "notes",
)


def to_pubsub_bytes(validated_data: dict[str, Any]) -> bytes:
    optional = {"support_type", "notes"}
    missing = [
        field
        for field in BIGQUERY_FIELDS
        if field not in validated_data and field not in optional
    ]
    if missing:
        raise ValueError(
            f"Validated payload is missing required fields: {', '.join(missing)}"
        )
    event = {field: validated_data.get(field) for field in BIGQUERY_FIELDS}
    return json.dumps(event, separators=(",", ":"), sort_keys=True, default=str).encode(
        "utf-8"
    )
