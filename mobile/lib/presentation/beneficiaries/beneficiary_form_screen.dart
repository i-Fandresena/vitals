import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/iso_date.dart';
import '../../domain/enums/clinical_enums.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';
import 'beneficiary_search_controller.dart';

/// Création d'un dossier bénéficiaire.
///
/// Six champs, dont trois facultatifs. Le formulaire est délibérément court :
/// il se remplit debout, devant la personne, souvent pendant qu'elle parle. Un
/// champ de plus est une raison de plus de revenir au registre papier (CDC §7).
class BeneficiaryFormScreen extends ConsumerStatefulWidget {
  const BeneficiaryFormScreen({super.key, this.prefilledName});

  /// Nom saisi dans la recherche avant de créer le dossier.
  final String? prefilledName;

  @override
  ConsumerState<BeneficiaryFormScreen> createState() =>
      _BeneficiaryFormScreenState();
}

/// Façon dont la date de naissance a été obtenue.
enum _BirthDateMode { known, estimated }

class _BeneficiaryFormScreenState extends ConsumerState<BeneficiaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _fokontanyController = TextEditingController();
  final _phoneController = TextEditingController();

  Sex? _sex;
  _BirthDateMode _birthDateMode = _BirthDateMode.known;
  DateTime? _birthDate;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Le nom vient de la recherche infructueuse : il part dans le nom de
    // famille, qui est ce que le personnel saisit en premier.
    _lastNameController.text = widget.prefilledName?.trim() ?? '';
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _ageController.dispose();
    _fokontanyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau dossier')),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: AppDimens.space16),
              ],

              TextFormField(
                controller: _lastNameController,
                enabled: !_saving,
                autofocus: widget.prefilledName == null,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le nom est obligatoire'
                    : null,
              ),
              const SizedBox(height: AppDimens.space16),

              TextFormField(
                controller: _firstNameController,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Prénom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le prénom est obligatoire'
                    : null,
              ),
              const SizedBox(height: AppDimens.space24),

              Text('Sexe', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppDimens.space8),
              _SexSelector(
                value: _sex,
                enabled: !_saving,
                onChanged: (value) => setState(() => _sex = value),
              ),
              const SizedBox(height: AppDimens.space24),

              Text('Date de naissance', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppDimens.space8),
              _BirthDateModeSelector(
                value: _birthDateMode,
                enabled: !_saving,
                onChanged: (mode) => setState(() {
                  _birthDateMode = mode;
                  _birthDate = null;
                  _ageController.clear();
                }),
              ),
              const SizedBox(height: AppDimens.space12),

              if (_birthDateMode == _BirthDateMode.known)
                _BirthDatePicker(
                  value: _birthDate,
                  enabled: !_saving,
                  onPick: _pickBirthDate,
                )
              else
                TextFormField(
                  controller: _ageController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Âge estimé',
                    suffixText: 'ans',
                    helperText:
                        'La date de naissance sera notée comme approximative.',
                    helperMaxLines: 2,
                  ),
                  validator: _validateEstimatedAge,
                ),
              const SizedBox(height: AppDimens.space24),

              TextFormField(
                controller: _fokontanyController,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Fokontany',
                  helperText: 'Facultatif',
                ),
              ),
              const SizedBox(height: AppDimens.space16),

              TextFormField(
                controller: _phoneController,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d +]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  helperText: 'Facultatif',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppDimens.space32),

              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Créer le dossier'),
              ),
              const SizedBox(height: AppDimens.space16),

              Text(
                'Le dossier est enregistré sur cet appareil immédiatement, '
                'même sans réseau.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.space32),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEstimatedAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Indiquez l'âge estimé";
    }
    final age = int.tryParse(value);
    if (age == null) return 'Saisissez un nombre';
    if (age > 120) return 'Âge invalide';
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 120),
      // Une date de naissance ne peut pas être dans le futur.
      lastDate: now,
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (_formKey.currentState?.validate() != true) return;

    if (_sex == null) {
      setState(() => _error = 'Indiquez le sexe.');
      return;
    }

    final String birthDate;
    final bool estimated;

    if (_birthDateMode == _BirthDateMode.known) {
      if (_birthDate == null) {
        setState(() => _error = 'Indiquez la date de naissance.');
        return;
      }
      birthDate = IsoDate.from(_birthDate!);
      estimated = false;
    } else {
      final age = int.parse(_ageController.text);
      final now = DateTime.now();
      // Convention explicite pour un âge estimé : le 1er juillet, milieu
      // d'année. Prendre la date du jour laisserait croire à un anniversaire,
      // et le 1er janvier décalerait systématiquement les tranches d'âge.
      birthDate = IsoDate.from(DateTime(now.year - age, 7));
      estimated = true;
    }

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;

    final csbId = auth.user.csbId;
    if (csbId == null) {
      setState(
        () => _error = "Votre profil n'est rattaché à aucun centre de santé.",
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final created = await ref
          .read(beneficiaryRepositoryProvider)
          .create(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            sex: _sex!,
            birthDate: birthDate,
            birthDateIsEstimated: estimated,
            csbId: csbId,
            createdByUserId: auth.user.id,
            phone: _phoneController.text,
            fokontany: _fokontanyController.text,
          );

      if (!mounted) return;

      // La liste de recherche doit montrer le dossier au retour.
      unawaited(ref.read(beneficiarySearchProvider.notifier).refresh());

      // On remplace l'écran plutôt que de l'empiler : revenir en arrière depuis
      // le dossier ne doit pas ramener sur un formulaire déjà validé.
      context.pushReplacement(Routes.beneficiaryPath(created.id));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is StateError
            ? error.message
            : "Le dossier n'a pas pu être enregistré. Réessayez.";
      });
    }
  }
}

class _SexSelector extends StatelessWidget {
  const _SexSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Sex? value;
  final bool enabled;
  final ValueChanged<Sex> onChanged;

  @override
  Widget build(BuildContext context) {
    // Deux grands boutons plutôt qu'une liste déroulante : un choix binaire ne
    // mérite pas deux appuis, et la cible est bien plus large.
    return Row(
      children: [
        for (final sex in Sex.values) ...[
          Expanded(
            child: _ChoiceButton(
              label: sex.label,
              selected: value == sex,
              enabled: enabled,
              onTap: () => onChanged(sex),
            ),
          ),
          if (sex != Sex.values.last) const SizedBox(width: AppDimens.space12),
        ],
      ],
    );
  }
}

class _BirthDateModeSelector extends StatelessWidget {
  const _BirthDateModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _BirthDateMode value;
  final bool enabled;
  final ValueChanged<_BirthDateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceButton(
            label: 'Date connue',
            selected: value == _BirthDateMode.known,
            enabled: enabled,
            onTap: () => onChanged(_BirthDateMode.known),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: _ChoiceButton(
            label: 'Âge estimé',
            selected: value == _BirthDateMode.estimated,
            enabled: enabled,
            onTap: () => onChanged(_BirthDateMode.estimated),
          ),
        ),
      ],
    );
  }
}

/// Bouton de choix exclusif, dimensionné pour être touché sans viser.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          height: AppDimens.fieldHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
              width: selected
                  ? AppDimens.borderWidthFocused
                  : AppDimens.borderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // La sélection est marquée par une coche autant que par la
              // couleur : au soleil, la différence de teinte peut disparaître.
              if (selected) ...[
                Icon(Icons.check, size: 20, color: scheme.onPrimaryContainer),
                const SizedBox(width: AppDimens.space8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? scheme.onPrimaryContainer : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthDatePicker extends StatelessWidget {
  const _BirthDatePicker({
    required this.value,
    required this.enabled,
    required this.onPick,
  });

  final DateTime? value;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = value == null
        ? 'Choisir la date'
        : '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return OutlinedButton.icon(
      onPressed: enabled ? onPick : null,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
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
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
