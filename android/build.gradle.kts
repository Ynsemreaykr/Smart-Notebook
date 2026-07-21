allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force Kotlin compiler targets to match the specific Java targets of misaligned plugins
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val pName = project.name
        if (pName.contains("share_plus") || pName.contains("image_picker") || pName.contains("url_launcher")) {
            // share_plus, image_picker and url_launcher use Java 17 natively, so their Kotlin must match
            compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
        } else if (pName.contains("pdfx")) {
            // pdfx uses Java 11
            compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) }
        } else {
            // home_widget and receive_sharing_intent use Java 1.8 natively
            compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8) }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}