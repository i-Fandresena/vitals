import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/beneficiary_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../data/secure/token_store.dart';

/// Dépendances partagées de l'application.

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    database: ref.watch(databaseProvider),
  );
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    apiClient: ref.watch(apiClientProvider),
    database: ref.watch(databaseProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final beneficiaryRepositoryProvider = Provider<BeneficiaryRepository>((ref) {
  return BeneficiaryRepository(
    beneficiaryDao: ref.watch(databaseProvider).beneficiaryDao,
  );
});
