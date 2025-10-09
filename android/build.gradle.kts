// android/build.gradle.kts

import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// تغيير مكان مجلد build الرئيسي
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ✅ مهم: نضمن إن كل subprojects تستخدم نفس الـ repositories
    
}


// نخلي الـ app دايمًا يتعمله evaluate قبل باقي الـ modules
subprojects {
    project.evaluationDependsOn(":app")
}

// Task clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
