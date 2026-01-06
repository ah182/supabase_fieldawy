# Global Force Refresh Feature

## Overview
Implemented a "Force Refresh" mechanism across all major data-displaying screens in the application. This ensures users can easily retry loading data if a network error occurs or if no results are found initially.

## Key Components

### 1. Reusable Error Widget
- **File:** `lib/widgets/refreshable_error_widget.dart`
- **Widget:** `RefreshableErrorWidget`
- **Features:** Unified design with error icon, descriptive message, and a prominent "Retry" button.

## Screens Updated

### Home Screen
- All 7 tabs (Home, Price Action, Expire Soon, Surgical, Offers, Courses, Books) now have a targeted refresh button for error and empty states.

### Catalog & Products
- **Add from Catalog:** Both Main and OCR catalog tabs now support refreshing on error.
- **My Products:** Main and OCR tabs include a refresh button.
- **Favorites:** Support for refreshing the favorites list.

### Distributors & Supplies
- **Distributors List:** Global distributor list can be refreshed.
- **Distributor Products:** Both Medicines and Supplies tabs for a specific distributor.
- **Vet Supplies:** All Supplies and My Supplies tabs.
- **Surgical Tools:** Specific screen for distributor surgical tools.

### Jobs & Reviews
- **Job Offers:** Available Jobs and My Jobs tabs.
- **Product Reviews:** Main requests list and specific review details list.

### Orders
- **Orders Screen:** Empty cart state and loading error state now support refreshing.

## Technical Implementation
- **Riverpod Integration:** Used `ref.refresh()` and `ref.invalidate()` to force providers to refetch data.
- **UI Consistency:** Replaced various inconsistent `Center(Text('Error'))` blocks with the new `RefreshableErrorWidget`.
- **Empty State Support:** Added `TextButton.icon` refreshers to empty states to allow manual re-polling of the server.
