# Phone OTP, app build and staging host

## Phone OTP

| Option | Cost and setup | Verdict |
|---|---|---|
| Firebase Phone Authentication | Free tier covers a student project. Test phone numbers with fixed codes (up to 10) send no SMS, which suits development and the demo | **Chosen** |
| Indian SMS providers (MSG91, Twilio India, etc.) | Need DLT registration of the sender ID and every template with an Indian operator, which takes days to weeks | Not worth it for the project |

Flow: the app verifies the number with Firebase, then sends the Firebase **ID token** to `POST /api/v1/auth/phone`. The backend checks the token against Google's `securetoken` keys (`aud` = Firebase project ID, `iss` = `https://securetoken.google.com/{project}`) and saves the `phone_number` claim. The app never sends a phone number the backend didn't see verified.

Development: with `PHONE_AUTH_MODE=mock` the backend accepts mock tokens, and the app's debug build uses the code `123456`.

## App build (Flutter)

The team chose Flutter over Expo, so the Expo-specific questions in the plan become:

- **Razorpay:** `razorpay_flutter` is a plugin with native code. It works in a normal debug build (no Expo-style dev client is needed).
- **Push:** Expo's push service only works with Expo apps, so pushes go through **Firebase Cloud Messaging** directly (HTTP v1 API, service account credentials in the workers' environment). FCM delivers to Android directly and to iOS through APNs.
- **Microsoft sign-in:** `flutter_appauth` runs the PKCE flow with the system browser.
- **iOS:** building and installing on a device needs a Mac with Xcode. Distributing to testers (TestFlight) needs the paid Apple Developer Program ($99 a year), and APNs keys for push need it too. Recommendation: demo on Android only.

## Staging host

| Option | Notes |
|---|---|
| College server | Free and on the campus network, but needs IT approval, a public URL for webhooks, and Docker access |
| Free-tier cloud VM (Oracle Cloud Always Free Ampere, 4 OCPU and 24 GB) | Enough for the whole Compose stack including Kafka and monitoring. Public IP, so webhooks work without a tunnel. ARM, so images are built multi-arch |
| One team laptop | No cost, but only up while the laptop is, and webhooks need the tunnel |

Recommendation: a free-tier cloud VM, with a team laptop plus the tunnel as the fallback for the demo. CI deploys over SSH with Docker Compose (`staging` profile).
