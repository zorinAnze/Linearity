"""Who is calling.

Posit Connect authenticates the visitor before the request reaches content,
then forwards the resulting identity in a request header. This module turns
that header into a `Principal`, so the rest of the API can attribute a run to
a person rather than trusting what the caller claims about themselves.

The header name and shape vary by Connect version and by whatever sits in
front of it, so both are configurable:

    LINEARITY_IDENTITY_HEADER   default "RStudio-Connect-Credentials"
    LINEARITY_REQUIRE_AUTH      reject unidentified callers (default off)

Confirm the header against your own deployment before relying on it: send a
request through Connect and read `GET /whoami`, which echoes back what
arrived.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any

from fastapi import HTTPException, Request

#: Connect's own header, plus the usual spellings a reverse proxy might use.
DEFAULT_IDENTITY_HEADER = "RStudio-Connect-Credentials"
FALLBACK_HEADERS = (
    "X-RStudio-Connect-Credentials",
    "X-Forwarded-User",
    "X-Auth-Request-User",
    "X-Remote-User",
)

REQUIRE_AUTH = os.environ.get("LINEARITY_REQUIRE_AUTH", "").lower() in (
    "1", "true", "yes", "on",
)
IDENTITY_HEADER = os.environ.get(
    "LINEARITY_IDENTITY_HEADER", DEFAULT_IDENTITY_HEADER
)

# Keys Connect and common proxies use for the same two facts.
_ID_KEYS = ("user", "username", "user_id", "userId", "id", "login", "sub")
_NAME_KEYS = ("name", "display_name", "displayName", "full_name", "fullName")
_GROUP_KEYS = ("groups", "group", "roles")


@dataclass(frozen=True)
class Principal:
    """An authenticated caller."""

    user_id: str
    display_name: str = ""
    groups: tuple[str, ...] = field(default_factory=tuple)
    #: Which header this came from — useful when diagnosing a deployment.
    source: str = ""

    def as_author(self) -> tuple[str, str]:
        """(name, id) for the report footer."""
        return (self.display_name or self.user_id, self.user_id)

    def summary(self) -> dict[str, Any]:
        return {
            "user_id": self.user_id,
            "display_name": self.display_name,
            "groups": list(self.groups),
            "source": self.source,
        }


def _coerce_groups(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, str):
        # Proxies tend to send a delimited string rather than a list.
        parts = [p.strip() for p in value.replace(";", ",").split(",")]
        return tuple(p for p in parts if p)
    if isinstance(value, (list, tuple)):
        return tuple(str(v) for v in value if v)
    return ()


def _first(d: dict[str, Any], keys: tuple[str, ...]) -> str:
    for k in keys:
        v = d.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
        if isinstance(v, dict):  # e.g. {"user": {"username": ...}}
            nested = _first(v, keys)
            if nested:
                return nested
    return ""


def _parse(raw: str, source: str) -> Principal | None:
    """Parse one header value: JSON if it is JSON, otherwise a bare username."""
    raw = raw.strip()
    if not raw:
        return None

    if raw.startswith("{"):
        try:
            data = json.loads(raw)
        except ValueError:
            return None
        if not isinstance(data, dict):
            return None
        # Connect nests the useful fields one level down in some versions.
        inner = data.get("user") if isinstance(data.get("user"), dict) else data
        user_id = _first(data, _ID_KEYS) or _first(inner, _ID_KEYS)
        if not user_id:
            return None
        groups: tuple[str, ...] = ()
        for key in _GROUP_KEYS:
            if key in data or key in inner:
                groups = _coerce_groups(data.get(key, inner.get(key)))
                if groups:
                    break
        return Principal(
            user_id=user_id,
            display_name=_first(data, _NAME_KEYS) or _first(inner, _NAME_KEYS),
            groups=groups,
            source=source,
        )

    # A bare username, as proxies commonly send.
    return Principal(user_id=raw, source=source)


def from_request(request: Request) -> Principal | None:
    """Resolve the caller, or None if the request carries no identity."""
    names = (IDENTITY_HEADER, *FALLBACK_HEADERS)
    for name in names:
        raw = request.headers.get(name)
        if raw:
            principal = _parse(raw, name)
            if principal:
                return principal
    return None


async def current_principal(request: Request) -> Principal | None:
    """FastAPI dependency. Enforces identity when LINEARITY_REQUIRE_AUTH is set.

    Connect authenticates before the request reaches us, so this is not the
    gate — it reads the result. Enforcement here is defence in depth, and the
    only check at all when the API is not behind Connect.
    """
    principal = from_request(request)
    if principal is None and REQUIRE_AUTH:
        raise HTTPException(
            status_code=401,
            detail=(
                "This request carries no authenticated identity. Expected it "
                f"in the '{IDENTITY_HEADER}' header, which the hosting "
                "platform should set. Call GET /whoami to see what arrived."
            ),
        )
    return principal


def resolve_author(
    principal: Principal | None, claimed_name: str, claimed_id: str
) -> tuple[str, str, str]:
    """Decide the report's author, preferring the authenticated identity.

    Returns (name, id, provenance). A caller must not be able to attribute a
    validated report to someone else, so an authenticated identity always
    wins over the submitted parameters.
    """
    if principal is not None:
        name, user_id = principal.as_author()
        return name, user_id, "authenticated"
    if claimed_name or claimed_id:
        return claimed_name, claimed_id, "claimed"
    return "", "", "none"
