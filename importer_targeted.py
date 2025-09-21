import json
import requests
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore

# === إعدادات المستخدم - غيرها بالقيم الحقيقية ===
CLOUDINARY_CLOUD_NAME = "dk8twnfrk"        # ❗ ضع اسم Cloudinary الخاص بك
CLOUDINARY_UPLOAD_PRESET = "fieldawy_unsigned"   # اسم الـ Upload Preset

# === إعدادات المجلدات والملفات ===
PROJECT_ROOT = Path(__file__).parent
JSON_PATH = PROJECT_ROOT / "assets" / "fieldawy_drugs" / "fieldawy_drugs_main.json"
IMAGES_DIR = PROJECT_ROOT / "drug_image_main"
FAILED_IDS_FILE = PROJECT_ROOT / "failed_ids_with_underscore.txt"  # الملف اللي فيه IDs الفاشلة
SERVICE_ACCOUNT_PATH = PROJECT_ROOT / "serviceAccountKey.json"     # ملف مفتاح Firebase

# === دوال مساعدة ===

def find_image_with_underscore(product_id):
    """دور على الصورة اللي اسمها {id}_1.{ext}"""
    for ext in ['png', 'jpg', 'jpeg']:
        path_with_underscore = IMAGES_DIR / f"{product_id}_1.{ext}"
        if path_with_underscore.exists():
            print(f"✅ Found image for ID {product_id}: {path_with_underscore.name}")
            return path_with_underscore

    # fallback: لو مش لقاها كده، ندور على أي صورة تبدأ بـ "{id}_"
    try:
        for file in IMAGES_DIR.iterdir():
            if file.is_file() and file.name.startswith(f"{product_id}_") and file.suffix.lower() in ['.png', '.jpg', '.jpeg']:
                print(f"✅ Found alternative image for ID {product_id}: {file.name}")
                return file
    except FileNotFoundError:
        pass

    return None

def upload_image_to_cloudinary(image_path):
    """رفع الصورة على Cloudinary"""
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

# === الدالة الرئيسية ===

def main():
    print("📄 Reading JSON...")
    if not JSON_PATH.exists():
        print("❌ JSON file not found")
        return

    # === قراءة IDs الفاشلة ===
    if not FAILED_IDS_FILE.exists():
        print("❌ File failed_ids_with_underscore.txt not found.")
        return

    with open(FAILED_IDS_FILE, "r", encoding="utf-8") as f:
        target_ids = set(line.strip() for line in f if line.strip())

    print(f"🎯 Targeting {len(target_ids)} specific products...")

    # === قراءة ملف الـ JSON ===
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    products = data.get("products", []) if isinstance(data, dict) else data
    # فلترة المنتجات علشان ناخد اللي IDs بتاعتهم في القائمة
    products_to_upload = [p for p in products if str(p.get("id", "")) in target_ids]

    if not products_to_upload:
        print("ℹ️ No matching products found for the given IDs")
        return

    print(f"✅ Found {len(products_to_upload)} matching products to process")

    # === تهيئة Firebase ===
    if not SERVICE_ACCOUNT_PATH.exists():
        print("❌ Firebase service account file not found.")
        return

    try:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
        firebase_admin.initialize_app(cred)
        db = firestore.client()
    except Exception as e:
        print(f"❌ Firebase init error: {e}")
        return

    # === رفع الصور وتحديث Firestore ===
    success = 0
    failure = 0

    for item in products_to_upload:
        product_id = str(item.get("id", ""))
        product_name = item.get("name", "").strip()

        if not product_id:
            print(f"⚠️ Skipping item without ID: {product_name}")
            failure += 1
            continue

        image_path = find_image_with_underscore(product_id)
        if not image_path:
            print(f"❌ Image still not found for: {product_name} (ID: {product_id})")
            failure += 1
            continue

        print(f"⬆️  Uploading image for: {product_name}")
        image_url = upload_image_to_cloudinary(image_path)
        if not image_url:
            print(f"❌ Failed to upload image for: {product_name}")
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
            failure += 1

    print("\n--- Targeted Import Complete ---")
    print(f"🎉 Success: {success}")
    print(f"❌ Failures: {failure}")

if __name__ == "__main__":
    main()