import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/iso_date.dart';
import '../../data/local/app_database.dart';
import '../../domain/enums/care_codes.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';
import '../shell/ui_kit.dart';
import 'widgets/care_form_kit.dart';

/// Suivi de grossesse et consultation prénatale (ticket 2.5).
///
/// L'écran ouvre la grossesse si elle n'existe pas encore, puis enchaîne sur
/// la CPN : en consultation, ces deux gestes n'en font qu'un, et les séparer
/// en deux écrans ferait abandonner la saisie au milieu.
///
/// Les quatre interventions systématiques — VAT, fer-acide folique, prévention
/// du paludisme, moustiquaire — sont des cases distinctes et non une liste
/// d'actes : ce sont exactement les indicateurs que le centre doit remonter,
/// et les noyer dans du texte libre les rendrait incomptables.
class AntenatalFormScreen extends ConsumerStatefulWidget {
  const AntenatalFormScreen({super.key, required this.beneficiaryId});

  final String beneficiaryId;

  @override
  ConsumerState<AntenatalFormScreen> createState() =>
      _AntenatalFormScreenState();
}

class _AntenatalFormScreenState extends ConsumerState<AntenatalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gravida = TextEditingController();
  final _para = TextEditingController();
  final _poids = TextEditingController();
  final _tensionSys = TextEditingController();
  final _tensionDia = TextEditingController();
  final _hauteurUterine = TextEditingController();
  final _rythmeCardiaque = TextEditingController();
  final _refereA = TextEditingController();
  final _notes = TextEditingController();

  Pregnancy? _grossesse;
  List<PrenatalVisit> _cpnFaites = [];

  DateTime _date = DateTime.now();
  DateTime? _ddr;
  final Set<FacteurRisqueCpn> _risques = {};
  bool _vat = false;
  bool _fer = false;
  bool _paludisme = false;
  bool _moustiquaire = false;
  bool _refere = false;

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
    for (final c in [
      _gravida,
      _para,
      _poids,
      _tensionSys,
      _tensionDia,
      _hauteurUterine,
      _rythmeCardiaque,
      _refereA,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    final depot = ref.read(careEventRepositoryProvider);
    final grossesse = await depot.grossesseEnCours(widget.beneficiaryId);
    final cpn = grossesse == null ? <PrenatalVisit>[] : await depot.cpnDe(grossesse.id);

    if (!mounted) return;
    setState(() {
      _grossesse = grossesse;
      _cpnFaites = cpn;
      _ddr = IsoDate.parse(grossesse?.lastPeriodDate);
      _chargement = false;
    });
  }

  int get _rangCpn => _cpnFaites.length + 1;

  /// Âge gestationnel estimé, en semaines depuis les dernières règles.
  int? get _ageGestationnel {
    if (_ddr == null) return null;
    final jours = _date.difference(_ddr!).inDays;
    return jours < 0 ? null : jours ~/ 7;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarSuivi(rang: _rangCpn, nouvelle: _grossesse == null),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  children: [
                    if (_erreur != null) FormErrorBanner(message: _erreur!),

                    _Resume(
                      grossesse: _grossesse,
                      cpnFaites: _cpnFaites.length,
                      ageGestationnel: _ageGestationnel,
                    ),

                    const SectionTitle("Date de l'acte"),
                    ActDateField(
                      value: _date,
                      enabled: !_enregistrement,
                      onChanged: (d) => setState(() => _date = d),
                    ),

                    if (_grossesse == null) ...[
                      const SectionTitle(
                        'Ouverture du suivi',
                        aide:
                            'La date des dernières règles sert à estimer le '
                            'terme. Beaucoup de femmes ne la connaissent pas : '
                            'elle reste facultative.',
                      ),
                      OutlinedButton.icon(
                        onPressed: _enregistrement ? null : _choisirDdr,
                        icon: const Icon(Icons.event_outlined),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _ddr == null
                                ? 'Dernières règles — inconnues'
                                : 'Dernières règles : '
                                      '${_ddr!.day.toString().padLeft(2, '0')}/'
                                      '${_ddr!.month.toString().padLeft(2, '0')}/'
                                      '${_ddr!.year}',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.space16),
                      Row(
                        children: [
                          Expanded(
                            child: NumberField(
                              controller: _gravida,
                              label: 'Grossesses',
                              unite: 'total',
                              enabled: !_enregistrement,
                              min: 1,
                              max: 20,
                            ),
                          ),
                          const SizedBox(width: AppDimens.space12),
                          Expanded(
                            child: NumberField(
                              controller: _para,
                              label: 'Accouchements',
                              unite: 'total',
                              enabled: !_enregistrement,
                              max: 20,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SectionTitle('Mesures'),
                    NumberField(
                      controller: _poids,
                      label: 'Poids',
                      unite: 'kg',
                      decimales: true,
                      enabled: !_enregistrement,
                      min: 30,
                      max: 200,
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
                    const SizedBox(height: AppDimens.space16),
                    Row(
                      children: [
                        Expanded(
                          child: NumberField(
                            controller: _hauteurUterine,
                            label: 'Hauteur utérine',
                            unite: 'cm',
                            decimales: true,
                            enabled: !_enregistrement,
                            max: 50,
                          ),
                        ),
                        const SizedBox(width: AppDimens.space12),
                        Expanded(
                          child: NumberField(
                            controller: _rythmeCardiaque,
                            label: 'Cœur fœtal',
                            unite: '/min',
                            enabled: !_enregistrement,
                            min: 60,
                            max: 220,
                          ),
                        ),
                      ],
                    ),

                    const SectionTitle(
                      'Interventions',
                      aide: 'Cocher ce qui a été fait aujourd\'hui.',
                    ),
                    CheckField(
                      value: _vat,
                      label: 'Vaccin antitétanique (VAT)',
                      enabled: !_enregistrement,
                      onChanged: (v) => setState(() => _vat = v),
                    ),
                    CheckField(
                      value: _fer,
                      label: 'Fer et acide folique',
                      enabled: !_enregistrement,
                      onChanged: (v) => setState(() => _fer = v),
                    ),
                    CheckField(
                      value: _paludisme,
                      label: 'Traitement préventif du paludisme',
                      enabled: !_enregistrement,
                      onChanged: (v) => setState(() => _paludisme = v),
                    ),
                    CheckField(
                      value: _moustiquaire,
                      label: 'Moustiquaire imprégnée remise',
                      enabled: !_enregistrement,
                      onChanged: (v) => setState(() => _moustiquaire = v),
                    ),

                    const SectionTitle(
                      'Facteurs de risque',
                      aide:
                          'Ceux qui justifient une référence. Laisser vide '
                          's\'il n\'y en a aucun.',
                    ),
                    Wrap(
                      spacing: AppDimens.space8,
                      runSpacing: AppDimens.space8,
                      children: [
                        for (final r in FacteurRisqueCpn.values)
                          FilterChip(
                            label: Text(r.label),
                            selected: _risques.contains(r),
                            onSelected: _enregistrement
                                ? null
                                : (choisi) => setState(() {
                                    choisi ? _risques.add(r) : _risques.remove(r);
                                  }),
                          ),
                      ],
                    ),

                    const SectionTitle('Suites'),
                    CheckField(
                      value: _refere,
                      label: 'Référée vers une structure supérieure',
                      enabled: !_enregistrement,
                      onChanged: (v) => setState(() => _refere = v),
                    ),
                    if (_refere) ...[
                      const SizedBox(height: AppDimens.space8),
                      TextFormField(
                        controller: _refereA,
                        enabled: !_enregistrement,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Référée à'),
                      ),
                    ],

                    const SectionTitle('Observation'),
                    TextFormField(
                      controller: _notes,
                      enabled: !_enregistrement,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Facultatif'),
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
                          : Text('Enregistrer la CPN $_rangCpn'),
                    ),
                    const SizedBox(height: AppDimens.space16),
                    if (_risques.isNotEmpty && !_refere)
                      Text(
                        '${_risques.length} facteur(s) de risque relevé(s) sans '
                        'référence. Vérifiez que c\'est bien voulu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: AppDimens.space32),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _choisirDdr() async {
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _ddr ?? aujourdhui.subtract(const Duration(days: 90)),
      // Une grossesse dure moins de 300 jours : au-delà, c'est une erreur de
      // saisie, pas une grossesse très longue.
      firstDate: aujourdhui.subtract(const Duration(days: 300)),
      lastDate: aujourdhui,
      helpText: 'Date des dernières règles',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (choisie != null) setState(() => _ddr = choisie);
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreur = null);

    if (_formKey.currentState?.validate() != true) return;

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;

    setState(() => _enregistrement = true);

    try {
      final depot = ref.read(careEventRepositoryProvider);

      // Ouvre la grossesse au besoin, puis enchaîne : les deux écritures
      // partagent la file de synchronisation et l'ordre est garanti par
      // l'identifiant de la grossesse, créé avant la CPN qui le référence.
      final grossesse =
          _grossesse ??
          await depot.ouvrirGrossesse(
            beneficiaryId: widget.beneficiaryId,
            createdByUserId: auth.user.id,
            lastPeriodDate: _ddr,
            gravida: lireEntier(_gravida),
            para: lireEntier(_para),
          );

      await depot.enregistrerCpn(
        pregnancyId: grossesse.id,
        beneficiaryId: widget.beneficiaryId,
        visitNumber: _rangCpn,
        occurredOn: IsoDate.from(_date),
        recordedByUserId: auth.user.id,
        gestationalAgeWeeks: _ageGestationnel,
        weightKg: lireDecimal(_poids),
        bloodPressureSys: lireEntier(_tensionSys),
        bloodPressureDia: lireEntier(_tensionDia),
        fundalHeightCm: lireDecimal(_hauteurUterine),
        fetalHeartRate: lireEntier(_rythmeCardiaque),
        tetanusVaccineGiven: _vat,
        ironFolateGiven: _fer,
        malariaPreventionGiven: _paludisme,
        insecticideNetGiven: _moustiquaire,
        riskFactorCodes: _risques.map((r) => r.code).toList(),
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
        _erreur = "La consultation prénatale n'a pas pu être enregistrée. $e";
      });
    }
  }
}

/// Barre de titre qui dit où l'on en est du suivi.
class AppBarSuivi extends StatelessWidget implements PreferredSizeWidget {
  const AppBarSuivi({super.key, required this.rang, required this.nouvelle});

  final int rang;
  final bool nouvelle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(nouvelle ? 'Nouveau suivi de grossesse' : 'CPN $rang'),
    );
  }
}

/// Rappel de l'état du suivi, avant la saisie.
class _Resume extends StatelessWidget {
  const _Resume({
    required this.grossesse,
    required this.cpnFaites,
    required this.ageGestationnel,
  });

  final Pregnancy? grossesse;
  final int cpnFaites;
  final int? ageGestationnel;

  @override
  Widget build(BuildContext context) {
    if (grossesse == null) {
      return AppCard(
        child: Row(
          children: [
            const TileIcon(Icons.pregnant_woman_outlined, taille: 36),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Text(
                'Aucun suivi en cours. Il sera ouvert en enregistrant cette '
                'première consultation prénatale.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    final terme = IsoDate.parse(grossesse!.expectedDeliveryOn);

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suivi en cours',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppDimens.space12),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              StatusPill(
                '$cpnFaites CPN faite${cpnFaites > 1 ? 's' : ''}',
                tone: StatusTone.info,
              ),
              if (ageGestationnel != null)
                StatusPill('$ageGestationnel semaines', tone: StatusTone.info),
              if (terme != null)
                StatusPill(
                  'Terme ${terme.day.toString().padLeft(2, '0')}/'
                  '${terme.month.toString().padLeft(2, '0')}',
                  tone: StatusTone.info,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
