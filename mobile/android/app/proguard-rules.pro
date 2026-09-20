# Règles de minification pour le build de release.

# Drift et SQLite : les bibliothèques natives sont chargées par réflexion.
-keep class com.tekartik.sqflite.** { *; }
-keep class org.sqlite.** { *; }

# mobile_scanner s'appuie sur ML Kit, qui charge ses modèles dynamiquement.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# flutter_secure_storage utilise le Keystore Android via androidx.security.
-keep class androidx.security.crypto.** { *; }

# Retire les appels de journalisation du binaire de release : aucune trace ne
# doit pouvoir contenir de donnée patient sur un appareil distribué.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
