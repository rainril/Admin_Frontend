# PrimeFit Admin Portal — Flutter App

A responsive Flutter frontend for the PrimeFit gym admin portal, matching the provided UI design.

## Screens included

- **Admin Sign In** — split dark/light layout, email/password with show-hide, "keep me signed in", forgot password, demo credentials pre-filled, form validation. Submitting navigates to the Dashboard.
- **Dashboard** — 4 animated stat cards, Weekly Attendance bar chart, Monthly Revenue line chart (via `fl_chart`), Recent Notifications feed.
- **Billing & Payments** — revenue/pending/failed summary cards, Membership Plans (Basic/Standard/Premium), Recent Payments table with status/plan badges, working **Create Plan** modal that adds a new plan card live, Export button.
- **Settings** — Admin Profile (editable + Save), Gym Information (editable + Update), Notifications toggles, System actions (Export/Backup/Clear Cache/Logs) — all wired to snackbar feedback.
- **Members** & **Inventory** — functional list screens (search, status badges) reachable from the sidebar, since no specific mockup was provided for these.

The **AI Analytics** nav item was intentionally removed per your request.

## Responsiveness

- Sidebar is a fixed panel on screens ≥900px wide, and collapses into a `Drawer` (hamburger menu) with an AppBar on narrower/mobile screens.
- Dashboard stat grid adapts from 4 → 2 → 1 columns based on width.
- Login screen switches from a two-pane layout to a stacked layout on narrow screens.
- Billing plan cards, payment table, and settings panels reflow for smaller viewports.

## Getting started

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. From the project root:
   ```bash
   flutter pub get
   flutter run -d chrome        # or: flutter run  (for a connected device/emulator)
   ```
3. Login screen is pre-filled with the demo credentials (`admin@primefit.com`). Any non-empty password + valid email will sign you in.

## Project structure

```
lib/
  main.dart
  theme/app_theme.dart          # colors & theme
  models/models.dart            # MembershipPlan, Payment models
  widgets/
    sidebar.dart                # shared nav sidebar
    stat_card.dart               # dashboard stat card
    create_plan_dialog.dart      # "Create Membership Plan" modal
  screens/
    login_screen.dart
    app_shell.dart               # responsive shell (sidebar/drawer + routing)
    dashboard_screen.dart
    billing_screen.dart
    settings_screen.dart
    members_screen.dart
    inventory_screen.dart
```

## Notes

- All data is in-memory demo data (no backend). Buttons like Save/Update/Export/Backup show a confirmation snackbar.
- The PrimeFit logo is recreated as a styled "PF" monogram since the original image asset wasn't available; swap in your real logo asset in `sidebar.dart` and `login_screen.dart` if you have one.
