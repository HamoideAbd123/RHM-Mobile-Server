# Mobile-to-RHM API contract

## Connection

- Base URL for the current same-device profile: `http://127.0.0.1:8000`.
- Legacy authentication remains supported with `Authorization: Bearer <RHM_API_TOKEN>`.
- New device pairing issues a device-specific bearer access credential and rotating refresh credential; the master token is not stored by the Flutter client after successful pairing.
- Backend loopback restrictions and authentication remain authoritative. The mobile app must not bypass them.

## Current mobile feature routes

The Flutter client uses the existing backend operations for:

| Capability | API surface |
|---|---|
| Connection readiness | `GET /mobile/health` |
| Pairing request | `POST /mobile/pairing/requests` (loopback-only; no master bearer token) |
| Pairing completion | `POST /mobile/pairing/requests/{id}/complete` (one-time secret + Ed25519 proof) |
| Device session refresh | `POST /mobile/auth/refresh` (loopback-only; rotating refresh credential) |
| Background notification session | `POST /mobile/auth/background-session` (authenticated primary device session; isolated refresh lifecycle) |
| Legacy/simple chat path | `POST /mobile/chat` |
| Persistent conversations | `GET/POST /conversations`, `PATCH/DELETE /conversations/{id}` |
| Conversation messages | `GET/POST /conversations/{id}/messages` |
| Projects | `GET/POST /projects`, `GET /projects/{name}/context` |
| Tasks | `GET/POST /tasks`, `PATCH /tasks/{id}` |
| Memories | `GET /memories`, `GET /memories/search`, `POST /memories`, `PATCH/DELETE /memories/{id}` |
| Agent | `POST /agent` |
| Audit | `GET /audit` |
| Devices | `GET /devices`, `POST /devices/{id}/revoke` |
| MCP registry and tools | `GET /mcp-client/servers`, `GET /mcp-client/servers/{id}/tools`, `POST /mcp-client/servers/{id}/tools/{tool}` |

Exact status codes, validation rules and schemas are owned by the private backend repository. Do not duplicate server-side business rules in Kotlin. Keep client tests aligned with the backend contract.

## Model routing and external services

The mobile app sends provider/model preferences to the backend. Provider credentials remain in the protected backend environment. Cloud fallback remains opt-in and is sent as disabled by default by the current client.

MCP calls are mediated by the backend's allowlist, Tool Gateway, schema/risk policy and audit handling. The phone UI must retain explicit confirmation before an external tool invocation.

## Android app updates

The Android application updater is intentionally outside this authenticated API contract. It reads the latest stable release directly from the fixed public GitHub repository `HamoideAbd123/RHM-Mobile-Server`, validates the release tag and exact APK/checksum asset URLs, and downloads those assets over HTTPS. It does not send the local RHM bearer token to GitHub and does not require FastAPI to be running.

The authenticated API's `/server-update/*` endpoints continue to manage the Python/Next.js server runtime only. They are not used to update the Android APK.

For app releases, the updater validates the declared APK size, validates the checksum file format, streams to a temporary file with resumable HTTP Range support, verifies the final SHA-256 digest, and delegates installation to Android. Android's package installer enforces package-signing continuity. See [Release and signing](RELEASE_AND_SIGNING.md).

## Transport boundary

HTTP is allowed only for the same-device loopback profile. Pairing and refresh bootstrap routes are loopback-only and do not enable LAN/public pairing. Do not reuse the URL on Wi-Fi or the public Internet. A remote profile requires HTTPS, secure session/device identity, authorization scoping, replay protection where applicable, and a separate security review.
