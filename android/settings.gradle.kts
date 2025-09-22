// File: C:/DBSpartiti/jamset/android/settings.gradle.kts
import java.util.Properties // Questo import è ancora utile per chiarezza, anche se usiamo il nome completo sotto
import java.io.File // Importa java.io.File esplicitamente

pluginManagement {
    val flutterSdkPath = run {
        // --- MODIFICA QUI ---
        val properties = java.util.Properties() // Usa il nome completo per l'istanza
        // Costruisci l'oggetto File in modo più esplicito
        // rootProject.projectDir qui si riferisce alla cartella 'android'
        val localPropertiesFile = File(rootProject.projectDir, "local.properties")

        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { input -> // Esplicita il nome del parametro lambda
                properties.load(input)
            }
        } else {
            // Gestisci il caso in cui local.properties non esista
            // Questo causerà un errore più avanti con requireNotNull se flutter.sdk non è impostato,
            // il che è corretto per segnalare una configurazione mancante.
            println("ATTENZIONE: Il file local.properties non è stato trovato in ${rootProject.projectDir}. Assicurati che esista e contenga 'flutter.sdk'.")
        }

        val flutterSdkPathValue = properties.getProperty("flutter.sdk")
        // requireNotNull è più idiomatico in Kotlin per questo tipo di controllo
        requireNotNull(flutterSdkPathValue) {
            "La proprietà 'flutter.sdk' non è impostata nel file 'local.properties' (${localPropertiesFile.absolutePath}) o il file non è stato trovato."
        }
        flutterSdkPathValue // Restituisce il valore
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Le versioni di AGP e Kotlin dovrebbero essere compatibili con la tua versione di Gradle.
    // Se continui ad avere problemi, considera di usare versioni più stabili e comuni.
    // Esempio: id("com.android.application") version "8.2.1" apply false
    // Esempio: id("org.jetbrains.kotlin.android") version "1.9.22" apply false
    id("com.android.application") version "8.7.3" apply false // Potresti dover abbassare questa versione se i problemi persistono
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false // E anche questa
}

// Include il modulo principale della tua applicazione Android
include(":app")

/**
 * Logica per caricare dinamicamente i plugin Flutter come sottomoduli Gradle.
 * Questo permette ad Android Studio e Gradle di "vedere" il codice nativo dei plugin.
 */
val flutterProjectRoot = rootProject.projectDir.parentFile // projectDir qui è 'android', quindi parentFile è la radice del progetto Flutter
val pluginsFile = File(flutterProjectRoot, ".flutter-plugins") // Usa l'import di java.io.File

if (pluginsFile.exists()) {
    // --- MODIFICA ANCHE QUI ---
    val plugins = java.util.Properties() // Usa il nome completo per l'istanza
    pluginsFile.inputStream().use { input -> // Esplicita il nome del parametro lambda
        plugins.load(input)
    }
    plugins.forEach { name, path ->
        // Il percorso nel file .flutter-plugins è relativo alla radice del progetto Flutter
        val pluginDirectory = File(flutterProjectRoot, path as String) // Usa l'import di java.io.File
        val androidPluginDirectory = File(pluginDirectory, "android") // Usa l'import di java.io.File
        if (androidPluginDirectory.exists()) {
            include(":$name")
            project(":$name").projectDir = androidPluginDirectory
        }
    }
}

