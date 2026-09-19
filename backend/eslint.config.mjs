// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist/**', 'node_modules/**', 'prisma/generated/**'],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // NestJS s'appuie sur des décorateurs et des types injectés : interdire
      // tout `any` bloquerait sur du code de framework légitime, mais il doit
      // rester visible.
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unsafe-assignment': 'warn',
      '@typescript-eslint/no-unsafe-member-access': 'warn',

      // Une promesse oubliée dans un service d'authentification, c'est une
      // écriture d'audit ou une révocation qui ne part jamais.
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',

      // `console.log` finit dans les journaux de production, qui ne doivent
      // jamais contenir de donnée de santé. Passer par le Logger de Nest.
      'no-console': ['error', { allow: ['warn', 'error'] }],

      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
  {
    // Le seed s'exécute à la main en développement et rend compte à l'écran.
    files: ['prisma/seed.ts'],
    rules: { 'no-console': 'off' },
  },
);
