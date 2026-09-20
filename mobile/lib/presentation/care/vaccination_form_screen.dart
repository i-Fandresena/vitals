import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/iso_date.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/care_event_dao.dart';
import '../../domain/enums/care_codes.dart';
import '../../domain/enums/clinical_enums.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';
import '../shell/ui_kit.dart';
import 'widgets/care_form_kit.dart';

/// Enregistrement d'une vaccination (ticket 2.6).
///
/// L'écran montre d'abord **ce qui a déjà été fait**, antigène par antigène.
/// C'est l'inverse d'un formulaire vierge, et c'est voulu : un carnet de
/// vaccination perdu est fréquent, et l'application devient alors la seule
/// trace. Le soignant doit voir le retard avant de saisir la dose du jour.
class VaccinationFormScreen extends ConsumerStatefulWidget {
  const VaccinationFormScreen({super.key, required this.beneficiaryId});

  final String beneficiaryId;

  @override
  ConsumerState<VaccinationFormScreen> createState() =>
      _VaccinationFormScreenState();
}

class _VaccinationFormScreenState
    extends ConsumerState<VaccinationFormScreen> {
  final _lot = TextEditingController();

  VaccineCode? _antigene;
  int _dose = 1;
  DateTime _date = DateTime.now();

  Map<VaccineCode, List<Vaccination>> _dejaFaites = {};
  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _lot.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final faites = await ref
        .read(careEventRepositoryProvider)
        .vaccinationsDe(widget.beneficiaryId);
    if (!mounted) return;
    setState(() {
      _dejaFaites = faites;
      _chargement = false;
    });
  }

  /// Dose suivante pour un antigène : celle qui manque.
  int _doseSuivante(VaccineCode antigene) {
    final faites = _dejaFaites[antigene] ?? const [];
    if (faites.isEmpty) return 1;
    final maxDose = faites.map((v) => v.doseNumber).reduce((a, b) => a > b ? a : b);
    return maxDose + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vaccination')),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                children: [
                  if (_erreur != null) FormErrorBanner(message: _erreur!),

                  const SectionTitle(
                    'Déjà administré',
                    aide: 'Selon les enregistrements de cet appareil.',
                  ),
                  _Carnet(dejaFaites: _dejaFaites),

                  const SectionTitle("Date de l'acte"),
                  ActDateField(
                    value: _date,
                    enabled: !_enregistrement,
                    onChanged: (d) => setState(() => _date = d),
                  ),

                  const SectionTitle('Antigène'),
                  ChoiceChipsField<VaccineCode>(
                    options: [
                      for (final v in VaccineCode.values)
                        if (v != VaccineCode.autre) (v, v.label),
                    ],
                    value: _antigene,
                    label: (v) => v.label,
                    enabled: !_enregistrement,
                    onChanged: (v) => setState(() {
                      _antigene = v;
                      // La dose proposée est celle qui manque : c'est le cas
                      // courant, et elle reste modifiable pour un rattrapage.
                      _dose = _doseSuivante(v);
                    }),
                  ),

                  if (_antigene != null) ...[
                    const SectionTitle('Dose'),
                    ChoiceChipsField<int>(
                      options: [
                        for (
                          var i = 1;
                          i <= (CalendrierPev.dosesParAntigene[_antigene!.code] ?? 5);
                          i++
                        )
                          (i, 'Dose $i'),
                      ],
                      value: _dose,
                      label: (d) => 'Dose $d',
                      enabled: !_enregistrement,
                      onChanged: (d) => setState(() => _dose = d),
                    ),
                    if (_dose > _doseSuivante(_antigene!))
                      Padding(
                        padding: const EdgeInsets.only(top: AppDimens.space8),
                        child: Text(
                          'Les doses précédentes ne sont pas enregistrées. '
                          'Vérifiez le carnet avant de valider.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],

                  const SectionTitle(
                    'Numéro de lot',
                    aide: 'Facultatif. Utile en cas de rappel de lot.',
                  ),
                  TextFormField(
                    controller: _lot,
                    enabled: !_enregistrement,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Facultatif'),
                  ),

                  const SizedBox(height: AppDimens.space32),
                  FilledButton(
                    onPressed: _enregistrement || _antigene == null
                        ? null
                        : _enregistrer,
                    child: _enregistrement
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Enregistrer la vaccination'),
                  ),
                  const SizedBox(height: AppDimens.space32),
                ],
              ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn || _antigene == null) return;

    setState(() => _enregistrement = true);

    try {
      await ref
          .read(careEventRepositoryProvider)
          .enregistrerVaccination(
            beneficiaryId: widget.beneficiaryId,
            vaccine: _antigene!,
            doseNumber: _dose,
            occurredOn: IsoDate.from(_date),
            recordedByUserId: auth.user.id,
            lotNumber: _lot.text,
          );

      if (!mounted) return;
      context.pop(true);
    } on VaccinationDejaEnregistree catch (e) {
      // Le doublon le plus probable : deux soignants, ou un retour en arrière
      // dans le formulaire. On l'explique plutôt que d'afficher une erreur de
      // base de données.
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = "La vaccination n'a pas pu être enregistrée. $e";
      });
    }
  }
}

/// Ce qui a déjà été administré, antigène par antigène.
class _Carnet extends StatelessWidget {
  const _Carnet({required this.dejaFaites});

  final Map<VaccineCode, List<Vaccination>> dejaFaites;

  @override
  Widget build(BuildContext context) {
    if (dejaFaites.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const TileIcon(Icons.vaccines_outlined, taille: 36),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Text(
                'Aucune vaccination enregistrée pour cette personne.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Wrap(
        spacing: AppDimens.space8,
        runSpacing: AppDimens.space8,
        children: [
          for (final entree in dejaFaites.entries)
            StatusPill(
              '${entree.key.label} · '
              '${entree.value.map((v) => v.doseNumber).join(", ")}',
              tone: StatusTone.succes,
              icone: Icons.check,
            ),
        ],
      ),
    );
  }
}
