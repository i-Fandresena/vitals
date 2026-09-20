import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_dimens.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';

/// Scan du QR code d'un dossier.
///
/// Le code ne contient qu'un UUID : le scan ne fait qu'ouvrir un dossier déjà
/// présent dans la base locale, il n'apporte aucune donnée. Un code inconnu, un
/// code d'une autre application ou un dossier d'un autre centre aboutissent
/// donc tous au même résultat — rien ne s'ouvre, et on explique pourquoi.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Un seul code à la fois : l'écran se ferme dès qu'un dossier est trouvé.
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Empêche qu'un second cliché déclenche une deuxième navigation pendant que
  /// la recherche du premier est encore en cours.
  bool _handling = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _handling = true;
      _message = null;
    });

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;

    final csbId = auth.user.csbId;
    if (csbId == null) {
      setState(() {
        _handling = false;
        _message = "Votre profil n'accède pas aux dossiers individuels.";
      });
      return;
    }

    final beneficiary = await ref
        .read(beneficiaryRepositoryProvider)
        .findByQrPayload(csbId: csbId, payload: raw);

    if (!mounted) return;

    if (beneficiary == null) {
      setState(() {
        _handling = false;
        _message =
            'Ce code ne correspond à aucun dossier de votre centre.\n'
            "Vérifiez qu'il s'agit bien d'une carte Vitals.";
      });
      return;
    }

    // On remplace l'écran de scan : revenir en arrière depuis le dossier doit
    // ramener à la recherche, pas rouvrir la caméra.
    context.pushReplacement(Routes.beneficiaryPath(beneficiary.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner une carte'),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
            // Les CSB sont souvent mal éclairés ; la torche est ici, pas
            // enfouie dans un menu.
            tooltip: 'Allumer la lampe',
            iconSize: 28,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) =>
                        _CameraError(error: error),
                  ),
                  const _ViewfinderOverlay(),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.space16),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  Text(
                    _message ?? 'Placez le QR code de la carte dans le cadre.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _message == null
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space12),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Chercher par nom'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cadre de visée.
///
/// Simple rectangle clair : il indique où placer le code sans masquer l'image,
/// et ne coûte rien à afficher sur un appareil modeste.
class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          ),
        ),
      ),
    );
  }
}

/// Affiché quand la caméra n'est pas disponible — permission refusée, matériel
/// occupé par une autre application, ou appareil sans caméra.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: Colors.white70,
              ),
              const SizedBox(height: AppDimens.space16),
              Text(
                isPermission
                    ? "L'accès à la caméra a été refusé.\n"
                          'Autorisez-le dans les réglages du téléphone, ou '
                          'cherchez le dossier par son nom.'
                    : "La caméra n'est pas disponible.\n"
                          'Cherchez le dossier par son nom.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
