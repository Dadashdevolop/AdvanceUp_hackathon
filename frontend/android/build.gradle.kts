import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// Repositories for all projects
allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Relocate build outputs (kept from original file)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Fix for record package namespace issue
subprojects {
    if (project.name == "record") {
        project.afterEvaluate {
            project.extensions.findByName("android")?.let { android ->
                (android as com.android.build.gradle.LibraryExtension).apply {
                    namespace = "com.llfbandit.record"
                }
            }
        }
    }
}
