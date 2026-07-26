allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox ships its Android SDK from a private Maven repo that requires
        // a secret download token (sk.… with the DOWNLOADS:READ scope).
        //
        // The token is deliberately NOT stored in this repository. Put it in
        // ~/.gradle/gradle.properties as:
        //     MAPBOX_DOWNLOADS_TOKEN=sk.your_token
        // or export it as the MAPBOX_DOWNLOADS_TOKEN environment variable.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication { create<BasicAuthentication>("basic") }
            credentials {
                // Mapbox requires this exact literal username.
                username = "mapbox"
                password = (project.findProperty("MAPBOX_DOWNLOADS_TOKEN")
                    ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN")
                    ?: "") as String
            }
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
