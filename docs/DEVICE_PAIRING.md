# Mobile device pairing

This client supports a one-time, owner-approved pairing flow for the same-phone RHM deployment.

## First pairing

1. In RHM, open **Connection settings** and choose **Secure pairing without the master token**.
2. Keep the pairing dialog open. It displays a short code and a QR representation of that code.
3. Switch to Termux and run `rhm device approve`. Enter the code at the hidden prompt. The code is not placed in shell history.
4. Return to RHM and tap **Check approval**.
5. The app proves possession of its Ed25519 private key, receives its device-specific credentials, and saves them in Android-backed secure storage.

The owner approval code is valid for 10 minutes and is one-time. The app stores an unfinished pairing request securely so it can be resumed if Android temporarily suspends the app.

## Daily use

The app sends a 15-minute access credential. When it expires, the client rotates its 30-day refresh credential automatically and stores the replacement. The master server token is not copied into the app during this pairing flow.

The private Ed25519 key is stored in Flutter secure storage backed by Android Keystore. The server stores only the corresponding public key. Re-pairing an active identity replaces its previous session. If the device identity was revoked, the app offers to generate a new identity.

## Revocation

Use **Workspace → Devices** to revoke a device. Revocation invalidates its active sessions. Refresh-token reuse also triggers device revocation.

## Local-only transport

The pairing bootstrap is accepted only through loopback. The app continues to restrict its server URL to `127.0.0.1` or `localhost`; this release does not enable remote/LAN pairing.

The Android runtime monitor now checks only the local `/health` liveness endpoint. It does not share or refresh the app's device credentials. Authenticated app readiness is checked separately through `/mobile/health`.
