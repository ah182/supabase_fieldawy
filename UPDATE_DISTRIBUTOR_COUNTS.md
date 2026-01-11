# Distributor Product Count Update
### 2026-01-08

## Summary
Updated the logic for calculating and retrieving distributor product counts to include all product types:
1. **Standard Products** (`distributor_products`)
2. **OCR Products** (`distributor_ocr_products`)
3. **Surgical Tools** (`distributor_surgical_tools`)
4. **Veterinary Supplies** (`vet_supplies` - Active only)

## Changes

### 1. Edge Function: `get-distributors`
- **Location:** `supabase/functions/get-distributors/index.ts`
- **Change:** Updated to query all 4 tables in parallel and sum the counts for each distributor.
- **Result:** The `productCount` field in the distributor card now reflects the total inventory.

### 2. Edge Function: `get-distributor-products`
- **Location:** `supabase/functions/get-distributor-products/index.ts`
- **Change:** Added fetching of `distributor_surgical_tools` and mapping them to the product list.
- **Result:** Surgical tools will now appear in the products list (Medicines tab) alongside standard and OCR products.
- **Note:** `vet_supplies` are fetched separately by the app in the "Supplies" tab, so they are not included in this function to avoid duplication.

## Deployment Instructions
To apply these changes, deploy the updated edge functions:

```bash
supabase functions deploy get-distributors --no-verify-jwt
supabase functions deploy get-distributor-products --no-verify-jwt
```
