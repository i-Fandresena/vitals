import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/iso_date.dart';
import '../../domain/enums/care_codes.dart';
import '../../domain/enums/clinical_enums.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';
import 'widgets/care_form_kit.dart';

/// Enregistrement d'une consultation (ticket 2.4).
///
/// Deux champs obligatoires seulement : le motif et le type. Tout le reste est
/// facultatif — un poids qu'on n'a pas pesé, une tension qu'on n'a pas prise,
/// c'est le quotidien d'un CSB. Exiger ces valeurs produirait des chiffres
/// inventés pour satisfaire le formulaire, ce qui est pire qu'une case vide.
///
/// Le motif est **codé et non libre** : c'est ce qui rend les consultations
/// dénombrables dans les indicateurs. Le texte libre existe, mais en bas, et
/// il n'est jamais agrégé.
class ConsultationFormScreen extends ConsumerStatefulWidget {
  const ConsultationFormScreen({super.key, required this.beneficiaryId});

  final String beneficiaryId;

  @override
  ConsumerState<ConsultationFormScreen> createState() =>
      _ConsultationFormScreenState();
}

class _ConsultationFormScreenState
    extends ConsumerState<ConsultationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poids = TextEditingController();
  final _temperature = TextEditingController();
  final _tensionSys = TextEditingController();
  final _tensionDia = TextEditingController();
  final _refereA = TextEditingController();
  final _notes = TextEditingController();

  ConsultationType _type = ConsultationType.curative;
  MotifConsultation? _motif;
  DateTime _date = DateTime.now();
  bool _traitement = false;
  bool _refere = false;

  bool _enregistrement = false;
  String? _erreur;

  @override
  void dispose() {
    _poids.dispose();
    _temperature.dispose();
    _tensionSys.dispose();
    _tensionDia.dispose();
    _refereA.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle consultation')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            children: [
              if (_erreur != null) FormErrorBanner(message: _erreur!),

              const SectionTitle("Date de l'acte"),
              ActDateField(
                value: _date,
                enabled: !_enregistrement,
                onChanged: (d) => setState(() => _date = d),
              ),

              const SectionTitle('Type de consultation'),
              ChoiceChipsField<ConsultationType>(
                options: [
                  for (final t in ConsultationType.values)
                    if (t != ConsultationType.postnatale) (t, t.label),
                ],
                value: _type,
                label: (t) => t.label,
                enabled: !_enregistrement,
                onChanged: (t) => setState(() => _type = t),
              ),

              const SectionTitle(
                'Motif',
                aide: 'Obligatoire. Sert au dénombrement des indicateurs.',
              ),
              ChoiceChipsField<MotifConsultation>(
                options: [
                  for (final m in MotifConsultation.values) (m, m.label),
                ],
                value: _motif,
                label: (m) => m.label,
                enabled: !_enregistrement,
                onChanged: (m) => setState(() => _motif = m),
              ),

              const SectionTitle(
                'Mesures',
                aide: 'Laisser vide si la mesure n\'a pas été prise.',
              ),
              NumberField(
                controller: _poids,
                label: 'Poids',
                unite: 'kg',
                decimales: true,
                enabled: !_enregistrement,
                min: 0.5,
                max: 250,
              ),
              const SizedBox(height: AppDimens.space16),
              NumberField(
                controller: _temperature,
                label: 'Température',
                unite: '°C',
                decimales: true,
                enabled: !_enregistrement,
                min: 30,
                max: 45,
              ),
              const SizedBox(height: AppDimens.space16),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      controller: _tensionSys,
                      label: 'Tension haute',
                      unite: 'mmHg',
                      enabled: !_enregistrement,
                      min: 50,
                      max: 260,
                    ),
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: NumberField(
                      controller: _tensionDia,
                      label: 'Tension basse',
                      unite: 'mmHg',
                      enabled: !_enregistrement,
                      min: 30,
                      max: 160,
                    ),
                  ),
                ],
              ),

              const SectionTitle('Suites'),
              CheckField(
                value: _traitement,
                label: 'Un traitement a été donné',
                enabled: !_enregistrement,
                onChanged: (v) => setState(() => _traitement = v),
              ),
              CheckField(
                value: _refere,
                label: 'Référé vers une structure supérieure',
                aide: 'À cocher aussi quand la personne refuse de s\'y rendre.',
                enabled: !_enregistrement,
                onChanged: (v) => setState(() => _refere = v),
              ),
              if (_refere) ...[
                const SizedBox(height: AppDimens.space8),
                TextFormField(
                  controller: _refereA,
                  enabled: !_enregistrement,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Référé à',
                    helperText: 'Nom de la structure',
                  ),
                ),
              ],

              const SectionTitle(
                'Observation',
                aide: 'Texte libre. Jamais utilisé dans les statistiques.',
              ),
              TextFormField(
                controller: _notes,
                enabled: !_enregistrement,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Facultatif',
                ),
              ),

              const SizedBox(height: AppDimens.space32),
              FilledButton(
                onPressed: _enregistrement ? null : _enregistrer,
                child: _enregistrement
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Enregistrer la consultation'),
              ),
              const SizedBox(height: AppDimens.space16),
              Text(
                'Enregistré sur cet appareil immédiatement, même sans réseau.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.space32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreur = null);

    if (_formKey.currentState?.validate() != true) return;

    if (_motif == null) {
      setState(() => _erreur = 'Choisissez un motif de consultation.');
      return;
    }

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;

    setState(() => _enregistrement = true);

    try {
      await ref
          .read(careEventRepositoryProvider)
          .enregistrerConsultation(
            beneficiaryId: widget.beneficiaryId,
            type: _type,
            occurredOn: IsoDate.from(_date),
            motiveCode: _motif!.code,
            recordedByUserId: auth.user.id,
            weightKg: lireDecimal(_poids),
            temperatureC: lireDecimal(_temperature),
            bloodPressureSys: lireEntier(_tensionSys),
            bloodPressureDia: lireEntier(_tensionDia),
            treatmentGiven: _traitement,
            referred: _refere,
            referredTo: _refere ? _refereA.text : null,
            notes: _notes.text,
          );

      if (!mounted) return;
      context.pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = "La consultation n'a pas pu être enregistrée. $e";
      });
    }
  }
}

/// Identifiants des actes, générés sur l'appareil comme les dossiers.
const uuid = Uuid();
