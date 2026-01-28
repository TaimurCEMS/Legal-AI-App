import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:legal_ai_app/core/models/document_model.dart';

void main() {
  group('DocumentModel Tests', () {
    test('fromJson handles all fields', () {
      final json = {
        'documentId': 'doc-123',
        'orgId': 'org-123',
        'caseId': 'case-123',
        'name': 'Test Document.pdf',
        'description': 'Test Description',
        'fileType': 'pdf',
        'fileSize': 1024000, // 1MB
        'storagePath': 'organizations/org-123/documents/doc-123/test.pdf',
        'downloadUrl': 'https://example.com/download',
        'createdAt': '2026-01-20T10:00:00Z',
        'updatedAt': '2026-01-20T10:00:00Z',
        'createdBy': 'user-123',
        'updatedBy': 'user-123',
      };

      final model = DocumentModel.fromJson(json);

      expect(model.documentId, equals('doc-123'));
      expect(model.orgId, equals('org-123'));
      expect(model.caseId, equals('case-123'));
      expect(model.name, equals('Test Document.pdf'));
      expect(model.description, equals('Test Description'));
      expect(model.fileType, equals('pdf'));
      expect(model.fileSize, equals(1024000));
      expect(model.storagePath, equals('organizations/org-123/documents/doc-123/test.pdf'));
      expect(model.downloadUrl, equals('https://example.com/download'));
      expect(model.createdBy, equals('user-123'));
      expect(model.updatedBy, equals('user-123'));
      expect(model.isDeleted, isFalse);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'documentId': 'doc-123',
        'orgId': 'org-123',
        'name': 'Test Document.pdf',
        'fileType': 'pdf',
        'fileSize': 1024000,
        'storagePath': 'organizations/org-123/documents/doc-123/test.pdf',
        'createdAt': '2026-01-20T10:00:00Z',
        'updatedAt': '2026-01-20T10:00:00Z',
        'createdBy': 'user-123',
        'updatedBy': 'user-123',
      };

      final model = DocumentModel.fromJson(json);

      expect(model.caseId, isNull);
      expect(model.description, isNull);
      expect(model.downloadUrl, isNull);
      expect(model.deletedAt, isNull);
    });

    test('fromJson handles deleted document', () {
      final json = {
        'documentId': 'doc-123',
        'orgId': 'org-123',
        'name': 'Test Document.pdf',
        'fileType': 'pdf',
        'fileSize': 1024000,
        'storagePath': 'organizations/org-123/documents/doc-123/test.pdf',
        'createdAt': '2026-01-20T10:00:00Z',
        'updatedAt': '2026-01-20T10:00:00Z',
        'createdBy': 'user-123',
        'updatedBy': 'user-123',
        'deletedAt': '2026-01-21T10:00:00Z',
      };

      final model = DocumentModel.fromJson(json);

      expect(model.deletedAt, isNotNull);
      expect(model.isDeleted, isTrue);
    });

    test('fileSizeFormatted formats bytes correctly', () {
      final model1 = DocumentModel(
        documentId: 'doc-1',
        orgId: 'org-1',
        name: 'small.txt',
        fileType: 'txt',
        fileSize: 500, // 500 bytes
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model1.fileSizeFormatted, equals('500 B'));

      final model2 = DocumentModel(
        documentId: 'doc-2',
        orgId: 'org-1',
        name: 'medium.pdf',
        fileType: 'pdf',
        fileSize: 1024 * 512, // 512 KB
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model2.fileSizeFormatted, equals('512.0 KB'));

      final model3 = DocumentModel(
        documentId: 'doc-3',
        orgId: 'org-1',
        name: 'large.pdf',
        fileType: 'pdf',
        fileSize: 1024 * 1024 * 2, // 2 MB
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(model3.fileSizeFormatted, equals('2.0 MB'));
    });

    test('fileTypeIcon returns correct icon for each file type', () {
      final pdfModel = DocumentModel(
        documentId: 'doc-1',
        orgId: 'org-1',
        name: 'test.pdf',
        fileType: 'pdf',
        fileSize: 1000,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(pdfModel.fileTypeIcon, equals(Icons.description));

      final docxModel = DocumentModel(
        documentId: 'doc-2',
        orgId: 'org-1',
        name: 'test.docx',
        fileType: 'docx',
        fileSize: 1000,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(docxModel.fileTypeIcon, equals(Icons.description));

      final txtModel = DocumentModel(
        documentId: 'doc-3',
        orgId: 'org-1',
        name: 'test.txt',
        fileType: 'txt',
        fileSize: 1000,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(txtModel.fileTypeIcon, equals(Icons.text_snippet));

      final unknownModel = DocumentModel(
        documentId: 'doc-4',
        orgId: 'org-1',
        name: 'test.xyz',
        fileType: 'xyz',
        fileSize: 1000,
        storagePath: 'path',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
        updatedBy: 'user',
      );
      expect(unknownModel.fileTypeIcon, equals(Icons.insert_drive_file));
    });

    test('toJson serializes all fields correctly', () {
      final model = DocumentModel(
        documentId: 'doc-123',
        orgId: 'org-123',
        caseId: 'case-123',
        name: 'Test Document.pdf',
        description: 'Test Description',
        fileType: 'pdf',
        fileSize: 1024000,
        storagePath: 'organizations/org-123/documents/doc-123/test.pdf',
        downloadUrl: 'https://example.com/download',
        createdAt: DateTime.parse('2026-01-20T10:00:00Z'),
        updatedAt: DateTime.parse('2026-01-20T10:00:00Z'),
        createdBy: 'user-123',
        updatedBy: 'user-123',
      );

      final json = model.toJson();

      expect(json['documentId'], equals('doc-123'));
      expect(json['orgId'], equals('org-123'));
      expect(json['caseId'], equals('case-123'));
      expect(json['name'], equals('Test Document.pdf'));
      expect(json['description'], equals('Test Description'));
      expect(json['fileType'], equals('pdf'));
      expect(json['fileSize'], equals(1024000));
      expect(json['storagePath'], equals('organizations/org-123/documents/doc-123/test.pdf'));
      expect(json['downloadUrl'], equals('https://example.com/download'));
      expect(json['createdAt'], equals('2026-01-20T10:00:00.000Z'));
      expect(json['updatedAt'], equals('2026-01-20T10:00:00.000Z'));
      expect(json['createdBy'], equals('user-123'));
      expect(json['updatedBy'], equals('user-123'));
    });

    test('toJson handles null optional fields', () {
      final model = DocumentModel(
        documentId: 'doc-123',
        orgId: 'org-123',
        name: 'Test Document.pdf',
        fileType: 'pdf',
        fileSize: 1024000,
        storagePath: 'organizations/org-123/documents/doc-123/test.pdf',
        createdAt: DateTime.parse('2026-01-20T10:00:00Z'),
        updatedAt: DateTime.parse('2026-01-20T10:00:00Z'),
        createdBy: 'user-123',
        updatedBy: 'user-123',
      );

      final json = model.toJson();

      expect(json['caseId'], isNull);
      expect(json['description'], isNull);
      expect(json['downloadUrl'], isNull);
      expect(json['deletedAt'], isNull);
    });
  });
}
