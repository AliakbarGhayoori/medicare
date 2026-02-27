# iOS App Skeleton

This folder contains a Phase 1 SwiftUI skeleton aligned to project docs.

## Structure
- `MediCareAI/App`: app entry and root routing
- `MediCareAI/Models`: Codable contracts aligned to backend API
- `MediCareAI/Services`: auth, API client, SSE parser
- `MediCareAI/ViewModels`: MVVM state and feature logic
- `MediCareAI/Views`: feature screens (Auth, Chat, V10, Settings, Onboarding)

## Notes
- `AuthService` supports Firebase when Firebase SDK is linked.
- For local backend mock auth, set environment variable `AUTH_MODE=mock` and backend token format `Bearer mock:<uid>` is used.
- Base API URL reads from `API_BASE_URL` env var and defaults to `http://localhost:8000`.
- Xcode project is generated from `ios/project.yml` via `xcodegen generate`.
- For live Firebase + real backend mode:
  - Use scheme `MediCareAI-Live` (sets `AUTH_MODE=firebase`).
  - Add `GoogleService-Info.plist` to `ios/MediCareAI/Resources/`.
  - Ensure backend is running with `AUTH_MODE=firebase` and real AI credentials.
- Test targets included:
  - `MediCareAITests` (unit tests)
  - `MediCareAIUITests` (UI tests)
