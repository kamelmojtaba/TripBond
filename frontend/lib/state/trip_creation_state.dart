/// Shared transient state used during the trip-creation wizard.
///
/// We had two top-level `selectedCityForTrip` declarations (one in
/// `plans_list.dart`, one in `DestinationLandingPage.dart`). Files that only
/// imported `DestinationLandingPage.dart` (e.g. `TripInfo.dart`) were reading
/// from a different copy of the global than the one `plans_list.dart` was
/// writing to, so the destination always looked empty. This module is now the
/// single source of truth — any file that needs to read or write the
/// in-progress destination should import this file.
library;

String selectedCityForTrip = '';
