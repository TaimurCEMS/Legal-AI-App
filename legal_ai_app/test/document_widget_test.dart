import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/core/models/document_model.dart';

void main() {
  group('Document Widget Tests', () {
    // Note: Widget tests for DocumentListScreen, DocumentUploadScreen, and DocumentDetailsScreen
    // require Firebase providers and web-only dart:html imports, so they are skipped here.
    // These should be tested via integration tests or manual testing.
    // See test/README_FIREBASE_TESTS.md for testing strategies.

    test('DocumentModel fileSizeFormatted edge cases', () {
      // Test exactly 1KB
      final model1 = DocumentModel(
        documentId: 'doc-1',
        orgId: 'org-1',
        name: 'test.txt',
        fileType: 'txt',
        fileSize: 1024,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model1.fileSizeFormatted, equals('1.0 KB'));

      // Test exactly 1MB
      final model2 = DocumentModel(
        documentId: 'doc-2',
        orgId: 'org-1',
        name: 'test.pdf',
        fileType: 'pdf',
        fileSize: 1024 * 1024,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model2.fileSizeFormatted, equals('1.0 MB'));

      // Test less than 1KB
      final model3 = DocumentModel(
        documentId: 'doc-3',
        orgId: 'org-1',
        name: 'test.txt',
        fileType: 'txt',
        fileSize: 512,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model3.fileSizeFormatted, equals('512 B'));
    });

    test('DocumentModel fileTypeIcon case insensitive', () {
      final model1 = DocumentModel(
        documentId: 'doc-1',
        orgId: 'org-1',
        name: 'test.PDF',
        fileType: 'PDF', // Uppercase
        fileSize: 1000,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model1.fileTypeIcon, equals('description'));

      final model2 = DocumentModel(
        documentId: 'doc-2',
        orgId: 'org-1',
        name: 'test.DOCX',
        fileType: 'DOCX', // Uppercase
        fileSize: 1000,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model2.fileTypeIcon, equals('description'));
    });
  });
}
