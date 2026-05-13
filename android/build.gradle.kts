allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.configurations.all {
        resolutionStrategy.eachDependency { DependencyResolveDetails details ->
            if (details.requested.group == 'com.android.support') {
                details.useVersion '28.0.0'
            }
        }
    }
    
    // Add compileSdk for all subprojects including package_info_plus
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            android {
                compileSdk 34
            }
        }
    }
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
