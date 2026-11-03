# Install UniRent on an Android phone

The phone connects to the server over HTTPS; it does not need to stay connected to the development laptop. UniRent is a Flutter Android app, so build and install its APK once (or download the APK artifact produced by CI). The server deployment uses Podman and `podman compose` with a compatible Compose provider; Docker is not required on the server.

## Server requirements

- Point `unirent.siddharths.me` DNS to the server and allow inbound TCP 80 and 443. Caddy in the `staging` Compose profile obtains and renews the TLS certificate.
- Set `STAGING_DOMAIN=unirent.siddharths.me` and `STORAGE_PUBLIC_URL=https://unirent.siddharths.me` in `infra/env/.env`. The Caddy config routes `/photos/*` to MinIO and other requests to the API so phone uploads and photo reads work on the same HTTPS origin.
- The Compose Caddy service must own ports 80 and 443. If another reverse proxy already owns them, configure that proxy to send `/photos/*` to MinIO port 9000 and all other paths to API port 8000, preserving the request host and URI for MinIO signatures. Keep both service ports private to the server.
- Configure real Microsoft/Firebase/Razorpay credentials as described in `infra/env/staging.env.example`; mock sign-in is rejected by the staging API.

On the server, clone the repository, copy `infra/env/staging.env.example` to `infra/env/.env`, fill in the secrets and Firebase credentials, then run:

```sh
chmod +x deploy.sh
./deploy.sh
```

The script builds the API and worker images on the server with Podman, starts the staging stack, initializes the photos bucket, runs migrations, and waits for the HTTPS readiness endpoint. It creates the staging env file and stops on the first run if the file is missing; fill the required settings before running again. Ensure the domain points to the server and ports 80 and 443 are available to Caddy. Check `https://unirent.siddharths.me/healthz` and `/readyz` before installing the app.

## Build an APK

From the repository root, with Flutter installed:

```sh
cd frontend
flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=https://unirent.siddharths.me \
  --dart-define=AUTH_MODE=microsoft \
  --dart-define=PHONE_AUTH_MODE=firebase \
  --dart-define=RAZORPAY_MODE=checkout \
  --dart-define=MS_CLIENT_ID=YOUR_ENTRA_CLIENT_ID \
  --dart-define=MS_TENANT_ID=YOUR_ENTRA_TENANT_ID
```

The APK is `frontend/build/app/outputs/flutter-apk/app-release.apk`. Firebase phone sign-in and Razorpay Checkout also need their native Firebase/Razorpay setup and production/test credentials; configure those before relying on those flows. For a basic API smoke check, the staging backend also needs valid sign-in configuration.

Transfer the APK to the phone through any convenient method (for example, a private file share), open it, and allow installation from that source when Android prompts. After installation, the phone uses the HTTPS API directly and no cable connection is needed.

CI also builds an APK on pushes to `master` and keeps it as a 14-day workflow artifact. Set the repository variable `STAGING_API_URL` to `https://unirent.siddharths.me` for that artifact; download it from the successful workflow run.
