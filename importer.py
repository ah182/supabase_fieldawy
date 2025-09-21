import os
import json
import requests
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# --- إعدادات Cloudinary ---
CLOUDINARY_CLOUD_NAME = "dk8twnfrk"  # ❗غيرها بالقيمة الحقيقية
CLOUDINARY_UPLOAD_PRESET = "fieldawy_unsigned"  # اسم الـ Preset

# --- إعدادات Firebase ---
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- إعدادات المجلدات ---
PROJECT_ROOT = Path(__file__).parent
JSON_PATH = PROJECT_ROOT / "assets" / "fieldawy_drugs" / "fieldawy_drugs_main.json"
IMAGES_DIR = PROJECT_ROOT / "drug_image_main"
FAILED_IDS_FILE = PROJECT_ROOT / "failed_ids_first_run.txt"
STILL_FAILED_FILE = PROJECT_ROOT / "still_failed_ids.txt"

def upload_image_to_cloudinary(image_path):
    url = f"https://api.cloudinary.com/v1_1/{CLOUDINARY_CLOUD_NAME}/image/upload"
    with open(image_path, 'rb') as file:
        files = {'file': file}
        data = {
            'upload_preset': CLOUDINARY_UPLOAD_PRESET,
            'folder': 'products'
        }
        response = requests.post(url, files=files, data=data)
        if response.status_code == 200:
            return response.json().get('secure_url')
        else:
            print("❌ Upload failed:", response.text)
            return None

def find_image(product_id, second_attempt=False):
    """بحث عن الصورة حسب نوع المحاولة"""
    # المحاولة الأولى: اسم عادي
    if not second_attempt:
        for ext in ['png', 'jpg', 'jpeg']:
            exact_path = IMAGES_DIR / f"{product_id}.{ext}"
            if exact_path.exists():
                return exact_path
    else:
        # المحاولة الثانية: اسم بـ _1
        for ext in ['png', 'jpg', 'jpeg']:
            alt_path = IMAGES_DIR / f"{product_id}_1.{ext}"
            if alt_path.exists():
                print(f"⚠️  Using alternative image for ID {product_id}: {alt_path.name}")
                return alt_path

    # fallback: أي صورة تبدأ بـ "{id}_"
    try:
        for file in IMAGES_DIR.iterdir():
            if file.is_file() and file.name.startswith(f"{product_id}_") and file.suffix.lower() in ['.png', '.jpg', '.jpeg']:
                if second_attempt:
                    print(f"⚠️  Using alternative image for ID {product_id}: {file.name}")
                    return file
    except FileNotFoundError:
        pass

    return None

def main():
    print("📄 Reading JSON...")
    if not JSON_PATH.exists():
        print("❌ JSON file not found")
        return

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    products = data.get("products", []) if isinstance(data, dict) else data
    if not products:
        print("ℹ️ No products found")
        return

    print(f"✅ Found {len(products)} products")

    success = 0
    failure = 0
    failed_ids = []

    # ===== المحاولة الأولى =====
    print("\n🔁 First attempt: Normal image names...")
    for item in products:
        product_id = str(item.get("id", ""))
        product_name = item.get("name", "").strip()

        if not product_id:
            print(f"⚠️ Skipping item without ID: {product_name}")
            failed_ids.append(product_id)
            failure += 1
            continue

        image_path = find_image(product_id, second_attempt=False)
        if not image_path:
            print(f"⚠️ Image not found for: {product_name} (ID: {product_id})")
            failed_ids.append(product_id)
            failure += 1
            continue

        print(f"⬆️ Uploading image for: {product_name}")
        image_url = upload_image_to_cloudinary(image_path)
        if not image_url:
            print(f"❌ Failed to upload image for: {product_name}")
            failed_ids.append(product_id)
            failure += 1
            continue

        # حفظ في Firestore
        item["imageUrl"] = image_url
        item["createdAt"] = firestore.SERVER_TIMESTAMP

        try:
            db.collection("products").document(product_id).set(item)
            print(f"✅ Uploaded: {product_name}")
            success += 1
        except Exception as e:
            print(f"❌ Firestore error for {product_name}: {e}")
            failed_ids.append(product_id)
            failure += 1

    # ===== حفظ IDs الفاشلة من المحاولة الأولى =====
    if failed_ids:
        with open(FAILED_IDS_FILE, "w") as f:
            for fid in failed_ids:
                f.write(f"{fid}\n")
        print(f"\n📝 First run failed IDs saved to: {FAILED_IDS_FILE}")

    # ===== المحاولة التانية للـ IDs الفاشلة =====
    if failed_ids:
        print(f"\n🔁 Second attempt: Trying with '_1' suffix for {len(failed_ids)} failed items...")
        still_failed = []
        for product_id in failed_ids[:]:  # نسخة علشان نقدر نعدل الأصلي
            # ندور المنتج من الـ JSON
            item = next((p for p in products if str(p.get("id", "")) == product_id), None)
            if not item:
                still_failed.append(product_id)
                continue

            product_name = item.get("name", "").strip()

            image_path = find_image(product_id, second_attempt=True)
            if not image_path:
                print(f"❌ Still no image for: {product_name} (ID: {product_id})")
                still_failed.append(product_id)
                continue

            print(f"⬆️ Uploading image (2nd try) for: {product_name}")
            image_url = upload_image_to_cloudinary(image_path)
            if not image_url:
                print(f"❌ Failed to upload (2nd try) for: {product_name}")
                still_failed.append(product_id)
                continue

            # حفظ في Firestore
            item["imageUrl"] = image_url
            item["createdAt"] = firestore.SERVER_TIMESTAMP

            try:
                db.collection("products").document(product_id).set(item)
                print(f"✅ Uploaded (2nd try): {product_name}")
                success += 1
                failure -= 1
            except Exception as e:
                print(f"❌ Firestore error (2nd try) for {product_name}: {e}")
                still_failed.append(product_id)

        # ===== تسجيل الـ IDs اللي لسه فاشلة =====
        if still_failed:
            with open(STILL_FAILED_FILE, "w") as f:
                for fid in still_failed:
                    f.write(f"{fid}\n")
            print(f"\n📝 Still failed IDs saved to: {STILL_FAILED_FILE}")

    print("\n--- Import Complete ---")
    print(f"🎉 Success: {success}")
    print(f"❌ Failures: {failure}")

if __name__ == "__main__":
    main()