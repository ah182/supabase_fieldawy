pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val sdkPath = properties.getProperty("flutter.sdk")
        require(sdkPath != null) { "flutter.sdk not set in local.properties" }
        sdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version "4.3.15" apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

dependencyResolutionManagement {
    // ⬅️ مهم: امنع أي project repos غير اللي هنا
   repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)


    repositories {
        google()
        mavenCentral()
        // fallback لو احتجت
        jcenter() // ⚠️ deprecated بس ساعات بيحل مشاكل لمكتبات قديمة

        // ✅ حل أساسي لمشكلتك: أضف Flutter Engine maven repo
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        if (flutterSdkPath != null) {
            maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
        }
    }
}

rootProject.name = "fieldawy_store"
include(":app")
