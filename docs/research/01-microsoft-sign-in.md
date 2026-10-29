# Microsoft sign-in with the college tenant

Status: findings from the documentation and a test tenant. The college-specific answers (consent policy, tenant ID) still need confirming with college IT.

## How the flow works

1. The app runs the OAuth 2.0 authorization code flow with PKCE against `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize`, scopes `openid profile email offline_access`.
2. The app sends the returned **ID token** to `POST /api/v1/auth/microsoft`.
3. The backend validates the token itself and issues UniRent tokens. The Microsoft tokens are never stored.

The app registration is a **public client** (mobile): no client secret, redirect URI `msauth://in.unirent.app/callback` for Android (with the signing-certificate hash) and `unirent://auth` as a fallback custom scheme.

## What the backend checks

| Check | Source |
|---|---|
| Signature | Keys from `https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys`, cached and refreshed on an unknown `kid` |
| `aud` | Must equal our application (client) ID |
| `iss` | `https://login.microsoftonline.com/{tid}/v2.0` |
| `tid` | Must equal the college tenant ID (`MS_TENANT_ID`) |
| Email domain | `email` or `preferred_username` must end with `@{MS_ALLOWED_DOMAIN}` |
| `exp`, `nbf` | Standard, with 60 seconds of leeway |

Accounts are keyed by the immutable `oid` claim, not the email, because a UPN can be renamed.

## Consent

Whether students can consent to a new multi-tenant app themselves depends on the tenant's **user consent setting**. Many university tenants allow user consent only for apps from verified publishers, or disable it entirely. If consent is blocked, students see "Need admin approval".

- **Ask college IT for:** admin consent for the scopes `openid profile email offline_access` (all low-risk, no Graph data), plus the tenant ID and the email domain.
- **Fallback while waiting:** register the app in a free Entra test tenant, create test users there, and keep the domain check configurable (`MS_ALLOWED_DOMAIN`). The check logic is the same.
- **Development fallback:** `MS_AUTH_MODE=mock` makes the backend accept ID tokens signed with a local development key, which the test suites and the app's debug sign-in use. It is refused when `ENVIRONMENT=staging` or `production`.

## Open questions

- [ ] Tenant ID and domain from college IT
- [ ] Admin consent granted, or the test-tenant fallback used for the demo
