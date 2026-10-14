import '../io/codec.dart';
import '../l10n.dart';

class ImportIssues {
  static String line(L l, ImportResult r) =>
      l.t('issue_${r.issue.name}', {'name': r.fileName});

  static List<ImportResult> failures(List<ImportResult> results) => [
    for (final r in results)
      if (r.people.isEmpty && r.issue != ImportIssue.none) r,
  ];

  static String describe(L l, List<ImportResult> results) =>
      failures(results).map((r) => line(l, r)).join('\n');

  static bool suggestsTemplate(List<ImportResult> results) =>
      failures(results).any(
        (r) =>
            r.issue == ImportIssue.noColumns ||
            r.issue == ImportIssue.headerOnly ||
            r.issue == ImportIssue.noContacts ||
            r.issue == ImportIssue.unreadable,
      );
}
