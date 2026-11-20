# RHM Mobile Server

Android background-runtime integration for the existing RHM Flutter application.

## Goal

Turn the existing RHM mobile app into a phone-hosted RHM node: Flutter remains the user interface, Kotlin owns Android lifecycle/background-service integration, and the existing Python FastAPI + Uvicorn backend remains the application server.

This repository is being initialized as an integration workspace. It does **not** yet contain a verified runnable Android app or a downloadable APK.

## Architecture decision

- **Flutter:** existing RHM mobile UI; do not create a duplicate app.
- **Kotlin (Android):** foreground service, boot handling, notifications, runtime supervision and Flutter platform-channel bridge.
- **Python / FastAPI / Uvicorn:** preserve the existing backend and API contracts.
- **Storage:** preserve existing RHM data; define backup/restore before migration.
- **Termux/Debian:** development and compatibility reference only during the transition. Standalone Python runtime is a separate feasibility milestone, not an assumed capability.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/ROADMAP.md](docs/ROADMAP.md), and [docs/STATUS.md](docs/STATUS.md).

## Source project

The current RHM core and Flutter app live in the separate repository:
https://github.com/HamoideAbd123/rhm-personal-ai-core

The source repository is private. Before CI can build this app from this public repository, the mobile source must be deliberately mirrored/copied here or a narrowly scoped, read-only access strategy must be configured. Never place personal API tokens, signing keys, or production secrets in this public repository.

## Build status

No APK is published yet. A successful GitHub repository creation is not a successful app build. The first milestone is to import and inspect the existing Flutter project, then add a reproducible Android build workflow and tests.

## Security

- Do not commit `.env`, API tokens, passwords, private keys, keystores, production databases, or personal backups.
- Do not expose the local server to the public internet without authentication and a secure transport layer.
- Keep the backend bound to loopback by default until authenticated LAN access is implemented and tested.
