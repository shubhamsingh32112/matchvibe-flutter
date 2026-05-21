import org.jetbrains.kotlin.gradle.dsl.KotlinVersion
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    val newBuildDir = file("${rootProject.buildDir}/${project.name}")
    // Skip build dir override for plugins on a different drive (Windows cross-drive issue)
    if (project.projectDir.toPath().root == newBuildDir.toPath().root) {
        project.buildDir = newBuildDir
    }
}

subprojects {
    evaluationDependsOn(":app")
}

// sentry_flutter 8.x pins Kotlin languageVersion 1.6; KGP 2.2+ requires 1.8+.
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(KotlinVersion.KOTLIN_1_8)
            apiVersion.set(KotlinVersion.KOTLIN_1_8)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
