// Generates the typed API client in lib/api/generated/ from the backend's
// OpenAPI contract (../contracts/openapi.json).
//
//   dart run tool/generate_api.dart          # regenerate
//   dart run tool/generate_api.dart --check  # exit 1 if the output is stale
//
// Output is formatted with the SDK's own `dart format`, so it matches what
// CI's format check expects. Unsupported schema shapes fail loudly rather
// than generating something subtly wrong.

import 'dart:convert';
import 'dart:io';

const _specPath = '../contracts/openapi.json';
const _outDir = 'lib/api/generated';

/// Readable names for enums whose property name alone would be ambiguous or
/// clash with SDK/Flutter types. Keyed by the enum's values joined with `|`.
const _enumNames = <String, String>{
  'electronics|cameras|cycles|books|instruments|sports|hostel|events|other':
      'ListingCategory',
  'new|like_new|good|fair|poor': 'ItemCondition',
  'rent|sale': 'TradeKind',
  'renter|owner': 'TradeRole',
  'renter|owner|staff': 'BookingViewerRole',
  'requested|approved|declined': 'ExtensionStatus',
  'requested|approved|declined|withdrawn|expired|cancelled|active|overdue|returning|in_appeal|awaiting_reviews|completed':
      'BookingStatus',
  'active|paused|sold|removed': 'ListingStatus',
  'open|ruled|overruled': 'AppealStatus',
  'open|ruled|all': 'AppealFilter',
  'open|closed': 'ThreadStatus',
  'hostel|day_scholar': 'ResidenceType',
  'lender|renter': 'TrustRole',
  'upi|cash': 'PaymentMethod',
  'android|ios': 'DevicePlatform',
  'suspended|banned': 'AccountRestriction',
  'active|suspended|banned': 'AccountStatus',
  'pending|upcoming|active|past|cancelled': 'BookingGroup',
  'trust|newest|price_asc|price_desc': 'SearchSort',
  'done|current|upcoming|skipped': 'TimelineStepState',
  'listed|rented|returned|sold|damage_charge': 'AssetEventKind',
  'answer|fallback': 'ChatReplyKind',
  'see_faqs|talk_to_moderator': 'ChatAction',
  'overdue|stalled_proceed|owner_escalated': 'EscalationKind',
  'overdue_returns|cancellations|disputes|low_trust': 'RiskFlagKind',
  'pickup|return': 'HandoverPhase',
  'user|bot|moderator': 'MessageAuthor',
  'user|bot': 'TranscriptAuthor',
  'renter|lender|renter_sale|lender_sale|cancellation': 'ReviewType',
  'damage_dispute|item_mismatch|other': 'AppealReason',
  'created|pending|captured|failed|marked_paid|refunded|partly_refunded':
      'PaymentStatus',
  'rent|extension|return_charges|sale': 'PaymentPurpose',
  'image/jpeg|image/png|image/webp': 'PhotoContentType',
  'profile|listing|handover|appeal': 'UploadPurpose',
};

/// Field names that can't be used as Dart identifiers as-is.
const _fieldNames = <String, String>{'return': 'returnHandover'};

/// Reserved words, plus members every Dart object already has.
const _reserved = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
  'toJson',
};

/// Names an enum constant can't take (members of the generated enums).
const _reservedEnumMembers = {'values', 'index', 'name', 'json', 'unknown'};

const _header =
    '// GENERATED CODE - DO NOT MODIFY BY HAND.\n'
    '// Source: contracts/openapi.json. Regenerate with:\n'
    '//   dart run tool/generate_api.dart\n';

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final root = File.fromUri(Platform.script).parent.parent.path;
  final spec =
      jsonDecode(File('$root/$_specPath').readAsStringSync())
          as Map<String, Object?>;

  final generator = _Generator(spec);
  final outputs = {
    'models.dart': generator.models(),
    'endpoints.dart': generator.endpoints(),
  };

  final stale = <String>[];
  for (final MapEntry(key: name, value: source) in outputs.entries) {
    final path = '$_outDir/$name';
    final formatted = await _format(source, path, root);
    final file = File('$root/$path');
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != formatted) {
        stale.add(path);
      }
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(formatted);
      stdout.writeln('wrote $path');
    }
  }

  if (stale.isNotEmpty) {
    stderr.writeln(
      'Generated API code is out of date: ${stale.join(', ')}\n'
      'Run `dart run tool/generate_api.dart` and commit the result.',
    );
    exit(1);
  }
  if (check) stdout.writeln('Generated API code is up to date.');
}

/// Formats [source] as if it lived at [path] inside the package, so the
/// package's language version (and thus formatting style) applies.
Future<String> _format(String source, String path, String root) async {
  final process = await Process.start('dart', [
    'format',
    '--stdin-name=$path',
  ], workingDirectory: root);
  process.stdin.write(source);
  await process.stdin.close();
  final out = process.stdout.transform(utf8.decoder).join();
  final err = process.stderr.transform(utf8.decoder).join();
  if (await process.exitCode != 0) {
    throw StateError('dart format failed for $path:\n${await err}');
  }
  return out;
}

// ---------------------------------------------------------------------------
// Naming helpers.

List<String> _words(String s) => s
    .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .split(RegExp('[^A-Za-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList();

String _pascal(String s) =>
    _words(s).map((w) => w[0].toUpperCase() + w.substring(1)).join();

String _camel(String s) {
  final p = _pascal(s);
  return p.isEmpty ? p : p[0].toLowerCase() + p.substring(1);
}

String _identifier(String raw, {bool field = true}) {
  final mapped = field ? _fieldNames[raw] : null;
  if (mapped != null) return mapped;
  var name = _camel(raw);
  if (RegExp('^[0-9]').hasMatch(name)) name = 'v$name';
  return _reserved.contains(name) ? '${name}Value' : name;
}

String _className(String schemaName) {
  final page = RegExp(r'^Page_(\w+)_$').firstMatch(schemaName);
  if (page != null) return '${_pascal(page[1]!)}Page';
  return _pascal(schemaName);
}

String _quote(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String _doc(String? text, {String indent = ''}) {
  if (text == null || text.trim().isEmpty) return '';
  final lines = text.trim().split('\n').map((line) {
    final escaped = line.trim().replaceAll('[', r'\[').replaceAll(']', r'\]');
    return '$indent/// $escaped'.trimRight();
  });
  return '${lines.join('\n')}\n';
}

String _refName(String ref) => ref.split('/').last;

// ---------------------------------------------------------------------------
// Type model.

sealed class _Type {
  const _Type();

  /// Dart type, without nullability.
  String get dart;

  /// Expression decoding the non-null JSON value [e] (typed `Object?`).
  String decode(String e, int depth);

  /// Expression encoding the non-null Dart value [e] to JSON.
  String encode(String e, int depth);

  /// Whether [encode] returns its argument unchanged.
  bool get encodesAsIs => false;
}

class _Prim extends _Type {
  const _Prim(this.dart);

  @override
  final String dart;

  @override
  String decode(String e, int depth) => switch (dart) {
    'int' => '($e as num).toInt()',
    'double' => '($e as num).toDouble()',
    _ => '$e as $dart',
  };

  @override
  String encode(String e, int depth) => e;

  @override
  bool get encodesAsIs => true;
}

class _Any extends _Type {
  const _Any();

  @override
  String get dart => 'Object';

  @override
  String decode(String e, int depth) => e;

  @override
  String encode(String e, int depth) => e;

  @override
  bool get encodesAsIs => true;
}

class _DateTime extends _Type {
  const _DateTime({required this.dateOnly});

  final bool dateOnly;

  @override
  String get dart => 'DateTime';

  @override
  String decode(String e, int depth) => 'DateTime.parse($e as String)';

  @override
  String encode(String e, int depth) =>
      dateOnly ? '_formatDate($e)' : '$e.toUtc().toIso8601String()';
}

class _List extends _Type {
  const _List(this.item);

  final _Type item;

  @override
  String get dart => item is _Any ? 'List<Object?>' : 'List<${item.dart}>';

  @override
  String decode(String e, int depth) {
    if (item is _Any) return 'List<Object?>.of($e as List<Object?>)';
    final v = 'e$depth';
    return '($e as List<Object?>).map(($v) => ${item.decode('$v!', depth + 1)}).toList()';
  }

  @override
  String encode(String e, int depth) {
    if (item.encodesAsIs) return e;
    final v = 'e$depth';
    return '$e.map(($v) => ${item.encode(v, depth + 1)}).toList()';
  }

  @override
  bool get encodesAsIs => item.encodesAsIs;
}

class _Map extends _Type {
  const _Map(this.value);

  final _Type value;

  @override
  String get dart =>
      value is _Any ? 'Map<String, Object?>' : 'Map<String, ${value.dart}>';

  @override
  String decode(String e, int depth) {
    if (value is _Any) {
      return 'Map<String, Object?>.of($e as Map<String, Object?>)';
    }
    final k = 'k$depth';
    final v = 'v$depth';
    return '($e as Map<String, Object?>).map(($k, $v) => MapEntry($k, ${value.decode('$v!', depth + 1)}))';
  }

  @override
  String encode(String e, int depth) {
    if (value.encodesAsIs) return e;
    final k = 'k$depth';
    final v = 'v$depth';
    return '$e.map(($k, $v) => MapEntry($k, ${value.encode(v, depth + 1)}))';
  }

  @override
  bool get encodesAsIs => value.encodesAsIs;
}

/// A generated class (model or sealed union).
class _Named extends _Type {
  const _Named(this.dart);

  @override
  final String dart;

  @override
  String decode(String e, int depth) =>
      '$dart.fromJson($e as Map<String, Object?>)';

  @override
  String encode(String e, int depth) => '$e.toJson()';
}

class _Enum extends _Type {
  const _Enum(this.dart);

  @override
  final String dart;

  @override
  String decode(String e, int depth) => '$dart.fromJson($e as String)';

  @override
  String encode(String e, int depth) => '$e.json';
}

/// A resolved schema: its type plus whether JSON null is allowed.
class _Resolved {
  const _Resolved(this.type, {this.nullable = false});

  final _Type type;
  final bool nullable;
}

class _Union {
  _Union(this.name, this.property, this.variants);

  final String name;
  final String property;

  /// Discriminator value → variant class name.
  final Map<String, String> variants;
}

class _EnumDef {
  _EnumDef(this.values);

  final List<String> values;
  final uses = <(String owner, String prop)>[];
  String? name;
  String? description;
}

// ---------------------------------------------------------------------------

class _Generator {
  _Generator(this.spec)
    : schemas = ((spec['components']! as Map)['schemas']! as Map)
          .cast<String, Map<String, Object?>>() {
    _collectEnums();
    _nameEnums();
    _collectUnions();
  }

  final Map<String, Object?> spec;
  final Map<String, Map<String, Object?>> schemas;

  final _enums = <String, _EnumDef>{};
  final _unions = <String, _Union>{};

  /// Variant class name → its union.
  final _variantOf = <String, _Union>{};

  Iterable<(String path, String method, Map<String, Object?> op)>
  get _operations sync* {
    final paths = (spec['paths']! as Map).cast<String, Map<String, Object?>>();
    for (final MapEntry(key: path, value: ops) in paths.entries) {
      if (path.startsWith('/internal')) continue; // service-to-service only
      for (final MapEntry(key: method, value: op) in ops.entries) {
        yield (path, method, op! as Map<String, Object?>);
      }
    }
  }

  // ---- enums ---------------------------------------------------------------

  /// String enum values of [schema], merging `enum`/`const` members of an
  /// `anyOf`; null if it isn't a string enum.
  List<String>? _enumValues(Map<String, Object?> schema) {
    if (schema['enum'] case final List<Object?> values) {
      return values.cast<String>();
    }
    if (schema['anyOf'] case final List<Object?> options) {
      final members = options
          .cast<Map<String, Object?>>()
          .where((o) => o['type'] != 'null')
          .toList();
      final isEnum = members.every(
        (o) =>
            o['type'] == 'string' && (o['enum'] != null || o['const'] != null),
      );
      if (members.isEmpty || !isEnum) return null;
      if (members.length == 1) return _enumValues(members.single);
      final values = <String>[];
      for (final m in members) {
        values.addAll(
          ((m['enum'] as List<Object?>?) ?? const []).cast<String>(),
        );
        if (m['const'] case final String c) values.add(c);
      }
      return values;
    }
    return null;
  }

  void _visitEnums(Object? schema, String owner, String prop) {
    if (schema is! Map<String, Object?>) return;
    final values = _enumValues(schema);
    if (values != null) {
      final def = _enums.putIfAbsent(values.join('|'), () => _EnumDef(values));
      def.uses.add((owner, prop));
      def.description ??= schema['description'] as String?;
      return;
    }
    for (final key in ['anyOf', 'oneOf']) {
      for (final option in (schema[key] as List<Object?>?) ?? const []) {
        _visitEnums(option, owner, prop);
      }
    }
    _visitEnums(schema['items'], owner, prop);
    _visitEnums(schema['additionalProperties'], owner, prop);
  }

  void _collectEnums() {
    for (final MapEntry(key: name, value: schema) in schemas.entries) {
      final props = (schema['properties'] as Map?)?.cast<String, Object?>();
      props?.forEach((prop, s) => _visitEnums(s, name, prop));
    }
    for (final (_, _, op) in _operations) {
      for (final p in (op['parameters'] as List<Object?>?) ?? const []) {
        final param = p! as Map<String, Object?>;
        _visitEnums(
          param['schema'],
          '${op['operationId']}',
          param['name']! as String,
        );
      }
    }
  }

  void _nameEnums() {
    final byCandidate = <String, List<_EnumDef>>{};
    for (final MapEntry(key: key, value: def) in _enums.entries) {
      final name = _enumNames[key] ?? _pascal(def.uses.first.$2);
      byCandidate.putIfAbsent(name, () => []).add(def);
    }
    // Generic names are only used when the spec gives nothing better.
    final taken = {
      ...schemas.keys.map(_className),
      'Status',
      'Kind',
      'Role',
      'Type',
      'State',
      'Category',
      'Platform',
    };
    for (final MapEntry(key: candidate, value: defs) in byCandidate.entries) {
      for (final def in defs) {
        final ambiguous = defs.length > 1 || taken.contains(candidate);
        def.name = ambiguous
            ? _pascal(def.uses.first.$1) + _pascal(def.uses.first.$2)
            : candidate;
      }
    }
    final names = _enums.values.map((d) => d.name).toList();
    if (names.toSet().length != names.length) {
      throw StateError('Duplicate enum names: $names');
    }
  }

  // ---- unions --------------------------------------------------------------

  _Union _unionFor(Map<String, Object?> schema) {
    final discriminator = schema['discriminator']! as Map<String, Object?>;
    final property = discriminator['propertyName']! as String;
    final mapping = (discriminator['mapping']! as Map).cast<String, String>();
    final variants = {
      for (final MapEntry(:key, :value) in mapping.entries)
        key: _className(_refName(value)),
    };
    final key = variants.values.join('|');
    return _unions.putIfAbsent(key, () {
      // Common prefix of the variant names + the discriminator, e.g.
      // ProfileOwn/ProfileStaff on "view" → ProfileView.
      final names = variants.values.toList();
      var prefix = names.first;
      for (final n in names) {
        while (!n.startsWith(prefix)) {
          prefix = prefix.substring(0, prefix.length - 1);
        }
      }
      final union = _Union(prefix + _pascal(property), property, variants);
      for (final v in variants.values) {
        if (_variantOf.containsKey(v)) {
          throw StateError('$v belongs to more than one union');
        }
        _variantOf[v] = union;
      }
      return union;
    });
  }

  void _visitUnions(Object? node) {
    if (node is Map) {
      if (node['oneOf'] != null && node['discriminator'] != null) {
        _unionFor(node.cast<String, Object?>());
      }
      node.values.forEach(_visitUnions);
    } else if (node is List) {
      node.forEach(_visitUnions);
    }
  }

  void _collectUnions() {
    _visitUnions(schemas);
    _visitUnions(spec['paths']);
  }

  // ---- type resolution -----------------------------------------------------

  _Resolved _resolve(Map<String, Object?> schema) {
    if (schema[r'$ref'] case final String ref) {
      return _Resolved(_Named(_className(_refName(ref))));
    }
    final values = _enumValues(schema);
    if (values != null) {
      final nullable =
          (schema['anyOf'] as List<Object?>?)?.any(
            (o) => (o! as Map)['type'] == 'null',
          ) ??
          false;
      return _Resolved(
        _Enum(_enums[values.join('|')]!.name!),
        nullable: nullable,
      );
    }
    if (schema['oneOf'] != null && schema['discriminator'] != null) {
      return _Resolved(_Named(_unionFor(schema).name));
    }
    if (schema['anyOf'] case final List<Object?> options) {
      final members = options.cast<Map<String, Object?>>();
      final nonNull = members.where((o) => o['type'] != 'null').toList();
      final nullable = nonNull.length < members.length;
      if (nonNull.length == 1) {
        return _Resolved(_resolve(nonNull.single).type, nullable: nullable);
      }
      // A mixed union such as string | integer: leave it untyped.
      return const _Resolved(_Any(), nullable: true);
    }
    // No type information (e.g. only a title): any JSON value.
    const annotations = {'title', 'description', 'default', 'examples'};
    if (schema.keys.every(annotations.contains)) {
      return const _Resolved(_Any(), nullable: true);
    }

    switch (schema['type']) {
      case 'string':
        return switch (schema['format']) {
          'date-time' => const _Resolved(_DateTime(dateOnly: false)),
          'date' => const _Resolved(_DateTime(dateOnly: true)),
          _ => const _Resolved(_Prim('String')),
        };
      case 'integer':
        return const _Resolved(_Prim('int'));
      case 'number':
        return const _Resolved(_Prim('double'));
      case 'boolean':
        return const _Resolved(_Prim('bool'));
      case 'array':
        final items = _resolve(schema['items']! as Map<String, Object?>);
        if (items.nullable && items.type is! _Any) {
          throw UnsupportedError('Nullable array items: $schema');
        }
        return _Resolved(_List(items.type));
      case 'object':
        if (schema['properties'] != null) {
          throw UnsupportedError('Inline object schemas: $schema');
        }
        final additional = schema['additionalProperties'];
        if (additional is Map<String, Object?> && additional.isNotEmpty) {
          return _Resolved(_Map(_resolve(additional).type));
        }
        return const _Resolved(_Map(_Any()));
    }
    throw UnsupportedError('Unsupported schema: $schema');
  }

  String? _defaultLiteral(Object? value, _Type type) {
    if (value == null) return null;
    return switch (type) {
      _Enum(:final dart) =>
        '$dart.${_enumMember(_enumValuesOf(dart), value as String)}',
      _Prim(dart: 'String') => _quote(value as String),
      _Prim(dart: 'int') => '${(value as num).toInt()}',
      _Prim(dart: 'double') => '${(value as num).toDouble()}',
      _Prim(dart: 'bool') => '$value',
      _ => null,
    };
  }

  List<String> _enumValuesOf(String name) =>
      _enums.values.firstWhere((d) => d.name == name).values;

  String _enumMember(List<String> values, String value) {
    final name = _identifier(value, field: false);
    return _reservedEnumMembers.contains(name) ? '${name}Value' : name;
  }

  // ---- models --------------------------------------------------------------

  String models() {
    final out = StringBuffer()
      ..writeln(_header)
      ..writeln("import 'package:flutter/foundation.dart' show immutable;")
      ..writeln()
      ..writeln('String _formatDate(DateTime d) =>')
      ..writeln(
        "    '\${d.year.toString().padLeft(4, '0')}-\${d.month.toString().padLeft(2, '0')}-\${d.day.toString().padLeft(2, '0')}';",
      )
      ..writeln();

    final sortedEnums = _enums.values.toList()
      ..sort((a, b) => a.name!.compareTo(b.name!));
    for (final def in sortedEnums) {
      _writeEnum(out, def);
    }
    final unions = _unions.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final union in unions) {
      _writeUnion(out, union);
    }
    final names = schemas.keys.toList()
      ..sort((a, b) => _className(a).compareTo(_className(b)));
    for (final name in names) {
      _writeModel(out, name, schemas[name]!);
    }
    return out.toString();
  }

  void _writeEnum(StringBuffer out, _EnumDef def) {
    final name = def.name!;
    out.write(_doc(def.description));
    out.writeln('enum $name {');
    for (final value in def.values) {
      out.writeln('  ${_enumMember(def.values, value)}(${_quote(value)}),');
    }
    out
      ..writeln()
      ..writeln('  /// A value added to the API after this client was built.')
      ..writeln("  unknown('');")
      ..writeln()
      ..writeln('  const $name(this.json);')
      ..writeln()
      ..writeln('  /// The wire value.')
      ..writeln('  final String json;')
      ..writeln()
      ..writeln('  static $name fromJson(String json) =>')
      ..writeln(
        '      values.firstWhere((v) => v.json == json, orElse: () => unknown);',
      )
      ..writeln('}')
      ..writeln();
  }

  /// Properties common to every variant of [union], with identical types.
  List<(String prop, String dartType)> _sharedFields(_Union union) {
    List<(String, String)>? shared;
    for (final variant in union.variants.values) {
      final schemaName = schemas.keys.firstWhere(
        (s) => _className(s) == variant,
      );
      final fields = [
        for (final f in _fields(schemaName, schemas[schemaName]!))
          if (f.constValue == null) (f.json, f.dartDecl),
      ];
      shared = shared == null ? fields : shared.where(fields.contains).toList();
    }
    return shared ?? const [];
  }

  void _writeUnion(StringBuffer out, _Union union) {
    final name = union.name;
    final prop = _identifier(union.property);
    out
      ..writeln(
        '/// One of ${union.variants.values.map((v) => '[$v]').join(', ')},',
      )
      ..writeln('/// discriminated by `${union.property}`.')
      ..writeln('@immutable')
      ..writeln('sealed class $name {')
      ..writeln('  const $name();')
      ..writeln()
      ..writeln('  factory $name.fromJson(Map<String, Object?> json) =>')
      ..writeln('      switch (json[${_quote(union.property)}]) {');
    for (final MapEntry(key: value, value: cls) in union.variants.entries) {
      out.writeln('        ${_quote(value)} => $cls.fromJson(json),');
    }
    out
      ..writeln(
        "        final other => throw FormatException('Unknown $name: \$other'),",
      )
      ..writeln('      };')
      ..writeln()
      ..writeln('  String get $prop;')
      ..writeln();
    for (final (json, dartType) in _sharedFields(union)) {
      out.writeln('  $dartType get ${_identifier(json)};');
      out.writeln();
    }
    out
      ..writeln('  Map<String, Object?> toJson();')
      ..writeln('}')
      ..writeln();
  }

  List<_Field> _fields(String schemaName, Map<String, Object?> schema) {
    final required = ((schema['required'] as List<Object?>?) ?? const [])
        .cast<String>()
        .toSet();
    final props =
        (schema['properties'] as Map?)?.cast<String, Map<String, Object?>>() ??
        const {};
    return [
      for (final MapEntry(key: json, value: s) in props.entries)
        _field(json, s, required: required.contains(json)),
    ];
  }

  _Field _field(String json, Map<String, Object?> s, {required bool required}) {
    if (s['const'] case final String value) {
      return _Field(json, const _Prim('String'), constValue: value);
    }
    final resolved = _resolve(s);
    final defaultLiteral = required
        ? null
        : _defaultLiteral(s['default'], resolved.type);
    final nullable = resolved.nullable || (!required && defaultLiteral == null);
    return _Field(
      json,
      resolved.type,
      nullable: nullable,
      required: required,
      defaultLiteral: defaultLiteral,
      description: s['description'] as String?,
    );
  }

  void _writeModel(
    StringBuffer out,
    String schemaName,
    Map<String, Object?> schema,
  ) {
    final name = _className(schemaName);
    final union = _variantOf[name];
    final shared = union == null
        ? const <String>{}
        : _sharedFields(union).map((f) => f.$1).toSet();
    final fields = _fields(schemaName, schema);
    final ctorFields = fields.where((f) => f.constValue == null).toList();

    out.write(_doc(schema['description'] as String?));
    out.writeln('@immutable');
    out.writeln(
      union == null ? 'class $name {' : 'class $name extends ${union.name} {',
    );

    // Constructor.
    if (ctorFields.isEmpty) {
      out.writeln('  const $name();');
    } else {
      out.writeln('  const $name({');
      for (final f in ctorFields) {
        if (f.required) {
          out.writeln('    required this.${f.name},');
        } else if (f.defaultLiteral != null) {
          out.writeln('    this.${f.name} = ${f.defaultLiteral},');
        } else {
          out.writeln('    this.${f.name},');
        }
      }
      out.writeln('  });');
    }
    out.writeln();

    // fromJson.
    final jsonParam = ctorFields.isEmpty ? '_' : 'json';
    out.writeln('  factory $name.fromJson(Map<String, Object?> $jsonParam) =>');
    if (ctorFields.isEmpty) {
      out.writeln('      const $name();');
    } else {
      out.writeln('      $name(');
      for (final f in ctorFields) {
        out.writeln(
          '        ${f.name}: ${f.decodeFrom("json[${_quote(f.json)}]")},',
        );
      }
      out.writeln('      );');
    }
    out.writeln();

    // Fields.
    for (final f in fields) {
      out.write(_doc(f.description, indent: '  '));
      final override =
          union != null && (shared.contains(f.json) || f.json == union.property)
          ? '  @override\n'
          : '';
      if (f.constValue != null) {
        out.writeln(
          '$override  String get ${f.name} => ${_quote(f.constValue!)};',
        );
      } else {
        out.writeln('$override  final ${f.dartDecl} ${f.name};');
      }
      out.writeln();
    }

    // toJson.
    if (union != null) out.writeln('  @override');
    if (fields.isEmpty) {
      out.writeln('  Map<String, Object?> toJson() => const {};');
    } else {
      out.writeln('  Map<String, Object?> toJson() => {');
      for (final f in fields) {
        out.writeln('        ${f.encodeEntry()},');
      }
      out.writeln('      };');
    }
    out.writeln('}');
    out.writeln();
  }

  // ---- endpoints -----------------------------------------------------------

  String endpoints() {
    final groups = <String, List<String>>{};
    for (final (path, method, op) in _operations) {
      final tag = ((op['tags'] as List<Object?>?)?.first as String?) ?? 'misc';
      groups.putIfAbsent(tag, () => []).add(_operation(path, method, op));
    }
    final tags = groups.keys.toList()..sort();

    final out = StringBuffer()
      ..writeln(_header)
      ..writeln()
      ..writeln("import '../transport.dart';")
      ..writeln("import 'models.dart';")
      ..writeln()
      ..writeln(
        '/// Typed access to every UniRent API operation, grouped by tag.',
      )
      ..writeln('class UniRentApi {')
      ..writeln('  UniRentApi(ApiTransport transport)')
      ..write('    : ');
    out.write(
      tags
          .map((t) => '${_camel(t)} = ${_pascal(t)}Api(transport)')
          .join(',\n      '),
    );
    out
      ..writeln(';')
      ..writeln();
    for (final t in tags) {
      out.writeln('  final ${_pascal(t)}Api ${_camel(t)};');
    }
    out
      ..writeln('}')
      ..writeln();

    for (final t in tags) {
      out
        ..writeln('class ${_pascal(t)}Api {')
        ..writeln('  ${_pascal(t)}Api(this._transport);')
        ..writeln()
        ..writeln('  final ApiTransport _transport;')
        ..writeln();
      groups[t]!.forEach(out.writeln);
      out
        ..writeln('}')
        ..writeln();
    }
    return out.toString();
  }

  String _methodName(String path, String method, Map<String, Object?> op) {
    final id = op['operationId']! as String;
    final suffix = '${path.replaceAll(RegExp(r'\W'), '_')}_$method';
    if (!id.endsWith(suffix)) {
      throw StateError('Unexpected operationId $id for $method $path');
    }
    return _identifier(id.substring(0, id.length - suffix.length));
  }

  String _operation(String path, String method, Map<String, Object?> op) {
    final name = _methodName(path, method, op);
    final params = ((op['parameters'] as List<Object?>?) ?? const [])
        .cast<Map<String, Object?>>();

    final positional = <String>[];
    final named = <String>[];
    final query = <String>[];
    final headers = <String>[];
    var dartPath = path;

    for (final p in params) {
      final raw = p['name']! as String;
      final location = p['in']! as String;
      final schema = p['schema']! as Map<String, Object?>;
      final resolved = _resolve(schema);
      final type = resolved.type;
      final required = p['required'] == true;
      if (location == 'header' && raw == 'X-Service-Token') continue;
      final ident = location == 'header'
          ? _identifier(raw.toLowerCase())
          : _identifier(raw);

      switch (location) {
        case 'path':
          positional.add('${type.dart} $ident');
          dartPath = dartPath.replaceAll(
            '{$raw}',
            '\${Uri.encodeComponent(${_queryValue(ident, type)})}',
          );
        case 'query':
          if (required) {
            named.add('required ${type.dart} $ident');
            query.add('${_quote(raw)}: ${_queryValue(ident, type)}');
          } else {
            named.add('${type.dart}? $ident');
            query.add(
              '${_quote(raw)}: ?${_queryValue(ident, type, nullable: true)}',
            );
          }
        case 'header':
          if (required) {
            named.add('required ${type.dart} $ident');
            headers.add('${_quote(raw)}: $ident');
          } else {
            named.add('${type.dart}? $ident');
            headers.add('${_quote(raw)}: ?$ident');
          }
        default:
          throw UnsupportedError('Parameter in $location: $raw');
      }
    }

    String? bodyExpr;
    if (op['requestBody'] case final Map<String, Object?> body) {
      final content = (body['content']! as Map).cast<String, Object?>();
      final json = content['application/json'] as Map<String, Object?>?;
      if (json == null) throw UnsupportedError('Body types ${content.keys}');
      final type = _resolve(json['schema']! as Map<String, Object?>).type;
      positional.add('${type.dart} body');
      bodyExpr = type.encode('body', 0);
    }

    final responses = (op['responses']! as Map).cast<String, Object?>();
    final success = responses.keys.where((c) => c.startsWith('2')).toList();
    if (success.length != 1) {
      throw UnsupportedError('$method $path: responses $success');
    }
    final response = responses[success.single]! as Map<String, Object?>;
    final content = (response['content'] as Map?)?.cast<String, Object?>();
    _Resolved? result;
    if (content != null && success.single != '204') {
      final json = content['application/json']! as Map<String, Object?>;
      result = _resolve(json['schema']! as Map<String, Object?>);
    }

    final returnType = result == null
        ? 'void'
        : result.nullable
        ? '${result.type.dart}?'
        : result.type.dart;

    final signature = [
      ...positional,
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ].join(', ');

    final args = <String>[
      _quote(method.toUpperCase()),
      "'$dartPath'",
      if (query.isNotEmpty) 'query: {${query.join(', ')}}',
      if (headers.isNotEmpty) 'headers: {${headers.join(', ')}}',
      if (bodyExpr != null) 'body: $bodyExpr',
    ];

    final doc = StringBuffer()
      ..write(_doc(op['summary'] as String?, indent: '  '));
    if (op['description'] case final String d) {
      doc
        ..writeln('  ///')
        ..write(_doc(d, indent: '  '));
    }
    doc.writeln('  ///');
    doc.writeln('  /// `${method.toUpperCase()} $path`');

    final call = '_transport.send(${args.join(', ')},)';
    final String bodyCode;
    if (result == null) {
      bodyCode = '    await $call;';
    } else if (result.type is _Any) {
      bodyCode = '    return $call;';
    } else {
      final decode = result.type.decode('json', 0);
      bodyCode = result.nullable
          ? '    final json = await $call;\n    return json == null ? null : $decode;'
          : '    final json = await $call;\n    return $decode;';
    }
    return '$doc  Future<$returnType> $name($signature) async {\n$bodyCode\n  }\n';
  }

  String _queryValue(String ident, _Type type, {bool nullable = false}) {
    final q = nullable ? '?' : '';
    return switch (type) {
      _Enum() => '$ident$q.json',
      _DateTime(dateOnly: false) => '$ident$q.toUtc().toIso8601String()',
      _DateTime(dateOnly: true) =>
        nullable
            ? '($ident == null ? null : _formatDate($ident))'
            : '_formatDate($ident)',
      _Prim(dart: 'String') => ident,
      _Prim() => '$ident$q.toString()',
      _ => throw UnsupportedError('Query parameter of type ${type.dart}'),
    };
  }
}

class _Field {
  _Field(
    this.json,
    this.type, {
    this.nullable = false,
    this.required = false,
    this.defaultLiteral,
    this.constValue,
    this.description,
  });

  final String json;
  final _Type type;
  final bool nullable;
  final bool required;
  final String? defaultLiteral;
  final String? constValue;
  final String? description;

  String get name => _identifier(json);

  String get dartDecl => nullable ? '${type.dart}?' : type.dart;

  String decodeFrom(String e) {
    final t = type;
    if (t is _Any) return e;
    if (defaultLiteral != null) {
      return '$e == null ? $defaultLiteral : ${t.decode(e, 0)}';
    }
    if (!nullable) return t.decode(e, 0);
    return switch (t) {
      _Prim(dart: 'String' || 'bool') => '$e as ${t.dart}?',
      _Prim(dart: 'int') => '($e as num?)?.toInt()',
      _Prim(dart: 'double') => '($e as num?)?.toDouble()',
      _ => '$e == null ? null : ${t.decode(e, 0)}',
    };
  }

  String encodeEntry() {
    final key = _quote(json);
    if (constValue != null) return '$key: $name';
    final t = type;
    if (!nullable || t is _Any) return '$key: ${t.encode(name, 0)}';
    final value = t.encodesAsIs
        ? name
        : switch (t) {
            _Named() => '$name?.toJson()',
            _Enum() => '$name?.json',
            _DateTime(dateOnly: false) => '$name?.toUtc().toIso8601String()',
            // Lists and maps encode as `x.map(...)`, so `x?.map(...)` works.
            _List() || _Map() => t.encode('$name?', 0),
            _ => '$name == null ? null : ${t.encode('$name!', 0)}',
          };
    // Required-but-nullable fields are sent as null; optional ones omitted.
    return required ? '$key: $value' : '$key: ?$value';
  }
}
