# UI Update: Distributor Vet Supply Cards

## Objective
Update the visual style of `_VetSupplyCard` in `DistributorProductsScreen` to exactly match `_SupplyCard` in `VetSuppliesScreen`.

## Changes Implemented
- **File:** `lib/features/distributors/presentation/screens/distributor_products_screen.dart`
- **Widget:** `_VetSupplyCard`

### Key Updates:
1.  **Structure**: Adopted the exact widget structure of `_SupplyCard` (Card -> Column -> Expanded Image Stack -> Expanded Info Column).
2.  **Styling**:
    -   Used `surfaceVariant` background for images.
    -   Applied consistent text styles (`labelLarge` for title, `labelSmall` for distributor name).
    -   Added "Views" badge alongside the "Price" badge.
    -   Added "Package Size" badge.
3.  **Functionality Integration**:
    -   Retained the **"Add to Cart"** button, positioning it as an overlay on the image (bottom-right), consistent with the previous distributor card functionality but styled to fit the new design.
    -   Added **View Tracking** (`VisibilityDetector`) to increment supply views when displayed, matching the behavior of the main supplies screen.
4.  **State Management**: Converted to `ConsumerStatefulWidget` to handle view tracking state (`_hasBeenViewed`).

## Result
The cards in the Distributor's Supply tab now look identical to the main Vet Supplies feed while retaining their specific ordering capabilities.
