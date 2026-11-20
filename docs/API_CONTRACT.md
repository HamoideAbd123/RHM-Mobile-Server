# Mobile-to-RHM API contract

## Connection

- Base URL for the current same-device profile: `http://127.0.0.1:8000`.
- Authentication: `Authorization: Bearer <RHM_API_TOKEN>` for protected routes.
- The token is entered by the user and saved by the app in Android secure storage.
- Backend loopback restrictions and authentication remain authoritative. The mobile app must not bypass them.

## Current mobile feature routes

The Flutter client uses the existing backend operations for:

| Capability | API surface |
|---|---|
| Connection readiness | `GET /mobile/health` |
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

## In-app update proxy

The current client uses:

- `GET /mobile/updates/latest`
- `GET /mobile/updates/assets/{asset_id}`

These are authenticated backend proxy routes. The backend validates release asset identity and downloads the APK and checksum. The current implementation was designed around private release metadata from `rhm-personal-ai-core`.

Before public releases are consumed by installed devices, update proxy configuration must explicitly identify this repository as the allowed release source. The backend must validate the repository, release channel/tag and asset names rather than trusting arbitrary URLs supplied by the app.

## Transport boundary

HTTP is allowed only for the same-device loopback profile. Do not reuse the URL on Wi-Fi or the public Internet. A remote profile requires HTTPS, secure session/device identity, authorization scoping, replay protection where applicable, and a separate security review.
