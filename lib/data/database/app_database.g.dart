// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#E8B731'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownerKeyMeta = const VerificationMeta(
    'ownerKey',
  );
  @override
  late final GeneratedColumn<String> ownerKey = GeneratedColumn<String>(
    'owner_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    createdAt,
    updatedAt,
    isDeleted,
    pendingSync,
    ownerKey,
    baseRevision,
    authorId,
    isShared,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('owner_key')) {
      context.handle(
        _ownerKeyMeta,
        ownerKey.isAcceptableOrUnknown(data['owner_key']!, _ownerKeyMeta),
      );
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      ownerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_key'],
      ),
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool pendingSync;
  final String? ownerKey;

  /// The server revision this row's local state was based on. Null means the
  /// row has never been to the server. Written by the sync layer, not by the
  /// repository.
  final int? baseRevision;

  /// Who wrote this row. Distinct from [ownerKey], which says whose local
  /// replica it is -- in a shared dig site those differ, and conflating them
  /// is exactly what would let one account's rows render as another's.
  final String? authorId;

  /// True when this folder has members beyond its owner. Display only: the
  /// server stays the authority on who may actually read it, so a stale
  /// `true` here shows a badge, never grants access.
  final bool isShared;
  const Folder({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.updatedAt,
    required this.isDeleted,
    required this.pendingSync,
    this.ownerKey,
    this.baseRevision,
    this.authorId,
    required this.isShared,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['pending_sync'] = Variable<bool>(pendingSync);
    if (!nullToAbsent || ownerKey != null) {
      map['owner_key'] = Variable<String>(ownerKey);
    }
    if (!nullToAbsent || baseRevision != null) {
      map['base_revision'] = Variable<int>(baseRevision);
    }
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    map['is_shared'] = Variable<bool>(isShared);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDeleted: Value(isDeleted),
      pendingSync: Value(pendingSync),
      ownerKey: ownerKey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerKey),
      baseRevision: baseRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRevision),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      isShared: Value(isShared),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      ownerKey: serializer.fromJson<String?>(json['ownerKey']),
      baseRevision: serializer.fromJson<int?>(json['baseRevision']),
      authorId: serializer.fromJson<String?>(json['authorId']),
      isShared: serializer.fromJson<bool>(json['isShared']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'ownerKey': serializer.toJson<String?>(ownerKey),
      'baseRevision': serializer.toJson<int?>(baseRevision),
      'authorId': serializer.toJson<String?>(authorId),
      'isShared': serializer.toJson<bool>(isShared),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isDeleted,
    bool? pendingSync,
    Value<String?> ownerKey = const Value.absent(),
    Value<int?> baseRevision = const Value.absent(),
    Value<String?> authorId = const Value.absent(),
    bool? isShared,
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    pendingSync: pendingSync ?? this.pendingSync,
    ownerKey: ownerKey.present ? ownerKey.value : this.ownerKey,
    baseRevision: baseRevision.present ? baseRevision.value : this.baseRevision,
    authorId: authorId.present ? authorId.value : this.authorId,
    isShared: isShared ?? this.isShared,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      ownerKey: data.ownerKey.present ? data.ownerKey.value : this.ownerKey,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('ownerKey: $ownerKey, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    createdAt,
    updatedAt,
    isDeleted,
    pendingSync,
    ownerKey,
    baseRevision,
    authorId,
    isShared,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.pendingSync == this.pendingSync &&
          other.ownerKey == this.ownerKey &&
          other.baseRevision == this.baseRevision &&
          other.authorId == this.authorId &&
          other.isShared == this.isShared);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isDeleted;
  final Value<bool> pendingSync;
  final Value<String?> ownerKey;
  final Value<int?> baseRevision;
  final Value<String?> authorId;
  final Value<bool> isShared;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.ownerKey = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.ownerKey = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<bool>? pendingSync,
    Expression<String>? ownerKey,
    Expression<int>? baseRevision,
    Expression<String>? authorId,
    Expression<bool>? isShared,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (ownerKey != null) 'owner_key': ownerKey,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (authorId != null) 'author_id': authorId,
      if (isShared != null) 'is_shared': isShared,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? isDeleted,
    Value<bool>? pendingSync,
    Value<String?>? ownerKey,
    Value<int?>? baseRevision,
    Value<String?>? authorId,
    Value<bool>? isShared,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      pendingSync: pendingSync ?? this.pendingSync,
      ownerKey: ownerKey ?? this.ownerKey,
      baseRevision: baseRevision ?? this.baseRevision,
      authorId: authorId ?? this.authorId,
      isShared: isShared ?? this.isShared,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (ownerKey.present) {
      map['owner_key'] = Variable<String>(ownerKey.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('ownerKey: $ownerKey, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownerKeyMeta = const VerificationMeta(
    'ownerKey',
  );
  @override
  late final GeneratedColumn<String> ownerKey = GeneratedColumn<String>(
    'owner_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    date,
    audioPath,
    folderId,
    updatedAt,
    isDeleted,
    pendingSync,
    ownerKey,
    baseRevision,
    authorId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('owner_key')) {
      context.handle(
        _ownerKeyMeta,
        ownerKey.isAcceptableOrUnknown(data['owner_key']!, _ownerKeyMeta),
      );
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      ownerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_key'],
      ),
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? audioPath;
  final String? folderId;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool pendingSync;
  final String? ownerKey;

  /// The server revision this row's local state was based on. Null means the
  /// row has never been to the server. Written by the sync layer, not by the
  /// repository.
  final int? baseRevision;

  /// Who wrote this row. Distinct from [ownerKey], which says whose local
  /// replica it is -- in a shared dig site those differ, and conflating them
  /// is exactly what would let one account's rows render as another's.
  final String? authorId;
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.audioPath,
    this.folderId,
    this.updatedAt,
    required this.isDeleted,
    required this.pendingSync,
    this.ownerKey,
    this.baseRevision,
    this.authorId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['pending_sync'] = Variable<bool>(pendingSync);
    if (!nullToAbsent || ownerKey != null) {
      map['owner_key'] = Variable<String>(ownerKey);
    }
    if (!nullToAbsent || baseRevision != null) {
      map['base_revision'] = Variable<int>(baseRevision);
    }
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      date: Value(date),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDeleted: Value(isDeleted),
      pendingSync: Value(pendingSync),
      ownerKey: ownerKey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerKey),
      baseRevision: baseRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRevision),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      date: serializer.fromJson<DateTime>(json['date']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      ownerKey: serializer.fromJson<String?>(json['ownerKey']),
      baseRevision: serializer.fromJson<int?>(json['baseRevision']),
      authorId: serializer.fromJson<String?>(json['authorId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'date': serializer.toJson<DateTime>(date),
      'audioPath': serializer.toJson<String?>(audioPath),
      'folderId': serializer.toJson<String?>(folderId),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'ownerKey': serializer.toJson<String?>(ownerKey),
      'baseRevision': serializer.toJson<int?>(baseRevision),
      'authorId': serializer.toJson<String?>(authorId),
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    Value<String?> audioPath = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isDeleted,
    bool? pendingSync,
    Value<String?> ownerKey = const Value.absent(),
    Value<int?> baseRevision = const Value.absent(),
    Value<String?> authorId = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    date: date ?? this.date,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    folderId: folderId.present ? folderId.value : this.folderId,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    pendingSync: pendingSync ?? this.pendingSync,
    ownerKey: ownerKey.present ? ownerKey.value : this.ownerKey,
    baseRevision: baseRevision.present ? baseRevision.value : this.baseRevision,
    authorId: authorId.present ? authorId.value : this.authorId,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      date: data.date.present ? data.date.value : this.date,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      ownerKey: data.ownerKey.present ? data.ownerKey.value : this.ownerKey,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('date: $date, ')
          ..write('audioPath: $audioPath, ')
          ..write('folderId: $folderId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('ownerKey: $ownerKey, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    date,
    audioPath,
    folderId,
    updatedAt,
    isDeleted,
    pendingSync,
    ownerKey,
    baseRevision,
    authorId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.date == this.date &&
          other.audioPath == this.audioPath &&
          other.folderId == this.folderId &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.pendingSync == this.pendingSync &&
          other.ownerKey == this.ownerKey &&
          other.baseRevision == this.baseRevision &&
          other.authorId == this.authorId);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> content;
  final Value<DateTime> date;
  final Value<String?> audioPath;
  final Value<String?> folderId;
  final Value<DateTime?> updatedAt;
  final Value<bool> isDeleted;
  final Value<bool> pendingSync;
  final Value<String?> ownerKey;
  final Value<int?> baseRevision;
  final Value<String?> authorId;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.date = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.folderId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.ownerKey = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String title,
    required String content,
    required DateTime date,
    this.audioPath = const Value.absent(),
    this.folderId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.ownerKey = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       content = Value(content),
       date = Value(date);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<DateTime>? date,
    Expression<String>? audioPath,
    Expression<String>? folderId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<bool>? pendingSync,
    Expression<String>? ownerKey,
    Expression<int>? baseRevision,
    Expression<String>? authorId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (date != null) 'date': date,
      if (audioPath != null) 'audio_path': audioPath,
      if (folderId != null) 'folder_id': folderId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (ownerKey != null) 'owner_key': ownerKey,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (authorId != null) 'author_id': authorId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? content,
    Value<DateTime>? date,
    Value<String?>? audioPath,
    Value<String?>? folderId,
    Value<DateTime?>? updatedAt,
    Value<bool>? isDeleted,
    Value<bool>? pendingSync,
    Value<String?>? ownerKey,
    Value<int?>? baseRevision,
    Value<String?>? authorId,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      audioPath: audioPath ?? this.audioPath,
      folderId: folderId ?? this.folderId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      pendingSync: pendingSync ?? this.pendingSync,
      ownerKey: ownerKey ?? this.ownerKey,
      baseRevision: baseRevision ?? this.baseRevision,
      authorId: authorId ?? this.authorId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (ownerKey.present) {
      map['owner_key'] = Variable<String>(ownerKey.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('date: $date, ')
          ..write('audioPath: $audioPath, ')
          ..write('folderId: $folderId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('ownerKey: $ownerKey, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageMetadataTable extends ImageMetadata
    with TableInfo<$ImageMetadataTable, ImageMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisResultMeta = const VerificationMeta(
    'analysisResult',
  );
  @override
  late final GeneratedColumn<String> analysisResult = GeneratedColumn<String>(
    'analysis_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    imagePath,
    latitude,
    longitude,
    analysisResult,
    capturedAt,
    noteId,
    updatedAt,
    isDeleted,
    baseRevision,
    authorId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('analysis_result')) {
      context.handle(
        _analysisResultMeta,
        analysisResult.isAcceptableOrUnknown(
          data['analysis_result']!,
          _analysisResultMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImageMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageMetadataData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      analysisResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_result'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
    );
  }

  @override
  $ImageMetadataTable createAlias(String alias) {
    return $ImageMetadataTable(attachedDatabase, alias);
  }
}

class ImageMetadataData extends DataClass
    implements Insertable<ImageMetadataData> {
  final String id;
  final String imagePath;
  final double? latitude;
  final double? longitude;
  final String? analysisResult;
  final DateTime capturedAt;
  final String? noteId;
  final DateTime? updatedAt;
  final bool isDeleted;

  /// The server revision this row's local state was based on. Null means the
  /// row has never been to the server. Written by the sync layer, not by the
  /// repository.
  final int? baseRevision;

  /// Who wrote this row. Distinct from [ownerKey], which says whose local
  /// replica it is -- in a shared dig site those differ, and conflating them
  /// is exactly what would let one account's rows render as another's.
  final String? authorId;
  const ImageMetadataData({
    required this.id,
    required this.imagePath,
    this.latitude,
    this.longitude,
    this.analysisResult,
    required this.capturedAt,
    this.noteId,
    this.updatedAt,
    required this.isDeleted,
    this.baseRevision,
    this.authorId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || analysisResult != null) {
      map['analysis_result'] = Variable<String>(analysisResult);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || baseRevision != null) {
      map['base_revision'] = Variable<int>(baseRevision);
    }
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    return map;
  }

  ImageMetadataCompanion toCompanion(bool nullToAbsent) {
    return ImageMetadataCompanion(
      id: Value(id),
      imagePath: Value(imagePath),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      analysisResult: analysisResult == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisResult),
      capturedAt: Value(capturedAt),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDeleted: Value(isDeleted),
      baseRevision: baseRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRevision),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
    );
  }

  factory ImageMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageMetadataData(
      id: serializer.fromJson<String>(json['id']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      analysisResult: serializer.fromJson<String?>(json['analysisResult']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      baseRevision: serializer.fromJson<int?>(json['baseRevision']),
      authorId: serializer.fromJson<String?>(json['authorId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'imagePath': serializer.toJson<String>(imagePath),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'analysisResult': serializer.toJson<String?>(analysisResult),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'noteId': serializer.toJson<String?>(noteId),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'baseRevision': serializer.toJson<int?>(baseRevision),
      'authorId': serializer.toJson<String?>(authorId),
    };
  }

  ImageMetadataData copyWith({
    String? id,
    String? imagePath,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> analysisResult = const Value.absent(),
    DateTime? capturedAt,
    Value<String?> noteId = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isDeleted,
    Value<int?> baseRevision = const Value.absent(),
    Value<String?> authorId = const Value.absent(),
  }) => ImageMetadataData(
    id: id ?? this.id,
    imagePath: imagePath ?? this.imagePath,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    analysisResult: analysisResult.present
        ? analysisResult.value
        : this.analysisResult,
    capturedAt: capturedAt ?? this.capturedAt,
    noteId: noteId.present ? noteId.value : this.noteId,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    baseRevision: baseRevision.present ? baseRevision.value : this.baseRevision,
    authorId: authorId.present ? authorId.value : this.authorId,
  );
  ImageMetadataData copyWithCompanion(ImageMetadataCompanion data) {
    return ImageMetadataData(
      id: data.id.present ? data.id.value : this.id,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      analysisResult: data.analysisResult.present
          ? data.analysisResult.value
          : this.analysisResult,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageMetadataData(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('analysisResult: $analysisResult, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('noteId: $noteId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    imagePath,
    latitude,
    longitude,
    analysisResult,
    capturedAt,
    noteId,
    updatedAt,
    isDeleted,
    baseRevision,
    authorId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageMetadataData &&
          other.id == this.id &&
          other.imagePath == this.imagePath &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.analysisResult == this.analysisResult &&
          other.capturedAt == this.capturedAt &&
          other.noteId == this.noteId &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.baseRevision == this.baseRevision &&
          other.authorId == this.authorId);
}

class ImageMetadataCompanion extends UpdateCompanion<ImageMetadataData> {
  final Value<String> id;
  final Value<String> imagePath;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> analysisResult;
  final Value<DateTime> capturedAt;
  final Value<String?> noteId;
  final Value<DateTime?> updatedAt;
  final Value<bool> isDeleted;
  final Value<int?> baseRevision;
  final Value<String?> authorId;
  final Value<int> rowid;
  const ImageMetadataCompanion({
    this.id = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.analysisResult = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.noteId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageMetadataCompanion.insert({
    required String id,
    required String imagePath,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.analysisResult = const Value.absent(),
    required DateTime capturedAt,
    this.noteId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       imagePath = Value(imagePath),
       capturedAt = Value(capturedAt);
  static Insertable<ImageMetadataData> custom({
    Expression<String>? id,
    Expression<String>? imagePath,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? analysisResult,
    Expression<DateTime>? capturedAt,
    Expression<String>? noteId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? baseRevision,
    Expression<String>? authorId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imagePath != null) 'image_path': imagePath,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (analysisResult != null) 'analysis_result': analysisResult,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (noteId != null) 'note_id': noteId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (authorId != null) 'author_id': authorId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageMetadataCompanion copyWith({
    Value<String>? id,
    Value<String>? imagePath,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? analysisResult,
    Value<DateTime>? capturedAt,
    Value<String?>? noteId,
    Value<DateTime?>? updatedAt,
    Value<bool>? isDeleted,
    Value<int?>? baseRevision,
    Value<String?>? authorId,
    Value<int>? rowid,
  }) {
    return ImageMetadataCompanion(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      analysisResult: analysisResult ?? this.analysisResult,
      capturedAt: capturedAt ?? this.capturedAt,
      noteId: noteId ?? this.noteId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      baseRevision: baseRevision ?? this.baseRevision,
      authorId: authorId ?? this.authorId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (analysisResult.present) {
      map['analysis_result'] = Variable<String>(analysisResult.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageMetadataCompanion(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('analysisResult: $analysisResult, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('noteId: $noteId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtifactCommentsTable extends ArtifactComments
    with TableInfo<$ArtifactCommentsTable, ArtifactComment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtifactCommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artifactIdMeta = const VerificationMeta(
    'artifactId',
  );
  @override
  late final GeneratedColumn<String> artifactId = GeneratedColumn<String>(
    'artifact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    artifactId,
    body,
    createdAt,
    updatedAt,
    isDeleted,
    baseRevision,
    authorId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artifact_comments';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtifactComment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('artifact_id')) {
      context.handle(
        _artifactIdMeta,
        artifactId.isAcceptableOrUnknown(data['artifact_id']!, _artifactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artifactIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArtifactComment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtifactComment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      artifactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artifact_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
    );
  }

  @override
  $ArtifactCommentsTable createAlias(String alias) {
    return $ArtifactCommentsTable(attachedDatabase, alias);
  }
}

class ArtifactComment extends DataClass implements Insertable<ArtifactComment> {
  final String id;
  final String artifactId;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  /// The server revision this row's local state was based on. Null means the
  /// row has never been to the server. Written by the sync layer, not by the
  /// repository.
  final int? baseRevision;

  /// Who wrote this row. Distinct from [ownerKey], which says whose local
  /// replica it is -- in a shared dig site those differ, and conflating them
  /// is exactly what would let one account's rows render as another's.
  final String? authorId;
  const ArtifactComment({
    required this.id,
    required this.artifactId,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    required this.isDeleted,
    this.baseRevision,
    this.authorId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['artifact_id'] = Variable<String>(artifactId);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || baseRevision != null) {
      map['base_revision'] = Variable<int>(baseRevision);
    }
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    return map;
  }

  ArtifactCommentsCompanion toCompanion(bool nullToAbsent) {
    return ArtifactCommentsCompanion(
      id: Value(id),
      artifactId: Value(artifactId),
      body: Value(body),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDeleted: Value(isDeleted),
      baseRevision: baseRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRevision),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
    );
  }

  factory ArtifactComment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtifactComment(
      id: serializer.fromJson<String>(json['id']),
      artifactId: serializer.fromJson<String>(json['artifactId']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      baseRevision: serializer.fromJson<int?>(json['baseRevision']),
      authorId: serializer.fromJson<String?>(json['authorId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'artifactId': serializer.toJson<String>(artifactId),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'baseRevision': serializer.toJson<int?>(baseRevision),
      'authorId': serializer.toJson<String?>(authorId),
    };
  }

  ArtifactComment copyWith({
    String? id,
    String? artifactId,
    String? body,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? isDeleted,
    Value<int?> baseRevision = const Value.absent(),
    Value<String?> authorId = const Value.absent(),
  }) => ArtifactComment(
    id: id ?? this.id,
    artifactId: artifactId ?? this.artifactId,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    baseRevision: baseRevision.present ? baseRevision.value : this.baseRevision,
    authorId: authorId.present ? authorId.value : this.authorId,
  );
  ArtifactComment copyWithCompanion(ArtifactCommentsCompanion data) {
    return ArtifactComment(
      id: data.id.present ? data.id.value : this.id,
      artifactId: data.artifactId.present
          ? data.artifactId.value
          : this.artifactId,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtifactComment(')
          ..write('id: $id, ')
          ..write('artifactId: $artifactId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    artifactId,
    body,
    createdAt,
    updatedAt,
    isDeleted,
    baseRevision,
    authorId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtifactComment &&
          other.id == this.id &&
          other.artifactId == this.artifactId &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.baseRevision == this.baseRevision &&
          other.authorId == this.authorId);
}

class ArtifactCommentsCompanion extends UpdateCompanion<ArtifactComment> {
  final Value<String> id;
  final Value<String> artifactId;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isDeleted;
  final Value<int?> baseRevision;
  final Value<String?> authorId;
  final Value<int> rowid;
  const ArtifactCommentsCompanion({
    this.id = const Value.absent(),
    this.artifactId = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtifactCommentsCompanion.insert({
    required String id,
    required String artifactId,
    required String body,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       artifactId = Value(artifactId),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<ArtifactComment> custom({
    Expression<String>? id,
    Expression<String>? artifactId,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? baseRevision,
    Expression<String>? authorId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (artifactId != null) 'artifact_id': artifactId,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (authorId != null) 'author_id': authorId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtifactCommentsCompanion copyWith({
    Value<String>? id,
    Value<String>? artifactId,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? isDeleted,
    Value<int?>? baseRevision,
    Value<String?>? authorId,
    Value<int>? rowid,
  }) {
    return ArtifactCommentsCompanion(
      id: id ?? this.id,
      artifactId: artifactId ?? this.artifactId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      baseRevision: baseRevision ?? this.baseRevision,
      authorId: authorId ?? this.authorId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (artifactId.present) {
      map['artifact_id'] = Variable<String>(artifactId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtifactCommentsCompanion(')
          ..write('id: $id, ')
          ..write('artifactId: $artifactId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('authorId: $authorId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $ImageMetadataTable imageMetadata = $ImageMetadataTable(this);
  late final $ArtifactCommentsTable artifactComments = $ArtifactCommentsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    notes,
    imageMetadata,
    artifactComments,
  ];
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      required String name,
      Value<String> color,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<bool> pendingSync,
      Value<String?> ownerKey,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<bool> isShared,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<bool> pendingSync,
      Value<String?> ownerKey,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<bool> isShared,
      Value<int> rowid,
    });

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerKey =>
      $composableBuilder(column: $table.ownerKey, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
          Folder,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<String?> ownerKey = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                pendingSync: pendingSync,
                ownerKey: ownerKey,
                baseRevision: baseRevision,
                authorId: authorId,
                isShared: isShared,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> color = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<String?> ownerKey = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                pendingSync: pendingSync,
                ownerKey: ownerKey,
                baseRevision: baseRevision,
                authorId: authorId,
                isShared: isShared,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
      Folder,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String title,
      required String content,
      required DateTime date,
      Value<String?> audioPath,
      Value<String?> folderId,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<bool> pendingSync,
      Value<String?> ownerKey,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> content,
      Value<DateTime> date,
      Value<String?> audioPath,
      Value<String?> folderId,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<bool> pendingSync,
      Value<String?> ownerKey,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerKey => $composableBuilder(
    column: $table.ownerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerKey =>
      $composableBuilder(column: $table.ownerKey, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<String?> ownerKey = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                title: title,
                content: content,
                date: date,
                audioPath: audioPath,
                folderId: folderId,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                pendingSync: pendingSync,
                ownerKey: ownerKey,
                baseRevision: baseRevision,
                authorId: authorId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String content,
                required DateTime date,
                Value<String?> audioPath = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<String?> ownerKey = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                title: title,
                content: content,
                date: date,
                audioPath: audioPath,
                folderId: folderId,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                pendingSync: pendingSync,
                ownerKey: ownerKey,
                baseRevision: baseRevision,
                authorId: authorId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$ImageMetadataTableCreateCompanionBuilder =
    ImageMetadataCompanion Function({
      required String id,
      required String imagePath,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> analysisResult,
      required DateTime capturedAt,
      Value<String?> noteId,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<int> rowid,
    });
typedef $$ImageMetadataTableUpdateCompanionBuilder =
    ImageMetadataCompanion Function({
      Value<String> id,
      Value<String> imagePath,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> analysisResult,
      Value<DateTime> capturedAt,
      Value<String?> noteId,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<int> rowid,
    });

class $$ImageMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $ImageMetadataTable> {
  $$ImageMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisResult => $composableBuilder(
    column: $table.analysisResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImageMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageMetadataTable> {
  $$ImageMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisResult => $composableBuilder(
    column: $table.analysisResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImageMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageMetadataTable> {
  $$ImageMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get analysisResult => $composableBuilder(
    column: $table.analysisResult,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);
}

class $$ImageMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageMetadataTable,
          ImageMetadataData,
          $$ImageMetadataTableFilterComposer,
          $$ImageMetadataTableOrderingComposer,
          $$ImageMetadataTableAnnotationComposer,
          $$ImageMetadataTableCreateCompanionBuilder,
          $$ImageMetadataTableUpdateCompanionBuilder,
          (
            ImageMetadataData,
            BaseReferences<
              _$AppDatabase,
              $ImageMetadataTable,
              ImageMetadataData
            >,
          ),
          ImageMetadataData,
          PrefetchHooks Function()
        > {
  $$ImageMetadataTableTableManager(_$AppDatabase db, $ImageMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> analysisResult = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageMetadataCompanion(
                id: id,
                imagePath: imagePath,
                latitude: latitude,
                longitude: longitude,
                analysisResult: analysisResult,
                capturedAt: capturedAt,
                noteId: noteId,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                baseRevision: baseRevision,
                authorId: authorId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String imagePath,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> analysisResult = const Value.absent(),
                required DateTime capturedAt,
                Value<String?> noteId = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageMetadataCompanion.insert(
                id: id,
                imagePath: imagePath,
                latitude: latitude,
                longitude: longitude,
                analysisResult: analysisResult,
                capturedAt: capturedAt,
                noteId: noteId,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                baseRevision: baseRevision,
                authorId: authorId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImageMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageMetadataTable,
      ImageMetadataData,
      $$ImageMetadataTableFilterComposer,
      $$ImageMetadataTableOrderingComposer,
      $$ImageMetadataTableAnnotationComposer,
      $$ImageMetadataTableCreateCompanionBuilder,
      $$ImageMetadataTableUpdateCompanionBuilder,
      (
        ImageMetadataData,
        BaseReferences<_$AppDatabase, $ImageMetadataTable, ImageMetadataData>,
      ),
      ImageMetadataData,
      PrefetchHooks Function()
    >;
typedef $$ArtifactCommentsTableCreateCompanionBuilder =
    ArtifactCommentsCompanion Function({
      required String id,
      required String artifactId,
      required String body,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<int> rowid,
    });
typedef $$ArtifactCommentsTableUpdateCompanionBuilder =
    ArtifactCommentsCompanion Function({
      Value<String> id,
      Value<String> artifactId,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> isDeleted,
      Value<int?> baseRevision,
      Value<String?> authorId,
      Value<int> rowid,
    });

class $$ArtifactCommentsTableFilterComposer
    extends Composer<_$AppDatabase, $ArtifactCommentsTable> {
  $$ArtifactCommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artifactId => $composableBuilder(
    column: $table.artifactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtifactCommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtifactCommentsTable> {
  $$ArtifactCommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artifactId => $composableBuilder(
    column: $table.artifactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtifactCommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtifactCommentsTable> {
  $$ArtifactCommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get artifactId => $composableBuilder(
    column: $table.artifactId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);
}

class $$ArtifactCommentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtifactCommentsTable,
          ArtifactComment,
          $$ArtifactCommentsTableFilterComposer,
          $$ArtifactCommentsTableOrderingComposer,
          $$ArtifactCommentsTableAnnotationComposer,
          $$ArtifactCommentsTableCreateCompanionBuilder,
          $$ArtifactCommentsTableUpdateCompanionBuilder,
          (
            ArtifactComment,
            BaseReferences<
              _$AppDatabase,
              $ArtifactCommentsTable,
              ArtifactComment
            >,
          ),
          ArtifactComment,
          PrefetchHooks Function()
        > {
  $$ArtifactCommentsTableTableManager(
    _$AppDatabase db,
    $ArtifactCommentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtifactCommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtifactCommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtifactCommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> artifactId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtifactCommentsCompanion(
                id: id,
                artifactId: artifactId,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                baseRevision: baseRevision,
                authorId: authorId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String artifactId,
                required String body,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> baseRevision = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtifactCommentsCompanion.insert(
                id: id,
                artifactId: artifactId,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                baseRevision: baseRevision,
                authorId: authorId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtifactCommentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtifactCommentsTable,
      ArtifactComment,
      $$ArtifactCommentsTableFilterComposer,
      $$ArtifactCommentsTableOrderingComposer,
      $$ArtifactCommentsTableAnnotationComposer,
      $$ArtifactCommentsTableCreateCompanionBuilder,
      $$ArtifactCommentsTableUpdateCompanionBuilder,
      (
        ArtifactComment,
        BaseReferences<_$AppDatabase, $ArtifactCommentsTable, ArtifactComment>,
      ),
      ArtifactComment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$ImageMetadataTableTableManager get imageMetadata =>
      $$ImageMetadataTableTableManager(_db, _db.imageMetadata);
  $$ArtifactCommentsTableTableManager get artifactComments =>
      $$ArtifactCommentsTableTableManager(_db, _db.artifactComments);
}
