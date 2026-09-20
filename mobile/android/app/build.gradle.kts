import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Coordonnées du keystore de signature, lues depuis android/key.properties.
//
// Ce fichier et le keystore lui-même ne sont JAMAIS versionnés : quiconque les
// possède peut publier une mise à jour que les appareils installeront comme
// authentique. Voir docs/04-deploiement.md pour les créer.
//
// Absent, le build de release retombe sur la clé de debug — pratique pour
// tester, mais l'APK produit n'est pas distribuable.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.containsKey("storeFile")

android {
    namespace = "ai.maternal.vitals"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ai.maternal.vitals"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")

                // v1 est l'ancienne signature JAR, inutile à partir d'Android 7
                // (minSdk 24) et connue pour la faille Janus.
                enableV1Signing = false
                enableV2Signing = true

                // v3 porte la rotation de clé. La clé de signature est
                // irremplaçable : si elle fuit un jour, v3 est ce qui
                // permettra d'en changer sans faire réinstaller l'application
                // dans chaque centre. Cela ne coûte rien aujourd'hui.
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Permet à `flutter build apk --release` de fonctionner sans
                // keystore, pour mesurer une taille ou tester localement.
                // L'APK produit ne doit pas être distribué.
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Avertit au moment du build plutôt qu'à la distribution : un APK signé avec
// la clé de debug ne peut pas être mis à jour par un APK correctement signé,
// et la clé de debug diffère d'une machine à l'autre.
gradle.taskGraph.whenReady {
    if (!hasReleaseKeystore && allTasks.any { it.name.contains("Release") }) {
        logger.warn(
            "\n  ⚠  Build de release SANS keystore : signé avec la clé de debug.\n" +
                "     Cet APK ne doit pas être distribué. Voir docs/04-deploiement.md.\n",
        )
    }
}

flutter {
    source = "../.."
}
