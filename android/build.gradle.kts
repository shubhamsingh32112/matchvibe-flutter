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

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
