enum TaskQueryIssueSeverity { warning, error }

class TaskQueryIssue {
  const TaskQueryIssue({required this.message, required this.severity});

  final String message;
  final TaskQueryIssueSeverity severity;
}

class TaskQuery {
  const TaskQuery({
    required this.originalInput,
    required this.usesExplicitStatusScope,
    required this.issues,
    required this.termCount,
    required this.isAdvanced,
  });

  final String originalInput;
  final bool usesExplicitStatusScope;
  final List<TaskQueryIssue> issues;
  final int termCount;
  final bool isAdvanced;

  bool get hasErrors =>
      issues.any((issue) => issue.severity == TaskQueryIssueSeverity.error);
}

TaskQuery parseTaskQuery(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const TaskQuery(
      originalInput: '',
      usesExplicitStatusScope: false,
      issues: [],
      termCount: 0,
      isAdvanced: false,
    );
  }

  final tokens = _mergeColonTokens(_tokenizeQuery(trimmed));
  final issues = <TaskQueryIssue>[];

  var depth = 0;
  for (final t in tokens) {
    if (t == '(') depth++;
    if (t == ')') depth--;
    if (depth < 0) {
      issues.add(const TaskQueryIssue(
        message: 'Unmatched closing parenthesis',
        severity: TaskQueryIssueSeverity.error,
      ));
      break;
    }
  }
  if (depth > 0) {
    issues.add(const TaskQueryIssue(
      message: 'Unclosed parenthesis',
      severity: TaskQueryIssueSeverity.error,
    ));
  }

  if (tokens.isNotEmpty) {
    final last = tokens.last.toLowerCase();
    if (last == 'or' || last == 'and' || last == 'not') {
      issues.add(TaskQueryIssue(
        message: 'Missing expression after "$last"',
        severity: TaskQueryIssueSeverity.error,
      ));
    }
  }

  return TaskQuery(
    originalInput: input,
    usesExplicitStatusScope: _scanExplicitStatusScope(tokens),
    issues: issues,
    termCount: _countTokens(tokens),
    isAdvanced: _scanIsAdvanced(tokens),
  );
}

bool _scanExplicitStatusScope(List<String> tokens) {
  final lowerTokens = tokens.map((t) => t.toLowerCase()).toList();

  for (var i = 0; i < lowerTokens.length; i++) {
    final token = lowerTokens[i];
    final isNegated = _isTokenNegated(lowerTokens, i);
    if (isNegated) continue;

    if (token.startsWith('status:')) {
      final value = token.substring(7);
      if (value == 'completed' || value == 'deleted' ||
          value == 'done' || value == 'complete') {
        return true;
      }
    }

    if (token.startsWith('+')) {
      final inner = token.substring(1);
      if (inner == 'completed' || inner == 'deleted' ||
          inner == 'done' || inner == 'complete') {
        return true;
      }
    }
  }
  return false;
}

bool _isTokenNegated(List<String> tokens, int index) {
  for (var j = index - 1; j >= 0; j--) {
    final t = tokens[j];
    if (t == '(' || t == ')') continue;
    if (t == '-' || t == 'not' || t == '!') return true;
    break;
  }
  return false;
}

bool _scanIsAdvanced(List<String> tokens) {
  for (final token in tokens) {
    final lower = token.toLowerCase();
    if (lower == 'or' || lower == 'and' || lower == 'not' ||
        lower == '!' || lower == '&&' || lower == '||') {
      return true;
    }
    if (token == '(' || token == ')') return true;
    if (token.startsWith('+') || token.startsWith('-')) return true;
    if (token.contains(':')) return true;
  }
  return false;
}

int _countTokens(List<String> tokens) {
  var count = 0;
  for (final token in tokens) {
    final lower = token.toLowerCase();
    if (lower == 'or' || lower == 'and' || lower == 'not' ||
        lower == '!' || lower == '&&' || lower == '||') {
      continue;
    }
    if (token == '(' || token == ')') continue;
    count++;
  }
  return count;
}

List<String> _tokenizeQuery(String input) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quoteChar;

  void flush() {
    if (buffer.isEmpty) return;
    tokens.add(buffer.toString());
    buffer.clear();
  }

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (quoteChar != null) {
      if (char == quoteChar) {
        quoteChar = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == '"' || char == '\'') {
      quoteChar = char;
      continue;
    }
    if (char == '(' || char == ')') {
      flush();
      tokens.add(char);
      continue;
    }
    if (char == '&' && i + 1 < input.length && input[i + 1] == '&') {
      flush();
      tokens.add('&&');
      i++;
      continue;
    }
    if (char == '|' && i + 1 < input.length && input[i + 1] == '|') {
      flush();
      tokens.add('||');
      i++;
      continue;
    }
    if (_isWhitespace(char)) {
      flush();
      continue;
    }
    buffer.write(char);
  }
  flush();
  return tokens;
}

List<String> _mergeColonTokens(List<String> tokens) {
  final result = <String>[];
  var i = 0;
  while (i < tokens.length) {
    if (tokens[i].endsWith(':') && i + 1 < tokens.length) {
      final next = tokens[i + 1];
      const operators = {
        '(',
        ')',
        '&&',
        '||',
        'and',
        'AND',
        'or',
        'OR',
        'not',
        'NOT',
        '!',
      };
      if (!operators.contains(next)) {
        result.add('${tokens[i]}$next');
        i += 2;
        continue;
      }
    }
    result.add(tokens[i]);
    i++;
  }
  return result;
}

bool _isWhitespace(String char) {
  return char == ' ' || char == '\n' || char == '\t' || char == '\r';
}
