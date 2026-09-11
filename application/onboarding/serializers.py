"""Django REST Framework serializer with exact limits.

Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
"""

from datetime import date
from rest_framework import serializers

from .dcyn import ALLOWED_REGIONS, ALLOWED_SUPPORT_TYPES, BinaryChoice, evaluate


class StrictSerializer(serializers.Serializer):
    """Reject undeclared input fields so schema drift cannot pass silently."""

    def to_internal_value(self, data):
        if not isinstance(data, dict):
            raise serializers.ValidationError("Expected a JSON object.")
        unknown = sorted(set(data) - set(self.fields))
        if unknown:
            raise serializers.ValidationError(
                {
                    "unknown_fields": f"Undeclared fields are forbidden: {', '.join(unknown)}"
                }
            )
        return super().to_internal_value(data)


class StudentOnboardingSerializer(StrictSerializer):
    schema_version = serializers.ChoiceField(choices=["1.0"])
    event_id = serializers.UUIDField()
    submitted_at = serializers.DateTimeField()
    student_full_name = serializers.RegexField(
        r"^[A-Za-z][A-Za-z .'-]{1,79}$", min_length=2, max_length=80
    )
    date_of_birth = serializers.DateField()
    guardian_email = serializers.EmailField(max_length=254)
    learner_region = serializers.ChoiceField(choices=sorted(ALLOWED_REGIONS))
    guardian_consent = serializers.BooleanField()
    support_required = serializers.BooleanField()
    support_type = serializers.ChoiceField(
        choices=sorted(ALLOWED_SUPPORT_TYPES), allow_null=True, required=False
    )
    notes = serializers.CharField(
        max_length=500, allow_blank=True, required=False, trim_whitespace=True
    )

    def validate_date_of_birth(self, value: date) -> date:
        today = date.today()
        age = (
            today.year
            - value.year
            - ((today.month, today.day) < (value.month, value.day))
        )
        if not 3 <= age <= 21:
            raise serializers.ValidationError(
                "Learner age must be between 3 and 21 years inclusive."
            )
        return value

    def validate_guardian_consent(self, value: bool) -> bool:
        if value is not True:
            raise serializers.ValidationError("Explicit guardian consent is required.")
        return value

    def validate(self, attrs):
        required = attrs["support_required"]
        support_type = attrs.get("support_type")
        if required and support_type is None:
            raise serializers.ValidationError(
                {"support_type": "Required when support_required is true."}
            )
        if not required and support_type is not None:
            raise serializers.ValidationError(
                {"support_type": "Must be null when support_required is false."}
            )
        decisions = evaluate(attrs)
        failures = [
            decision for decision in decisions if decision.answer is BinaryChoice.NO
        ]
        if failures:
            raise serializers.ValidationError(
                {item.code: item.reason for item in failures}
            )
        attrs["dcyn_decisions"] = {item.code: item.answer.value for item in decisions}
        return attrs
