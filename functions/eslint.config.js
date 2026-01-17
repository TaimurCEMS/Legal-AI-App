import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  // Base recommended rules
  js.configs.recommended,
  
  // Ignore patterns - exclude compiled output and config files
  {
    ignores: [
      'lib/**',
      'node_modules/**',
      '**/*.js',
      '**/*.cjs',
      '**/*.mjs',
      '.eslintrc.js',
      'jest.config.js',
      'eslint.config.js',
    ],
  },
  
  // TypeScript files configuration - only lint src/**/*.ts
  ...tseslint.configs.recommended,
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: 2022,
        sourceType: 'module',
        project: './tsconfig.json',
      },
    },
    rules: {
      // Keep rules simple - no strictness wars
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },
  
  // Test files - allow Jest globals
  {
    files: ['src/**/*.test.ts', 'src/**/__tests__/**/*.ts'],
    languageOptions: {
      globals: {
        describe: 'readonly',
        test: 'readonly',
        it: 'readonly',
        expect: 'readonly',
        beforeEach: 'readonly',
        afterEach: 'readonly',
        jest: 'readonly',
      },
    },
    rules: {
      // Relax rules for tests
      '@typescript-eslint/no-explicit-any': 'off',
    },
  }
);
