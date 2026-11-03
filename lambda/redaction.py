def normalize_comprehend(aws_entities: list[dict]) -> list[dict]:
    """Map Comprehend Medical's response shape onto neutral start/end/type keys.
    Comprehend Medical's response shape is a bit more complex than we need for
    redaction, and we want to be able to unit test the redaction logic without
    having to mock the AWS API.
    """
    return [
        {"start": e["BeginOffset"], "end": e["EndOffset"], "type": e["Type"]}
        for e in aws_entities
    ]


def merge_spans(entities: list[dict]) -> list[dict]:
    """Collapse overlapping spans so no covered character survives.
 
    Discarding an overlapping span instead would leave the part of it that
    extends past its neighbour unredacted — under-redaction, which is the
    failure mode that actually matters here.
    """
    merged: list[dict] = []

    for entity in sorted(entities, key=lambda e: e["start"]):
        if merged and entity["start"] < merged[-1]["end"]:
            previous = merged[-1]
            previous["end"] = max(previous["end"], entity["end"])
            if previous["type"] != entity["type"]:
                # A span covering two entity types can't honestly claim either.
                previous["type"] = "PHI"
        else:
            merged.append(dict(entity))

    return merged


def redact(text: str, entities: list[dict]) -> str:
    """Replace each span with [REDACTED-{TYPE}].
 
    Expects neutral keys: start, end, type. Replacement runs back to front so
    that every edit leaves the offsets of earlier spans still valid.
    """
    for entity in sorted(merge_spans(entities), key=lambda e: e["start"], reverse=True):
        replacement = f"[REDACTED-{entity['type']}]"
        text = text[: entity["start"]] + replacement + text[entity["end"] :]

    return text