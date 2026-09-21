import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import 'auth_controller.dart';

/// Écran de connexion.
///
/// Deux champs, un bouton. C'est le premier contact avec l'application et il
/// doit être franchissable sans explication (CDC §7) — donc : pas de « mot de
/// passe oublié » qui n'irait nulle part, pas d'inscription (les comptes sont
/// créés par le responsable du CSB), pas d'illustration décorative.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _passwordVisible = false;

  /// Progression suivie ici et non dans l'état global : l'écran doit rester
  /// affiché pendant la tentative, sinon le message d'échec apparaîtrait
  /// ailleurs que là où l'utilisateur vient d'appuyer.
  bool _enCours = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Referme le clavier : sur un petit écran il masque le message d'erreur.
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) return;
    if (_enCours) return;

    setState(() => _enCours = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            username: _usernameController.text,
            password: _passwordController.text,
          );
    } finally {
      // En cas de succès le routeur a déjà quitté cet écran ; le `mounted`
      // évite de toucher un état démonté.
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final error = state is AuthSignedOut ? state.error : null;
    final isLoading = _enCours;

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimens.space32),
                    _Header(theme: theme),
                    const SizedBox(height: AppDimens.space32),

                    if (error != null) ...[
                      _ErrorBanner(message: error),
                      const SizedBox(height: AppDimens.space16),
                    ],

                    TextFormField(
                      controller: _usernameController,
                      autofocus: true,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      // Les identifiants sont souvent des matricules : ni
                      // majuscule automatique, ni correction orthographique.
                      textCapitalization: TextCapitalization.none,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Identifiant',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Saisissez votre identifiant'
                          : null,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: AppDimens.space16),

                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      enabled: !isLoading,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        // Afficher le mot de passe évite l'échec silencieux le
                        // plus courant : une faute de frappe invisible.
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          tooltip: _passwordVisible
                              ? 'Masquer le mot de passe'
                              : 'Afficher le mot de passe',
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Saisissez votre mot de passe'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppDimens.space32),

                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Se connecter'),
                    ),
                    const SizedBox(height: AppDimens.space24),

                    Text(
                      'Votre compte est créé par le responsable de votre centre.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppDimens.space32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Le logo lui-meme, et non un pictogramme generique : c'est le seul
        // endroit de l'application ou il a la place d'etre reconnu.
        Image.asset(
          'assets/branding/embleme.png',
          height: 96,
          filterQuality: FilterQuality.medium,
          // Un appareil qui n'arrive pas a decoder l'image ne doit pas
          // empecher de se connecter.
          errorBuilder: (_, _, _) => Icon(
            Icons.health_and_safety_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppDimens.space16),
        Text('MbolaTsara', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppDimens.space4),
        Text(
          'Dossiers et activités du centre de santé',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Message d'erreur persistant.
///
/// Un bandeau plutôt qu'une notification éphémère : l'utilisateur doit pouvoir
/// relire pourquoi la connexion a échoué pendant qu'il corrige sa saisie.
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
            // Sélectionnable : un message technique doit pouvoir être recopié
            // ou envoyé au responsable, pas seulement lu puis oublié.
            child: SelectableText(
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
