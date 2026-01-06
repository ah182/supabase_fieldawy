# Fix: Dashboard Top Products Error

## Issue
The "Top Products" section in the Dashboard was throwing an error when trying to display offers related to OCR products.
Error: `PostgrestException(message: "column ocr_products.ocr_product_id does not exist", code: 400, ...)`

## Cause
The code was attempting to query the `ocr_products` table using a non-existent column `ocr_product_id`. The correct primary key column is `id`.

## Solution
Modified `lib/features/dashboard/presentation/widgets/top_products_widget.dart`:
1.  **Corrected Query:** Changed the query to look up by `.eq('id', linkedProductId)` in the `ocr_products` table.
2.  **Added Fallback:** Implemented a secondary check. If the ID is not found in `ocr_products`, the code now checks `distributor_ocr_products` (assuming the ID might refer to the distributor's entry) and joins with `ocr_products` to get the image URL.

## Result
The Dashboard should now correctly display images for top-performing offers, including those based on OCR products, without crashing.
