# Fix: Dashboard Top Products Name Fetching

## Issue
The "Top Products" section in the Dashboard was failing to fetch the correct product name for OCR-based offers.
This was due to two reasons:
1.  Incorrect column name usage (`ocr_product_id` instead of `id`) when querying the `ocr_products` table.
2.  Lack of fallback mechanism if the offer's `product_id` referred to a `distributor_ocr_product` entry instead of the master `ocr_product`.

## Solution
Modified `lib/features/dashboard/data/dashboard_repository.dart` in the `_fetchTopProducts` method:
1.  **Corrected Query:** Changed the primary lookup to use `.eq('id', offer['product_id'])` on the `ocr_products` table.
2.  **Added Fallback:** Implemented a fallback query to `distributor_ocr_products` if the direct lookup fails. This query joins with `ocr_products` to retrieve the `product_name`.

## Result
The Dashboard will now correctly display the names of top-performing offers, ensuring consistency with the image display fix applied previously.
