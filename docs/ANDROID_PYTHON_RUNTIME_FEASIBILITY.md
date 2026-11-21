# Android Python runtime feasibility

**Assessment date:** 2026-11-20  
**Status:** Termux/PRoot is the transitional runtime; embedded Python is not approved for production yet.

## Current backend profile

The private RHM core uses FastAPI, Uvicorn, SQLAlchemy, psycopg[binary], Alembic, Pydantic v2, pydantic-settings, cryptography and MCP. The phone deployment has run Python 3.11 inside Debian PRoot on ARM64 with PostgreSQL, using the existing backend.

## Embedded candidate: Chaquopy

Chaquopy 17.2 is a candidate for a controlled proof of concept. Its documentation lists Python 3.10–3.15, arm64-v8a, Android API 24 minimum and Android Gradle Plugin compatibility through 9.5. The Huawei target is Android 10/API 29, so the platform API floor is compatible.

This does not prove that the complete RHM dependency graph can be packaged. Native wheels must target Android/Bionic, not generic Linux aarch64. RHM includes native-extension dependencies such as pydantic-core, psycopg-binary and cryptography. A minimal FastAPI build is not proof that the full backend runs.

## Required gate before embedding the backend

A separate ARM64 test flavor must retrieve actual private backend source through a read-only CI secret (never committed) and prove:
1. reproducible Android installation of every runtime dependency;
2. imports for Pydantic/pydantic-core, SQLAlchemy, cryptography, psycopg and MCP;
3. Uvicorn serving the existing FastAPI app on 127.0.0.1:8000;
4. authenticated health and representative database-backed API calls;
5. durable database behavior without changing production data;
6. lifecycle, update/data preservation, resource use and reboot recovery on Huawei Android 10.

Do not omit unsupported dependencies or rewrite core business logic. Retain Termux/PRoot until the full dependency gate passes.

## Database and data protection

The private deployment guide identifies PostgreSQL on Termux as the preferred durable phone profile. SQLite was used for isolated tests/smoke checks, not approved as a replacement. This integration therefore does not move, convert, reset or copy PostgreSQL data.

- Keep the existing PostgreSQL cluster in Termux's private app data.
- Keep backend environment, provider keys, API token files and DB credentials private in Debian.
- Store the mobile bearer credential in Flutter secure storage and the native monitor copy as Android-Keystore AES-GCM ciphertext.
- Keep runtime logs/PID state in Termux private home with restrictive permissions.
- Do not put the DB, tokens or keystore in shared storage or this public repository.
- APK updates must not reset or migrate the database.
- A future SQLite migration requires versioned Alembic migrations, encrypted backup/restore tests, integrity checks and rollback approval.

## Conclusion

The practical profile is Flutter UI + Kotlin foreground supervisor + existing Python/FastAPI/Uvicorn in Termux Debian PRoot + existing PostgreSQL. An APK embedding the complete runtime without Termux remains a separate feasibility milestone until all native dependencies and database behavior pass ARM64 CI and Huawei device acceptance.
