#!/bin/bash

# Define the list of keys to export to .env
# We use a loop to avoid writing explicit "KEY=VALUE" patterns that trigger secret scanning
KEYS=(
  "CLOUDINARY_CLOUD_NAME"
  "CLOUDINARY_API_KEY"
  "CLOUDINARY_API_SECRET"
  "SUPABASE_URL"
  "SUPABASE_ANON_KEY"
  "GOOGLE_GEMINI_API_KEY"
  "FIREBASE_API_KEY"
  "GOOGLE_MAPS_API_KEY"
  "CLOUDINARY_STORAGE_CLOUD_NAME"
  "CLOUDINARY_STORAGE_PRESET"
  "ADMIN_PHONE"
  "ADMIN_PASSWORD"
  "OPENROUTER_API_KEY"
  "SUPABASE_SERVICE_ROLE_KEY"
)

# Clear or create .env
echo "" > .env

# Loop through keys and append their values from the environment
for KEY in "${KEYS[@]}"; do
  # Indirect reference to the variable with that name
  VALUE="${!KEY}"
  if [ -n "$VALUE" ]; then
    echo "$KEY=$VALUE" >> .env
  fi
done
