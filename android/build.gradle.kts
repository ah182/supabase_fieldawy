// android/build.gradle.kts

import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// تغيير مكان مجلد build الرئيسي
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ✅ إجبار جميع المكتبات على استخدام إصدار SDK موحد لحل مشكلة lStar ومتطلبات androidx.activity
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                compileSdkVersion(35)
                defaultConfig {
                    targetSdkVersion(35)
                }
            }
        }
    }
}


// نخلي الـ app دايمًا يتعمله evaluate قبل باقي الـ modules
subprojects {
    project.evaluationDependsOn(":app")
}

// Task clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
