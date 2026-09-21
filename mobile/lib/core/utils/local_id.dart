/// Identifiant lisible d'un dossier bénéficiaire, et encodage du QR code.
///
/// Deux identifiants coexistent, volontairement (voir `docs/00-decisions-techniques.md`) :
///
/// - l'**UUID v7**, clé technique, seule valeur qui circule entre appareils ;
/// - l'**identifiant lisible** `CSB-0142-26-00731`, qui n'a aucun rôle
///   technique. Il sert à dire un dossier à voix haute et à faire le lien avec
///   le registre papier pendant la transition.
///
/// La séquence est locale au centre et repart à 1 chaque année. Elle se calcule
/// donc sans réseau, ce qui est indispensable : un dossier doit pouvoir être
/// créé en brousse, sans que deux centres puissent produire le même numéro.
library;

abstract final class LocalId {
  const LocalId._();

  /// Préfixe du schéma d'URI porté par le QR code.
  ///
  /// Le QR n'encode **que l'UUID** : ni nom, ni date de naissance, ni donnée de
  /// santé. Une carte perdue ou photographiée ne révèle donc rien ; elle n'est
  /// exploitable que par quelqu'un déjà authentifié dans l'application.
  static const String qrScheme = 'vitals:b/';

  /// Construit `CSB-<code>-<AA>-<séquence>`.
  ///
  /// [csbCode] est le code du centre, [year] l'année complète, [sequence] le
  /// rang du dossier dans l'année.
  static String format({
    required String csbCode,
    required int year,
    required int sequence,
  }) {
    final shortYear = (year % 100).toString().padLeft(2, '0');
    // Cinq chiffres : un CSB très actif enregistre quelques milliers de
    // dossiers par an, la marge est confortable sans allonger la lecture.
    final number = sequence.toString().padLeft(5, '0');
    return 'CSB-$csbCode-$shortYear-$number';
  }

  /// Encode un UUID pour un QR code.
  static String toQrPayload(String beneficiaryId) => '$qrScheme$beneficiaryId';

  /// Relit le contenu d'un QR code et renvoie l'UUID, ou `null`.
  ///
  /// Renvoie `null` sur tout code étranger à l'application — un QR de produit,
  /// une URL, un code d'un autre logiciel. Le scanner doit pouvoir dire « ce
  /// code n'est pas un dossier MbolaTsara » plutôt que d'ouvrir n'importe quoi.
  static String? parseQrPayload(String? raw) {
    if (raw == null) return null;

    final trimmed = raw.trim();
    if (!trimmed.startsWith(qrScheme)) return null;

    final id = trimmed.substring(qrScheme.length);
    return _isUuid(id) ? id : null;
  }

  /// Vrai si la chaîne ressemble à un identifiant lisible saisi à la main.
  ///
  /// Sert à aiguiller la recherche : une saisie de cette forme cherche un
  /// identifiant exact, toute autre saisie cherche un nom.
  static bool looksLikeLocalId(String input) =>
      _localIdPattern.hasMatch(input.trim().toUpperCase());

  /// Normalise une saisie manuelle : majuscules, espaces retirés.
  ///
  /// Un agent qui recopie un numéro depuis un carnet écrit aussi bien
  /// `csb-0142-26-00731` que `CSB 0142 26 00731`.
  static String normalize(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'[\s_]+'), '-');

  static final RegExp _localIdPattern = RegExp(
    r'^CSB-[A-Z0-9]+-\d{2}-\d{1,6}$',
  );

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isUuid(String value) => _uuidPattern.hasMatch(value);
}
