-- Migration: Add price tracking and expiration date to distributor_ocr_products
-- Created: 2024
-- Description: Adds old_price, price_updated_at, and expiration_date columns to track price changes and product expiration

-- Add old_price column to store previous price for price change tracking
ALTER TABLE public.distributor_ocr_products
ADD COLUMN IF NOT EXISTS old_price numeric NULL;

-- Add price_updated_at column to track when price was last updated
ALTER TABLE public.distributor_ocr_products
ADD COLUMN IF NOT EXISTS price_updated_at timestamp with time zone NULL;

-- Add expiration_date column for offers with expiration dates
ALTER TABLE public.distributor_ocr_products
ADD COLUMN IF NOT EXISTS expiration_date timestamp with time zone NULL;

-- Add comment to explain the columns
COMMENT ON COLUMN public.distributor_ocr_products.old_price IS 'Previous price before update, used for price change tracking in Price Action tab';
COMMENT ON COLUMN public.distributor_ocr_products.price_updated_at IS 'Timestamp of last price update';
COMMENT ON COLUMN public.distributor_ocr_products.expiration_date IS 'Product expiration date for offers';
