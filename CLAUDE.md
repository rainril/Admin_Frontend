# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter frontend for the "PrimeFit" gym admin portal. The Flutter app is a thin client: it has no local data layer of its own and expects a **separate Laravel + MySQL backend** running at `http://127.0.0.1:8000/api` to supply all data (auth, payments, attendance, inventory, dashboard analytics, settings). That backend is not part of this repo. A second, separate service lives in `primefit-chatbot/` (Python/FastAPI) for chatbot intent classification — see its own README for setup; Laravel calls it, not Flutter directly.

## Commands

```bash
flutter pub get                 # install deps
flutter run -d chrome           # run (this app effectively only supports web — see Platform below)
flutter build web               # production web build
flutter test                    # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter analyze                 # lint (flutter_lints, see analysis_options.yaml)
```

There is no `-d` target other than web/chrome that will actually build — see Platform note below.

## Platform: web-only in practice

`lib/main.dart` unconditionally imports `dart:html` (used to read the URL hash for deep-linking into `#/scan`, `#/attendance`, `#/chatbot`). This means the app only compiles for web; the `android/`, `ios/`, `windows/`, `linux/`, `macos/` platform folders exist from `flutter create` scaffolding but are not currently buildable without first replacing that import with a conditional (`dart:html` vs. a stub) or `package:web`. Don't assume mobile/desktop builds work — check `main.dart` before changing this.

## Architecture

- **Entry/routing**: `lib/main.dart` picks the initial screen. On web it reads `window.location.hash` (`#/scan`, `#/attendance`, `#/chatbot`) to deep-link directly into a sub-page; otherwise it starts at `LoginScreen`. There's no named-route table — navigation elsewhere is done with `Navigator.push`/`pushAndRemoveUntil` and `AppShell`'s internal tab index.
- **Shell**: `lib/screens/app_shell.dart` is the post-login container. It holds an `IndexedStack` of the 8 main screens (Dashboard, Attendance, Scan, Billing, Pending Payments, Inventory, Chatbot, Settings) and switches between a fixed `Sidebar` (width ≥ 900px) and a `Drawer` + `AppBar` (narrower). `AppShell(initialIndex: N)` is how deep links jump straight to a tab — the `#/chatbot` deep link in `main.dart` hardcodes that tab's index, so keep it in sync if you reorder tabs.
- **Auth/session state**: `AuthService` (`lib/services/auth_service.dart`) calls Laravel's `/login`, `/register`, `/forgot-password`, `/verify-reset-code`, `/reset-password` and persists the token + profile fields to `SharedPreferences`. `CurrentUser` (`lib/services/current_user.dart`) is a plain static in-memory holder (first/last name, email, `adminLevel`, `accountId`) populated after login — it is **not** reloaded from `SharedPreferences` automatically, so a hot restart loses it even though the token persists.
- **Role gating**: two admin levels, `owner` and `staff`, exposed as `CurrentUser.isOwner` / `CurrentUser.isStaff`. Screens branch UI on this directly (e.g. `dashboard_screen.dart` shows different stat cards per role, `inventory_screen.dart` and `attendance_page.dart` hide destructive actions from staff in favor of a request/approval flow — see `DeletionRequestsPanel` and the approval-request endpoints in `attendance_service.dart`). When adding admin-only features, follow this same `CurrentUser.isOwner` check pattern rather than introducing a new permissions system.
- **Service layer**: one static-method class per resource area under `lib/services/` (`attendance_service.dart`, `payment_service.dart`, `equipment_item_service.dart`, `merch_item_service.dart`, `merch_sale_service.dart`, `deletion_request_service.dart`, `dashboard_analytics_service.dart`, `settings_service.dart`, `chatbot_service.dart`, `earnings_pdf_service.dart`). Each talks to Laravel via `package:http`, JSON-decodes the response, and returns plain `Map`/`List` — there's no typed API client or code generation. **Watch the base URL**: most services define their own `static const String baseUrl = 'http://127.0.0.1:8000/api'`, but newer ones reference a shared `ApiConfig.baseUrl` defined at the top of `dashboard_analytics_service.dart` (itself hardcoded to `http://localhost:8000/api`). These are currently two independent constants that happen to point to the same place — changing the backend host means updating both.
- **Local caches**: a few services keep an in-memory singleton cache alongside the network call (e.g. `PaymentData.instance` in `payment_data.dart`, `AttendanceData` in `attendance_data.dart`) so the UI has something to render immediately/on failure while a fresh fetch is in flight.
- **Theming**: `lib/theme/app_theme.dart` defines the static light palette (`AppTheme.light`, `AppColors`). `lib/services/theme_controller.dart` is a `ChangeNotifier` singleton (`ThemeController.instance`) driving dark mode; `main.dart` wraps `MaterialApp` in a `ListenableBuilder` on it. Toggling dark mode elsewhere in the app should go through `ThemeController.instance.setDarkMode(...)`, not a local widget state.
- **Models**: `lib/models/models.dart` holds only `MembershipPlan` and `Payment` (used for the Billing screen's demo/UI-side data); most other screens work directly with the raw `Map<String, dynamic>` returned by their service instead of a model class.
- **QR / check-in flow**: `qr_scanner_page.dart` and `scan_checkin_page.dart` use `mobile_scanner` to scan a member's QR and hit `attendance_service.dart`'s verify/check-in endpoints; `qr_flutter` is used elsewhere to *generate* member QR codes.
- Comments and variable naming throughout the services layer mix English and Tagalog (e.g. "Kunin ang listahan...") — match the existing style when editing those files rather than normalizing to English-only.

## Chatbot subproject (`primefit-chatbot/`)

Standalone Python (FastAPI + scikit-learn TF-IDF/LogisticRegression) intent classifier, independent of the Flutter build. It does not talk to MySQL itself — it returns an `intent` + `response_template`, and Laravel is expected to fill in real data before relaying the final message to Flutter's `ChatbotService`. Setup/retraining commands are in `primefit-chatbot/README.md`.
