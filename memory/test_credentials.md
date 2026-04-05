# Test Credentials

## Seeded Test Users (Spring Boot DataSeeder)

| Name   | Phone          | Role          | Notes                          |
|--------|----------------|---------------|--------------------------------|
| Arjun  | +919876543210  | Regular User  | Primary test user              |
| Priya  | +919876543211  | Regular User  | Secondary test user            |
| Guest  | +910000000000  | Guest/System  | Used for groups seeding check  |

## Auth Flow
- Auth uses Firebase Phone OTP
- Dev mode: Set `SPARK_AUTH_EXPOSE_DEBUG_OTP=true` to see OTP in API response (default: false)
- Dev guest login: Set `SPARK_AUTH_ENABLE_DEV_GUEST_LOGIN=true` to bypass OTP (default: false)
- JWT: Configured via `SPARK_JWT_SECRET` env var (default warns but works in dev)

## Backend API Base URL
- Local: `http://localhost:8080/api/v1`
- Auth endpoints: `POST /api/v1/auth/otp/request`, `POST /api/v1/auth/otp/verify`
