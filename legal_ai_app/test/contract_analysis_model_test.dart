import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:legal_ai_app/core/models/contract_analysis_model.dart';

void main() {
  group('Clause Tests', () {
    test('fromJson handles all fields', () {
      final json = {
        'id': 'clause-1',
        'type': 'termination',
        'title': 'Termination for cause',
        'content': 'Either party may terminate...',
        'pageNumber': 1,
        'startChar': 100,
        'endChar': 400,
      };
      final clause = Clause.fromJson(json);
      expect(clause.id, equals('clause-1'));
      expect(clause.type, equals('termination'));
      expect(clause.title, equals('Termination for cause'));
      expect(clause.content, equals('Either party may terminate...'));
      expect(clause.pageNumber, equals(1));
      expect(clause.startChar, equals(100));
      expect(clause.endChar, equals(400));
      expect(clause.typeDisplayLabel, equals('Termination'));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'clause-2',
        'type': 'payment',
        'title': 'Payment terms',
        'content': 'Payment due within 30 days.',
      };
      final clause = Clause.fromJson(json);
      expect(clause.pageNumber, isNull);
      expect(clause.startChar, isNull);
      expect(clause.endChar, isNull);
      expect(clause.typeDisplayLabel, equals('Payment'));
    });
  });

  group('Risk Tests', () {
    test('fromJson handles all fields', () {
      final json = {
        'id': 'risk-1',
        'severity': 'high',
        'category': 'liability',
        'title': 'Uncapped liability',
        'description': 'The contract does not cap liability.',
        'clauseIds': ['clause-1'],
        'recommendation': 'Negotiate a liability cap.',
      };
      final risk = Risk.fromJson(json);
      expect(risk.id, equals('risk-1'));
      expect(risk.severity, equals('high'));
      expect(risk.category, equals('liability'));
      expect(risk.title, equals('Uncapped liability'));
      expect(risk.description, equals('The contract does not cap liability.'));
      expect(risk.clauseIds, equals(['clause-1']));
      expect(risk.recommendation, equals('Negotiate a liability cap.'));
      expect(risk.severityDisplayLabel, equals('High'));
      expect(risk.severityColor, equals(Colors.red));
      expect(risk.categoryDisplayLabel, equals('Liability'));
    });

    test('severityColor returns correct colors', () {
      expect(Risk(id: 'r1', severity: 'high', category: 'x', title: 't', description: 'd').severityColor, Colors.red);
      expect(Risk(id: 'r2', severity: 'medium', category: 'x', title: 't', description: 'd').severityColor, Colors.orange);
      expect(Risk(id: 'r3', severity: 'low', category: 'x', title: 't', description: 'd').severityColor, Colors.yellow.shade700);
    });
  });

  group('ContractAnalysisModel Tests', () {
    test('fromJson handles all fields', () {
      final json = {
        'analysisId': 'analysis-123',
        'documentId': 'doc-456',
        'caseId': 'case-789',
        'status': 'completed',
        'error': null,
        'summary': 'This is a standard service agreement.',
        'clauses': [
          {'id': 'c1', 'type': 'termination', 'title': 'Termination', 'content': 'Text'},
        ],
        'risks': [
          {'id': 'r1', 'severity': 'medium', 'category': 'payment', 'title': 'Late fees', 'description': 'High late fees.'},
        ],
        'createdAt': '2026-01-29T10:00:00Z',
        'completedAt': '2026-01-29T10:01:00Z',
        'createdBy': 'user-1',
        'model': 'gpt-4o-mini',
        'tokensUsed': 1500,
        'processingTimeMs': 8000,
      };
      final model = ContractAnalysisModel.fromJson(json);
      expect(model.analysisId, equals('analysis-123'));
      expect(model.documentId, equals('doc-456'));
      expect(model.caseId, equals('case-789'));
      expect(model.status, equals('completed'));
      expect(model.summary, equals('This is a standard service agreement.'));
      expect(model.clauses.length, equals(1));
      expect(model.risks.length, equals(1));
      expect(model.createdBy, equals('user-1'));
      expect(model.model, equals('gpt-4o-mini'));
      expect(model.tokensUsed, equals(1500));
      expect(model.processingTimeMs, equals(8000));
      expect(model.isCompleted, isTrue);
      expect(model.isFailed, isFalse);
      expect(model.hasResults, isTrue);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'analysisId': 'a1',
        'documentId': 'd1',
        'status': 'pending',
        'clauses': [],
        'risks': [],
        'createdAt': '2026-01-29T10:00:00Z',
        'createdBy': 'user-1',
        'model': 'gpt-4o-mini',
      };
      final model = ContractAnalysisModel.fromJson(json);
      expect(model.caseId, isNull);
      expect(model.error, isNull);
      expect(model.summary, isNull);
      expect(model.completedAt, isNull);
      expect(model.tokensUsed, isNull);
      expect(model.processingTimeMs, isNull);
      expect(model.isCompleted, isFalse);
      expect(model.isProcessing, isTrue);
      expect(model.hasResults, isFalse);
    });

    test('clausesByType groups clauses by type', () {
      final model = ContractAnalysisModel(
        analysisId: 'a1',
        documentId: 'd1',
        status: 'completed',
        clauses: [
          const Clause(id: 'c1', type: 'termination', title: 'T1', content: 'x'),
          const Clause(id: 'c2', type: 'termination', title: 'T2', content: 'y'),
          const Clause(id: 'c3', type: 'payment', title: 'P1', content: 'z'),
        ],
        risks: [],
        createdAt: DateTime(2026, 1, 29),
        createdBy: 'u1',
        model: 'gpt-4o-mini',
      );
      final byType = model.clausesByType;
      expect(byType['termination']!.length, equals(2));
      expect(byType['payment']!.length, equals(1));
    });

    test('risksBySeverity groups risks by severity', () {
      final model = ContractAnalysisModel(
        analysisId: 'a1',
        documentId: 'd1',
        status: 'completed',
        clauses: [],
        risks: [
          const Risk(id: 'r1', severity: 'high', category: 'x', title: 'R1', description: 'd1'),
          const Risk(id: 'r2', severity: 'high', category: 'x', title: 'R2', description: 'd2'),
          const Risk(id: 'r3', severity: 'low', category: 'x', title: 'R3', description: 'd3'),
        ],
        createdAt: DateTime(2026, 1, 29),
        createdBy: 'u1',
        model: 'gpt-4o-mini',
      );
      final bySev = model.risksBySeverity;
      expect(bySev['high']!.length, equals(2));
      expect(bySev['low']!.length, equals(1));
    });
  });
}
