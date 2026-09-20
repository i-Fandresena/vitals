/// Briques communes aux trois formulaires de saisie (tickets 2.4 à 2.6).
///
/// Elles partagent une contrainte : la saisie se fait debout, souvent pendant
/// que la personne parle. D'où des cibles larges, des choix à un seul appui, et
/// des champs numériques qui ouvrent le bon clavier du premier coup.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';

/// Titre de section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.texte, {super.key, this.aide});

  final String texte;
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.space24,
        bottom: AppDimens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texte, style: theme.textTheme.titleSmall),
          if (aide != null) ...[
            const SizedBox(height: AppDimens.space2),
            Text(aide!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Choix unique parmi une liste, en grands boutons.
///
/// Préféré à une liste déroulante tant que la liste tient à l'écran : un menu
/// coûte deux appuis et masque les options, un bouton en coûte un et les
/// montre toutes.
class ChoiceChipsField<T> extends StatelessWidget {
  const ChoiceChipsField({
    super.key,
    required this.options,
    required this.value,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  final List<(T, String)> options;
  final T? value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppDimens.space8,
      runSpacing: AppDimens.space8,
      children: [
        for (final (valeur, libelle) in options)
          _Chip(
            libelle: libelle,
            selectionne: value == valeur,
            enabled: enabled,
            onTap: () => onChanged(valeur),
            scheme: scheme,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.libelle,
    required this.selectionne,
    required this.enabled,
    required this.onTap,
    required this.scheme,
  });

  final String libelle;
  final bool selectionne;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne ? scheme.primaryContainer : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppDimens.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            border: Border.all(
              color: selectionne ? scheme.primary : scheme.outline,
              width: selectionne
                  ? AppDimens.borderWidthFocused
                  : AppDimens.borderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // La coche double la couleur : au soleil, la différence de
              // teinte peut disparaître, pas la forme.
              if (selectionne) ...[
                Icon(Icons.check, size: 18, color: scheme.onPrimaryContainer),
                const SizedBox(width: AppDimens.space4),
              ],
              Text(
                libelle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selectionne ? scheme.onPrimaryContainer : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Case à cocher à grande cible, avec son explication.
class CheckField extends StatelessWidget {
  const CheckField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.aide,
    this.enabled = true,
  });

  final bool value;
  final String label;
  final String? aide;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            ),
            const SizedBox(width: AppDimens.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimens.space12),
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  if (aide != null)
                    Text(aide!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Champ numérique avec unité.
///
/// Toujours facultatif : un poids qu'on n'a pas pesé ne doit pas empêcher
/// d'enregistrer la consultation. Une valeur absente est plus honnête qu'une
/// valeur inventée pour satisfaire un formulaire.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.unite,
    this.decimales = false,
    this.enabled = true,
    this.min,
    this.max,
  });

  final TextEditingController controller;
  final String label;
  final String unite;
  final bool decimales;
  final bool enabled;
  final num? min;
  final num? max;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: decimales),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimales ? RegExp(r'[\d.,]') : RegExp(r'\d'),
        ),
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: unite,
        helperText: 'Facultatif',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final valeur = double.tryParse(v.replaceAll(',', '.'));
        if (valeur == null) return 'Valeur invalide';
        if (min != null && valeur < min!) return 'Valeur trop basse';
        if (max != null && valeur > max!) return 'Valeur trop haute';
        return null;
      },
    );
  }
}

/// Lit un champ numérique facultatif.
double? lireDecimal(TextEditingController c) {
  final t = c.text.trim().replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

int? lireEntier(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : int.tryParse(t);
}

/// Bandeau d'erreur persistant, repris des autres écrans.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.space16),
      padding: const EdgeInsets.all(AppDimens.space16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de date d'acte, par défaut aujourd'hui.
///
/// Reste modifiable : un acte fait en brousse est souvent saisi le lendemain,
/// et les indicateurs doivent compter le jour de l'acte, pas celui de la
/// saisie.
class ActDateField extends StatelessWidget {
  const ActDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final aujourdhui = DateTime.now();
    final estAujourdhui =
        value.year == aujourdhui.year &&
        value.month == aujourdhui.month &&
        value.day == aujourdhui.day;

    return OutlinedButton.icon(
      onPressed: enabled
          ? () async {
              final choisie = await showDatePicker(
                context: context,
                initialDate: value,
                // Un acte ne peut pas être futur, et remonter au-delà d'un an
                // relève de la reprise d'archives, pas de la saisie courante.
                firstDate: aujourdhui.subtract(const Duration(days: 365)),
                lastDate: aujourdhui,
                helpText: "Date de l'acte",
                cancelText: 'Annuler',
                confirmText: 'Valider',
              );
              if (choisie != null) onChanged(choisie);
            }
          : null,
      icon: const Icon(Icons.event),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          estAujourdhui
              ? "Aujourd'hui"
              : '${value.day.toString().padLeft(2, '0')}/'
                    '${value.month.toString().padLeft(2, '0')}/${value.year}',
        ),
      ),
    );
  }
}
