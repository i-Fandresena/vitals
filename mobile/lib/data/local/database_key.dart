import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Clé de chiffrement de la base locale (ticket 3.3).
///
/// La base d'un téléphone de CSB contient des dossiers de santé. Un appareil
/// perdu, volé, ou simplement prêté finit entre d'autres mains, et le fichier
/// SQLite d'une application Android est extractible dès que l'appareil est
/// déverrouillé ou rooté. Sans chiffrement, tout s'y lit en clair.
///
/// **La clé ne quitte jamais le matériel sécurisé.** Elle est tirée au premier
/// lancement et rangée dans le coffre du système, qui s'appuie sur le Keystore
/// Android : elle n'est donc pas lisible en extrayant le stockage de
/// l'application, et elle n'est ni dérivée d'un mot de passe, ni transmise au
/// serveur, ni sauvegardée.
///
/// Conséquence assumée : **une réinitialisation du téléphone rend la base
/// illisible.** Les dossiers déjà synchronisés se retrouvent au prochain
/// téléchargement ; ce qui n'avait jamais été envoyé est perdu. C'est le prix
/// d'une clé que personne ne peut ressortir, et la raison pour laquelle la
/// synchronisation doit tourner régulièrement.
class DatabaseKey {
  DatabaseKey([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _cle = 'db.encryption_key';

  /// Marque du passage à une base chiffrée. Sa présence signale que la base
  /// non chiffrée d'avant le ticket 3.3 a déjà été écartée.
  static const _marqueChiffrement = 'db.encrypted_since';

  /// Renvoie la clé, en la créant au premier appel.
  ///
  /// 32 octets tirés du générateur cryptographique du système, encodés en
  /// hexadécimal : c'est la forme qu'attend `PRAGMA key` sous la notation
  /// `x'...'`, qui évite toute dérivation supplémentaire.
  Future<String> obtenir() async {
    final existante = await _storage.read(key: _cle);
    if (existante != null && existante.length == 64) return existante;

    final aleatoire = Random.secure();
    final octets = List<int>.generate(32, (_) => aleatoire.nextInt(256));
    final hexa = octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _cle, value: hexa);
    return hexa;
  }

  /// Vrai si l'appareil n'a jamais ouvert de base chiffrée.
  Future<bool> premierChiffrement() async =>
      await _storage.read(key: _marqueChiffrement) == null;

  Future<void> marquerChiffre() =>
      _storage.write(key: _marqueChiffrement, value: DateTime.now().toIso8601String());

  /// Efface la clé. La base devient définitivement illisible.
  ///
  /// N'est appelé que lorsque la base elle-même est supprimée : garder une clé
  /// orpheline n'a pas d'usage, et en garder une qui ne correspond plus à rien
  /// empêcherait d'en créer une nouvelle.
  Future<void> effacer() async {
    await _storage.delete(key: _cle);
    await _storage.delete(key: _marqueChiffrement);
  }

  /// Vérifie qu'une clé est bien formée. Utilisé par les tests.
  static bool estValide(String cle) =>
      cle.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(cle);

  /// Échappe la clé pour `PRAGMA key`.
  ///
  /// La notation `x'...'` passe les octets bruts, sans que SQLCipher n'applique
  /// sa dérivation PBKDF2 : la clé étant déjà aléatoire sur 256 bits, la
  /// dériver n'ajouterait rien et ralentirait chaque ouverture.
  static String pragma(String cleHexa) => "x'$cleHexa'";

  /// Empreinte non réversible, pour les diagnostics.
  ///
  /// Permet de constater que deux ouvertures utilisent bien la même clé sans
  /// jamais l'afficher.
  static String empreinte(String cleHexa) =>
      base64Url.encode(utf8.encode(cleHexa)).substring(0, 8);
}
