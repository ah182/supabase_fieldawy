# Price Tracking for OCR Products Migration

## Overview
This migration adds price change tracking functionality to OCR products, allowing them to appear in the "Price Action" tab alongside regular catalog products.

## Changes Made

### Database Schema
Added three new columns to `distributor_ocr_products` table:
- `old_price` (numeric): Stores the previous price before update
- `price_updated_at` (timestamp): Records when the price was last updated
- `expiration_date` (timestamp): Stores product expiration date for offers

### Application Code
- Modified `updateOcrProductPrice()` in `product_repository.dart` to:
  - Fetch the current price before updating
  - Store it in `old_price` column
  - Update `price_updated_at` with current timestamp
  
- Modified `getProductsWithPriceUpdates()` to include OCR products with price changes

## How to Apply Migration

### Option 1: Using Supabase CLI (Recommended)
```bash
supabase db push
```

### Option 2: Manual SQL Execution
1. Log in to your Supabase Dashboard
2. Go to SQL Editor
3. Execute the following SQL:

```sql
-- Add old_price column
ALTER TABLE public.distributor_ocr_products
ADD COLUMN IF NOT EXISTS old_price numeric NULL;

-- Add price_updated_at column
ALTER TABLE public.distributor_ocr_products
ADD COLUMN IF NOT EXISTS price_updated_at timestamp with time zone NULL;

-- Add expiration_date column
ALTER TABLE public.distributor_ocr_products
ADD COLUMN IF NOT EXISTS expiration_date timestamp with time zone NULL;
```

## Features After Migration

### Price Action Tab
- OCR products with price changes now appear in the "Price Action" tab
- Shows old price → new price with update timestamp
- Sorted by most recent updates first

### Benefits
- Users can track price changes for both catalog and OCR products
- Better visibility of pricing updates
- Consistent price tracking across all product types

## Testing
1. Update an OCR product price in "My Products" → OCR tab
2. Navigate to Home → "Price Action" tab
3. Verify the OCR product appears with old and new prices
4. Confirm the update timestamp is displayed

## Notes
- Existing OCR products will have `NULL` in `old_price` and `price_updated_at` until their prices are updated
- Only products with price changes (where `old_price IS NOT NULL`) appear in Price Action tab
