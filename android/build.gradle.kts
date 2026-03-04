allprojects {
    repositories {
        google()
        mavenCentral()
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

// AGP 8+ requires every Android module to declare a `namespace`.
// Some older Flutter plugins still omit it, which breaks builds with:
// "Namespace not specified. Specify a namespace in the module's build file ..."
//
// This assigns a stable fallback namespace to any Android subproject that has
// an Android plugin applied but doesn't set one.
subprojects {
    fun ensureNamespace() {
        val androidExt = extensions.findByName("android") ?: return

        val currentNamespace =
            runCatching {
                androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as String?
            }.getOrNull()

        if (!currentNamespace.isNullOrBlank()) return

        val fallbackNamespace =
            when (project.name) {
                "flutter_local_notifications" -> "com.dexterous.flutterlocalnotifications"
                else -> "com.example.${project.name.replace('-', '_')}"
            }

        runCatching {
            androidExt
                .javaClass
                .getMethod("setNamespace", String::class.java)
                .invoke(androidExt, fallbackNamespace)
        }
    }

    plugins.withId("com.android.library") { ensureNamespace() }
    plugins.withId("com.android.application") { ensureNamespace() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
