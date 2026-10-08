// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedProfilesTable extends CachedProfiles
    with TableInfo<$CachedProfilesTable, CachedProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bioMeta = const VerificationMeta('bio');
  @override
  late final GeneratedColumn<String> bio = GeneratedColumn<String>(
      'bio', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _birthdateMeta =
      const VerificationMeta('birthdate');
  @override
  late final GeneratedColumn<DateTime> birthdate = GeneratedColumn<DateTime>(
      'birthdate', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _photosJsonMeta =
      const VerificationMeta('photosJson');
  @override
  late final GeneratedColumn<String> photosJson = GeneratedColumn<String>(
      'photos_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _interestsJsonMeta =
      const VerificationMeta('interestsJson');
  @override
  late final GeneratedColumn<String> interestsJson = GeneratedColumn<String>(
      'interests_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completenessScoreMeta =
      const VerificationMeta('completenessScore');
  @override
  late final GeneratedColumn<int> completenessScore = GeneratedColumn<int>(
      'completeness_score', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isVerifiedMeta =
      const VerificationMeta('isVerified');
  @override
  late final GeneratedColumn<bool> isVerified = GeneratedColumn<bool>(
      'is_verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_verified" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastActiveAtMeta =
      const VerificationMeta('lastActiveAt');
  @override
  late final GeneratedColumn<DateTime> lastActiveAt = GeneratedColumn<DateTime>(
      'last_active_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        bio,
        birthdate,
        gender,
        city,
        photosJson,
        interestsJson,
        completenessScore,
        isVerified,
        lastActiveAt,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<CachedProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bio')) {
      context.handle(
          _bioMeta, bio.isAcceptableOrUnknown(data['bio']!, _bioMeta));
    }
    if (data.containsKey('birthdate')) {
      context.handle(_birthdateMeta,
          birthdate.isAcceptableOrUnknown(data['birthdate']!, _birthdateMeta));
    } else if (isInserting) {
      context.missing(_birthdateMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    } else if (isInserting) {
      context.missing(_genderMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('photos_json')) {
      context.handle(
          _photosJsonMeta,
          photosJson.isAcceptableOrUnknown(
              data['photos_json']!, _photosJsonMeta));
    } else if (isInserting) {
      context.missing(_photosJsonMeta);
    }
    if (data.containsKey('interests_json')) {
      context.handle(
          _interestsJsonMeta,
          interestsJson.isAcceptableOrUnknown(
              data['interests_json']!, _interestsJsonMeta));
    } else if (isInserting) {
      context.missing(_interestsJsonMeta);
    }
    if (data.containsKey('completeness_score')) {
      context.handle(
          _completenessScoreMeta,
          completenessScore.isAcceptableOrUnknown(
              data['completeness_score']!, _completenessScoreMeta));
    }
    if (data.containsKey('is_verified')) {
      context.handle(
          _isVerifiedMeta,
          isVerified.isAcceptableOrUnknown(
              data['is_verified']!, _isVerifiedMeta));
    }
    if (data.containsKey('last_active_at')) {
      context.handle(
          _lastActiveAtMeta,
          lastActiveAt.isAcceptableOrUnknown(
              data['last_active_at']!, _lastActiveAtMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      bio: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bio']),
      birthdate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}birthdate'])!,
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city']),
      photosJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photos_json'])!,
      interestsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}interests_json'])!,
      completenessScore: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}completeness_score'])!,
      isVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_verified'])!,
      lastActiveAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_active_at']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedProfilesTable createAlias(String alias) {
    return $CachedProfilesTable(attachedDatabase, alias);
  }
}

class CachedProfile extends DataClass implements Insertable<CachedProfile> {
  final String id;
  final String name;
  final String? bio;
  final DateTime birthdate;
  final String gender;
  final String? city;
  final String photosJson;
  final String interestsJson;
  final int completenessScore;
  final bool isVerified;
  final DateTime? lastActiveAt;
  final DateTime cachedAt;
  const CachedProfile(
      {required this.id,
      required this.name,
      this.bio,
      required this.birthdate,
      required this.gender,
      this.city,
      required this.photosJson,
      required this.interestsJson,
      required this.completenessScore,
      required this.isVerified,
      this.lastActiveAt,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || bio != null) {
      map['bio'] = Variable<String>(bio);
    }
    map['birthdate'] = Variable<DateTime>(birthdate);
    map['gender'] = Variable<String>(gender);
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    map['photos_json'] = Variable<String>(photosJson);
    map['interests_json'] = Variable<String>(interestsJson);
    map['completeness_score'] = Variable<int>(completenessScore);
    map['is_verified'] = Variable<bool>(isVerified);
    if (!nullToAbsent || lastActiveAt != null) {
      map['last_active_at'] = Variable<DateTime>(lastActiveAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedProfilesCompanion toCompanion(bool nullToAbsent) {
    return CachedProfilesCompanion(
      id: Value(id),
      name: Value(name),
      bio: bio == null && nullToAbsent ? const Value.absent() : Value(bio),
      birthdate: Value(birthdate),
      gender: Value(gender),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      photosJson: Value(photosJson),
      interestsJson: Value(interestsJson),
      completenessScore: Value(completenessScore),
      isVerified: Value(isVerified),
      lastActiveAt: lastActiveAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastActiveAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bio: serializer.fromJson<String?>(json['bio']),
      birthdate: serializer.fromJson<DateTime>(json['birthdate']),
      gender: serializer.fromJson<String>(json['gender']),
      city: serializer.fromJson<String?>(json['city']),
      photosJson: serializer.fromJson<String>(json['photosJson']),
      interestsJson: serializer.fromJson<String>(json['interestsJson']),
      completenessScore: serializer.fromJson<int>(json['completenessScore']),
      isVerified: serializer.fromJson<bool>(json['isVerified']),
      lastActiveAt: serializer.fromJson<DateTime?>(json['lastActiveAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'bio': serializer.toJson<String?>(bio),
      'birthdate': serializer.toJson<DateTime>(birthdate),
      'gender': serializer.toJson<String>(gender),
      'city': serializer.toJson<String?>(city),
      'photosJson': serializer.toJson<String>(photosJson),
      'interestsJson': serializer.toJson<String>(interestsJson),
      'completenessScore': serializer.toJson<int>(completenessScore),
      'isVerified': serializer.toJson<bool>(isVerified),
      'lastActiveAt': serializer.toJson<DateTime?>(lastActiveAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedProfile copyWith(
          {String? id,
          String? name,
          Value<String?> bio = const Value.absent(),
          DateTime? birthdate,
          String? gender,
          Value<String?> city = const Value.absent(),
          String? photosJson,
          String? interestsJson,
          int? completenessScore,
          bool? isVerified,
          Value<DateTime?> lastActiveAt = const Value.absent(),
          DateTime? cachedAt}) =>
      CachedProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        bio: bio.present ? bio.value : this.bio,
        birthdate: birthdate ?? this.birthdate,
        gender: gender ?? this.gender,
        city: city.present ? city.value : this.city,
        photosJson: photosJson ?? this.photosJson,
        interestsJson: interestsJson ?? this.interestsJson,
        completenessScore: completenessScore ?? this.completenessScore,
        isVerified: isVerified ?? this.isVerified,
        lastActiveAt:
            lastActiveAt.present ? lastActiveAt.value : this.lastActiveAt,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedProfile copyWithCompanion(CachedProfilesCompanion data) {
    return CachedProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bio: data.bio.present ? data.bio.value : this.bio,
      birthdate: data.birthdate.present ? data.birthdate.value : this.birthdate,
      gender: data.gender.present ? data.gender.value : this.gender,
      city: data.city.present ? data.city.value : this.city,
      photosJson:
          data.photosJson.present ? data.photosJson.value : this.photosJson,
      interestsJson: data.interestsJson.present
          ? data.interestsJson.value
          : this.interestsJson,
      completenessScore: data.completenessScore.present
          ? data.completenessScore.value
          : this.completenessScore,
      isVerified:
          data.isVerified.present ? data.isVerified.value : this.isVerified,
      lastActiveAt: data.lastActiveAt.present
          ? data.lastActiveAt.value
          : this.lastActiveAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bio: $bio, ')
          ..write('birthdate: $birthdate, ')
          ..write('gender: $gender, ')
          ..write('city: $city, ')
          ..write('photosJson: $photosJson, ')
          ..write('interestsJson: $interestsJson, ')
          ..write('completenessScore: $completenessScore, ')
          ..write('isVerified: $isVerified, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      bio,
      birthdate,
      gender,
      city,
      photosJson,
      interestsJson,
      completenessScore,
      isVerified,
      lastActiveAt,
      cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.bio == this.bio &&
          other.birthdate == this.birthdate &&
          other.gender == this.gender &&
          other.city == this.city &&
          other.photosJson == this.photosJson &&
          other.interestsJson == this.interestsJson &&
          other.completenessScore == this.completenessScore &&
          other.isVerified == this.isVerified &&
          other.lastActiveAt == this.lastActiveAt &&
          other.cachedAt == this.cachedAt);
}

class CachedProfilesCompanion extends UpdateCompanion<CachedProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> bio;
  final Value<DateTime> birthdate;
  final Value<String> gender;
  final Value<String?> city;
  final Value<String> photosJson;
  final Value<String> interestsJson;
  final Value<int> completenessScore;
  final Value<bool> isVerified;
  final Value<DateTime?> lastActiveAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bio = const Value.absent(),
    this.birthdate = const Value.absent(),
    this.gender = const Value.absent(),
    this.city = const Value.absent(),
    this.photosJson = const Value.absent(),
    this.interestsJson = const Value.absent(),
    this.completenessScore = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.lastActiveAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProfilesCompanion.insert({
    required String id,
    required String name,
    this.bio = const Value.absent(),
    required DateTime birthdate,
    required String gender,
    this.city = const Value.absent(),
    required String photosJson,
    required String interestsJson,
    this.completenessScore = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.lastActiveAt = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        birthdate = Value(birthdate),
        gender = Value(gender),
        photosJson = Value(photosJson),
        interestsJson = Value(interestsJson),
        cachedAt = Value(cachedAt);
  static Insertable<CachedProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? bio,
    Expression<DateTime>? birthdate,
    Expression<String>? gender,
    Expression<String>? city,
    Expression<String>? photosJson,
    Expression<String>? interestsJson,
    Expression<int>? completenessScore,
    Expression<bool>? isVerified,
    Expression<DateTime>? lastActiveAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (birthdate != null) 'birthdate': birthdate,
      if (gender != null) 'gender': gender,
      if (city != null) 'city': city,
      if (photosJson != null) 'photos_json': photosJson,
      if (interestsJson != null) 'interests_json': interestsJson,
      if (completenessScore != null) 'completeness_score': completenessScore,
      if (isVerified != null) 'is_verified': isVerified,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? bio,
      Value<DateTime>? birthdate,
      Value<String>? gender,
      Value<String?>? city,
      Value<String>? photosJson,
      Value<String>? interestsJson,
      Value<int>? completenessScore,
      Value<bool>? isVerified,
      Value<DateTime?>? lastActiveAt,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return CachedProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      photosJson: photosJson ?? this.photosJson,
      interestsJson: interestsJson ?? this.interestsJson,
      completenessScore: completenessScore ?? this.completenessScore,
      isVerified: isVerified ?? this.isVerified,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      cachedAt: cachedAt ?? this.cachedAt,
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
    if (bio.present) {
      map['bio'] = Variable<String>(bio.value);
    }
    if (birthdate.present) {
      map['birthdate'] = Variable<DateTime>(birthdate.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (photosJson.present) {
      map['photos_json'] = Variable<String>(photosJson.value);
    }
    if (interestsJson.present) {
      map['interests_json'] = Variable<String>(interestsJson.value);
    }
    if (completenessScore.present) {
      map['completeness_score'] = Variable<int>(completenessScore.value);
    }
    if (isVerified.present) {
      map['is_verified'] = Variable<bool>(isVerified.value);
    }
    if (lastActiveAt.present) {
      map['last_active_at'] = Variable<DateTime>(lastActiveAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bio: $bio, ')
          ..write('birthdate: $birthdate, ')
          ..write('gender: $gender, ')
          ..write('city: $city, ')
          ..write('photosJson: $photosJson, ')
          ..write('interestsJson: $interestsJson, ')
          ..write('completenessScore: $completenessScore, ')
          ..write('isVerified: $isVerified, ')
          ..write('lastActiveAt: $lastActiveAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMatchesTable extends CachedMatches
    with TableInfo<$CachedMatchesTable, CachedMatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchedUserIdMeta =
      const VerificationMeta('matchedUserId');
  @override
  late final GeneratedColumn<String> matchedUserId = GeneratedColumn<String>(
      'matched_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchedUserNameMeta =
      const VerificationMeta('matchedUserName');
  @override
  late final GeneratedColumn<String> matchedUserName = GeneratedColumn<String>(
      'matched_user_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchedUserPhotoUrlMeta =
      const VerificationMeta('matchedUserPhotoUrl');
  @override
  late final GeneratedColumn<String> matchedUserPhotoUrl =
      GeneratedColumn<String>('matched_user_photo_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _matchedUserBlurhashMeta =
      const VerificationMeta('matchedUserBlurhash');
  @override
  late final GeneratedColumn<String> matchedUserBlurhash =
      GeneratedColumn<String>('matched_user_blurhash', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageTextMeta =
      const VerificationMeta('lastMessageText');
  @override
  late final GeneratedColumn<String> lastMessageText = GeneratedColumn<String>(
      'last_message_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageAtMeta =
      const VerificationMeta('lastMessageAt');
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>('last_message_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        matchedUserId,
        matchedUserName,
        matchedUserPhotoUrl,
        matchedUserBlurhash,
        lastMessageText,
        lastMessageAt,
        unreadCount,
        createdAt,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_matches';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMatch> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('matched_user_id')) {
      context.handle(
          _matchedUserIdMeta,
          matchedUserId.isAcceptableOrUnknown(
              data['matched_user_id']!, _matchedUserIdMeta));
    } else if (isInserting) {
      context.missing(_matchedUserIdMeta);
    }
    if (data.containsKey('matched_user_name')) {
      context.handle(
          _matchedUserNameMeta,
          matchedUserName.isAcceptableOrUnknown(
              data['matched_user_name']!, _matchedUserNameMeta));
    } else if (isInserting) {
      context.missing(_matchedUserNameMeta);
    }
    if (data.containsKey('matched_user_photo_url')) {
      context.handle(
          _matchedUserPhotoUrlMeta,
          matchedUserPhotoUrl.isAcceptableOrUnknown(
              data['matched_user_photo_url']!, _matchedUserPhotoUrlMeta));
    }
    if (data.containsKey('matched_user_blurhash')) {
      context.handle(
          _matchedUserBlurhashMeta,
          matchedUserBlurhash.isAcceptableOrUnknown(
              data['matched_user_blurhash']!, _matchedUserBlurhashMeta));
    }
    if (data.containsKey('last_message_text')) {
      context.handle(
          _lastMessageTextMeta,
          lastMessageText.isAcceptableOrUnknown(
              data['last_message_text']!, _lastMessageTextMeta));
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
          _lastMessageAtMeta,
          lastMessageAt.isAcceptableOrUnknown(
              data['last_message_at']!, _lastMessageAtMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMatch(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      matchedUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}matched_user_id'])!,
      matchedUserName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}matched_user_name'])!,
      matchedUserPhotoUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}matched_user_photo_url']),
      matchedUserBlurhash: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}matched_user_blurhash']),
      lastMessageText: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_message_text']),
      lastMessageAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_message_at']),
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedMatchesTable createAlias(String alias) {
    return $CachedMatchesTable(attachedDatabase, alias);
  }
}

class CachedMatch extends DataClass implements Insertable<CachedMatch> {
  final String id;
  final String matchedUserId;
  final String matchedUserName;
  final String? matchedUserPhotoUrl;
  final String? matchedUserBlurhash;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime cachedAt;
  const CachedMatch(
      {required this.id,
      required this.matchedUserId,
      required this.matchedUserName,
      this.matchedUserPhotoUrl,
      this.matchedUserBlurhash,
      this.lastMessageText,
      this.lastMessageAt,
      required this.unreadCount,
      required this.createdAt,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['matched_user_id'] = Variable<String>(matchedUserId);
    map['matched_user_name'] = Variable<String>(matchedUserName);
    if (!nullToAbsent || matchedUserPhotoUrl != null) {
      map['matched_user_photo_url'] = Variable<String>(matchedUserPhotoUrl);
    }
    if (!nullToAbsent || matchedUserBlurhash != null) {
      map['matched_user_blurhash'] = Variable<String>(matchedUserBlurhash);
    }
    if (!nullToAbsent || lastMessageText != null) {
      map['last_message_text'] = Variable<String>(lastMessageText);
    }
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedMatchesCompanion toCompanion(bool nullToAbsent) {
    return CachedMatchesCompanion(
      id: Value(id),
      matchedUserId: Value(matchedUserId),
      matchedUserName: Value(matchedUserName),
      matchedUserPhotoUrl: matchedUserPhotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedUserPhotoUrl),
      matchedUserBlurhash: matchedUserBlurhash == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedUserBlurhash),
      lastMessageText: lastMessageText == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageText),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      unreadCount: Value(unreadCount),
      createdAt: Value(createdAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedMatch.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMatch(
      id: serializer.fromJson<String>(json['id']),
      matchedUserId: serializer.fromJson<String>(json['matchedUserId']),
      matchedUserName: serializer.fromJson<String>(json['matchedUserName']),
      matchedUserPhotoUrl:
          serializer.fromJson<String?>(json['matchedUserPhotoUrl']),
      matchedUserBlurhash:
          serializer.fromJson<String?>(json['matchedUserBlurhash']),
      lastMessageText: serializer.fromJson<String?>(json['lastMessageText']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchedUserId': serializer.toJson<String>(matchedUserId),
      'matchedUserName': serializer.toJson<String>(matchedUserName),
      'matchedUserPhotoUrl': serializer.toJson<String?>(matchedUserPhotoUrl),
      'matchedUserBlurhash': serializer.toJson<String?>(matchedUserBlurhash),
      'lastMessageText': serializer.toJson<String?>(lastMessageText),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedMatch copyWith(
          {String? id,
          String? matchedUserId,
          String? matchedUserName,
          Value<String?> matchedUserPhotoUrl = const Value.absent(),
          Value<String?> matchedUserBlurhash = const Value.absent(),
          Value<String?> lastMessageText = const Value.absent(),
          Value<DateTime?> lastMessageAt = const Value.absent(),
          int? unreadCount,
          DateTime? createdAt,
          DateTime? cachedAt}) =>
      CachedMatch(
        id: id ?? this.id,
        matchedUserId: matchedUserId ?? this.matchedUserId,
        matchedUserName: matchedUserName ?? this.matchedUserName,
        matchedUserPhotoUrl: matchedUserPhotoUrl.present
            ? matchedUserPhotoUrl.value
            : this.matchedUserPhotoUrl,
        matchedUserBlurhash: matchedUserBlurhash.present
            ? matchedUserBlurhash.value
            : this.matchedUserBlurhash,
        lastMessageText: lastMessageText.present
            ? lastMessageText.value
            : this.lastMessageText,
        lastMessageAt:
            lastMessageAt.present ? lastMessageAt.value : this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        createdAt: createdAt ?? this.createdAt,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedMatch copyWithCompanion(CachedMatchesCompanion data) {
    return CachedMatch(
      id: data.id.present ? data.id.value : this.id,
      matchedUserId: data.matchedUserId.present
          ? data.matchedUserId.value
          : this.matchedUserId,
      matchedUserName: data.matchedUserName.present
          ? data.matchedUserName.value
          : this.matchedUserName,
      matchedUserPhotoUrl: data.matchedUserPhotoUrl.present
          ? data.matchedUserPhotoUrl.value
          : this.matchedUserPhotoUrl,
      matchedUserBlurhash: data.matchedUserBlurhash.present
          ? data.matchedUserBlurhash.value
          : this.matchedUserBlurhash,
      lastMessageText: data.lastMessageText.present
          ? data.lastMessageText.value
          : this.lastMessageText,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMatch(')
          ..write('id: $id, ')
          ..write('matchedUserId: $matchedUserId, ')
          ..write('matchedUserName: $matchedUserName, ')
          ..write('matchedUserPhotoUrl: $matchedUserPhotoUrl, ')
          ..write('matchedUserBlurhash: $matchedUserBlurhash, ')
          ..write('lastMessageText: $lastMessageText, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      matchedUserId,
      matchedUserName,
      matchedUserPhotoUrl,
      matchedUserBlurhash,
      lastMessageText,
      lastMessageAt,
      unreadCount,
      createdAt,
      cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMatch &&
          other.id == this.id &&
          other.matchedUserId == this.matchedUserId &&
          other.matchedUserName == this.matchedUserName &&
          other.matchedUserPhotoUrl == this.matchedUserPhotoUrl &&
          other.matchedUserBlurhash == this.matchedUserBlurhash &&
          other.lastMessageText == this.lastMessageText &&
          other.lastMessageAt == this.lastMessageAt &&
          other.unreadCount == this.unreadCount &&
          other.createdAt == this.createdAt &&
          other.cachedAt == this.cachedAt);
}

class CachedMatchesCompanion extends UpdateCompanion<CachedMatch> {
  final Value<String> id;
  final Value<String> matchedUserId;
  final Value<String> matchedUserName;
  final Value<String?> matchedUserPhotoUrl;
  final Value<String?> matchedUserBlurhash;
  final Value<String?> lastMessageText;
  final Value<DateTime?> lastMessageAt;
  final Value<int> unreadCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedMatchesCompanion({
    this.id = const Value.absent(),
    this.matchedUserId = const Value.absent(),
    this.matchedUserName = const Value.absent(),
    this.matchedUserPhotoUrl = const Value.absent(),
    this.matchedUserBlurhash = const Value.absent(),
    this.lastMessageText = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMatchesCompanion.insert({
    required String id,
    required String matchedUserId,
    required String matchedUserName,
    this.matchedUserPhotoUrl = const Value.absent(),
    this.matchedUserBlurhash = const Value.absent(),
    this.lastMessageText = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        matchedUserId = Value(matchedUserId),
        matchedUserName = Value(matchedUserName),
        createdAt = Value(createdAt),
        cachedAt = Value(cachedAt);
  static Insertable<CachedMatch> custom({
    Expression<String>? id,
    Expression<String>? matchedUserId,
    Expression<String>? matchedUserName,
    Expression<String>? matchedUserPhotoUrl,
    Expression<String>? matchedUserBlurhash,
    Expression<String>? lastMessageText,
    Expression<DateTime>? lastMessageAt,
    Expression<int>? unreadCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchedUserId != null) 'matched_user_id': matchedUserId,
      if (matchedUserName != null) 'matched_user_name': matchedUserName,
      if (matchedUserPhotoUrl != null)
        'matched_user_photo_url': matchedUserPhotoUrl,
      if (matchedUserBlurhash != null)
        'matched_user_blurhash': matchedUserBlurhash,
      if (lastMessageText != null) 'last_message_text': lastMessageText,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (createdAt != null) 'created_at': createdAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMatchesCompanion copyWith(
      {Value<String>? id,
      Value<String>? matchedUserId,
      Value<String>? matchedUserName,
      Value<String?>? matchedUserPhotoUrl,
      Value<String?>? matchedUserBlurhash,
      Value<String?>? lastMessageText,
      Value<DateTime?>? lastMessageAt,
      Value<int>? unreadCount,
      Value<DateTime>? createdAt,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return CachedMatchesCompanion(
      id: id ?? this.id,
      matchedUserId: matchedUserId ?? this.matchedUserId,
      matchedUserName: matchedUserName ?? this.matchedUserName,
      matchedUserPhotoUrl: matchedUserPhotoUrl ?? this.matchedUserPhotoUrl,
      matchedUserBlurhash: matchedUserBlurhash ?? this.matchedUserBlurhash,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchedUserId.present) {
      map['matched_user_id'] = Variable<String>(matchedUserId.value);
    }
    if (matchedUserName.present) {
      map['matched_user_name'] = Variable<String>(matchedUserName.value);
    }
    if (matchedUserPhotoUrl.present) {
      map['matched_user_photo_url'] =
          Variable<String>(matchedUserPhotoUrl.value);
    }
    if (matchedUserBlurhash.present) {
      map['matched_user_blurhash'] =
          Variable<String>(matchedUserBlurhash.value);
    }
    if (lastMessageText.present) {
      map['last_message_text'] = Variable<String>(lastMessageText.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMatchesCompanion(')
          ..write('id: $id, ')
          ..write('matchedUserId: $matchedUserId, ')
          ..write('matchedUserName: $matchedUserName, ')
          ..write('matchedUserPhotoUrl: $matchedUserPhotoUrl, ')
          ..write('matchedUserBlurhash: $matchedUserBlurhash, ')
          ..write('lastMessageText: $lastMessageText, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMessagesTable extends CachedMessages
    with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaUrlMeta =
      const VerificationMeta('mediaUrl');
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
      'media_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaDurationMeta =
      const VerificationMeta('mediaDuration');
  @override
  late final GeneratedColumn<int> mediaDuration = GeneratedColumn<int>(
      'media_duration', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        matchId,
        senderId,
        type,
        content,
        mediaUrl,
        mediaDuration,
        status,
        createdAt,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('media_url')) {
      context.handle(_mediaUrlMeta,
          mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta));
    }
    if (data.containsKey('media_duration')) {
      context.handle(
          _mediaDurationMeta,
          mediaDuration.isAcceptableOrUnknown(
              data['media_duration']!, _mediaDurationMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      mediaUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_url']),
      mediaDuration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_duration']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String id;
  final String matchId;
  final String senderId;
  final String type;
  final String content;
  final String? mediaUrl;
  final int? mediaDuration;
  final String status;
  final DateTime createdAt;
  final DateTime cachedAt;
  const CachedMessage(
      {required this.id,
      required this.matchId,
      required this.senderId,
      required this.type,
      required this.content,
      this.mediaUrl,
      this.mediaDuration,
      required this.status,
      required this.createdAt,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['sender_id'] = Variable<String>(senderId);
    map['type'] = Variable<String>(type);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || mediaDuration != null) {
      map['media_duration'] = Variable<int>(mediaDuration);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      id: Value(id),
      matchId: Value(matchId),
      senderId: Value(senderId),
      type: Value(type),
      content: Value(content),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      mediaDuration: mediaDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaDuration),
      status: Value(status),
      createdAt: Value(createdAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      type: serializer.fromJson<String>(json['type']),
      content: serializer.fromJson<String>(json['content']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      mediaDuration: serializer.fromJson<int?>(json['mediaDuration']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'senderId': serializer.toJson<String>(senderId),
      'type': serializer.toJson<String>(type),
      'content': serializer.toJson<String>(content),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'mediaDuration': serializer.toJson<int?>(mediaDuration),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedMessage copyWith(
          {String? id,
          String? matchId,
          String? senderId,
          String? type,
          String? content,
          Value<String?> mediaUrl = const Value.absent(),
          Value<int?> mediaDuration = const Value.absent(),
          String? status,
          DateTime? createdAt,
          DateTime? cachedAt}) =>
      CachedMessage(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        senderId: senderId ?? this.senderId,
        type: type ?? this.type,
        content: content ?? this.content,
        mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
        mediaDuration:
            mediaDuration.present ? mediaDuration.value : this.mediaDuration,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      mediaDuration: data.mediaDuration.present
          ? data.mediaDuration.value
          : this.mediaDuration,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaDuration: $mediaDuration, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, senderId, type, content,
      mediaUrl, mediaDuration, status, createdAt, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.senderId == this.senderId &&
          other.type == this.type &&
          other.content == this.content &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaDuration == this.mediaDuration &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.cachedAt == this.cachedAt);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> senderId;
  final Value<String> type;
  final Value<String> content;
  final Value<String?> mediaUrl;
  final Value<int?> mediaDuration;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaDuration = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String id,
    required String matchId,
    required String senderId,
    required String type,
    required String content,
    this.mediaUrl = const Value.absent(),
    this.mediaDuration = const Value.absent(),
    required String status,
    required DateTime createdAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        matchId = Value(matchId),
        senderId = Value(senderId),
        type = Value(type),
        content = Value(content),
        status = Value(status),
        createdAt = Value(createdAt),
        cachedAt = Value(cachedAt);
  static Insertable<CachedMessage> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? senderId,
    Expression<String>? type,
    Expression<String>? content,
    Expression<String>? mediaUrl,
    Expression<int>? mediaDuration,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (senderId != null) 'sender_id': senderId,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaDuration != null) 'media_duration': mediaDuration,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? matchId,
      Value<String>? senderId,
      Value<String>? type,
      Value<String>? content,
      Value<String?>? mediaUrl,
      Value<int?>? mediaDuration,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return CachedMessagesCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (mediaDuration.present) {
      map['media_duration'] = Variable<int>(mediaDuration.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaDuration: $mediaDuration, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SwipeOutboxTable extends SwipeOutbox
    with TableInfo<$SwipeOutboxTable, SwipeOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SwipeOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetUserIdMeta =
      const VerificationMeta('targetUserId');
  @override
  late final GeneratedColumn<String> targetUserId = GeneratedColumn<String>(
      'target_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, targetUserId, direction, createdAt, status, retryCount, lastError];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'swipe_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<SwipeOutboxEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_user_id')) {
      context.handle(
          _targetUserIdMeta,
          targetUserId.isAcceptableOrUnknown(
              data['target_user_id']!, _targetUserIdMeta));
    } else if (isInserting) {
      context.missing(_targetUserIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SwipeOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SwipeOutboxEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      targetUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_user_id'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $SwipeOutboxTable createAlias(String alias) {
    return $SwipeOutboxTable(attachedDatabase, alias);
  }
}

class SwipeOutboxEntry extends DataClass
    implements Insertable<SwipeOutboxEntry> {
  final String id;
  final String targetUserId;
  final String direction;
  final DateTime createdAt;
  final String status;
  final int retryCount;
  final String? lastError;
  const SwipeOutboxEntry(
      {required this.id,
      required this.targetUserId,
      required this.direction,
      required this.createdAt,
      required this.status,
      required this.retryCount,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['target_user_id'] = Variable<String>(targetUserId);
    map['direction'] = Variable<String>(direction);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SwipeOutboxCompanion toCompanion(bool nullToAbsent) {
    return SwipeOutboxCompanion(
      id: Value(id),
      targetUserId: Value(targetUserId),
      direction: Value(direction),
      createdAt: Value(createdAt),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SwipeOutboxEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SwipeOutboxEntry(
      id: serializer.fromJson<String>(json['id']),
      targetUserId: serializer.fromJson<String>(json['targetUserId']),
      direction: serializer.fromJson<String>(json['direction']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetUserId': serializer.toJson<String>(targetUserId),
      'direction': serializer.toJson<String>(direction),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SwipeOutboxEntry copyWith(
          {String? id,
          String? targetUserId,
          String? direction,
          DateTime? createdAt,
          String? status,
          int? retryCount,
          Value<String?> lastError = const Value.absent()}) =>
      SwipeOutboxEntry(
        id: id ?? this.id,
        targetUserId: targetUserId ?? this.targetUserId,
        direction: direction ?? this.direction,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  SwipeOutboxEntry copyWithCompanion(SwipeOutboxCompanion data) {
    return SwipeOutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      targetUserId: data.targetUserId.present
          ? data.targetUserId.value
          : this.targetUserId,
      direction: data.direction.present ? data.direction.value : this.direction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SwipeOutboxEntry(')
          ..write('id: $id, ')
          ..write('targetUserId: $targetUserId, ')
          ..write('direction: $direction, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, targetUserId, direction, createdAt, status, retryCount, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SwipeOutboxEntry &&
          other.id == this.id &&
          other.targetUserId == this.targetUserId &&
          other.direction == this.direction &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class SwipeOutboxCompanion extends UpdateCompanion<SwipeOutboxEntry> {
  final Value<String> id;
  final Value<String> targetUserId;
  final Value<String> direction;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SwipeOutboxCompanion({
    this.id = const Value.absent(),
    this.targetUserId = const Value.absent(),
    this.direction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SwipeOutboxCompanion.insert({
    required String id,
    required String targetUserId,
    required String direction,
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        targetUserId = Value(targetUserId),
        direction = Value(direction),
        createdAt = Value(createdAt);
  static Insertable<SwipeOutboxEntry> custom({
    Expression<String>? id,
    Expression<String>? targetUserId,
    Expression<String>? direction,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetUserId != null) 'target_user_id': targetUserId,
      if (direction != null) 'direction': direction,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SwipeOutboxCompanion copyWith(
      {Value<String>? id,
      Value<String>? targetUserId,
      Value<String>? direction,
      Value<DateTime>? createdAt,
      Value<String>? status,
      Value<int>? retryCount,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return SwipeOutboxCompanion(
      id: id ?? this.id,
      targetUserId: targetUserId ?? this.targetUserId,
      direction: direction ?? this.direction,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (targetUserId.present) {
      map['target_user_id'] = Variable<String>(targetUserId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SwipeOutboxCompanion(')
          ..write('id: $id, ')
          ..write('targetUserId: $targetUserId, ')
          ..write('direction: $direction, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedProfilesTable cachedProfiles = $CachedProfilesTable(this);
  late final $CachedMatchesTable cachedMatches = $CachedMatchesTable(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  late final $SwipeOutboxTable swipeOutbox = $SwipeOutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [cachedProfiles, cachedMatches, cachedMessages, swipeOutbox];
}

typedef $$CachedProfilesTableCreateCompanionBuilder = CachedProfilesCompanion
    Function({
  required String id,
  required String name,
  Value<String?> bio,
  required DateTime birthdate,
  required String gender,
  Value<String?> city,
  required String photosJson,
  required String interestsJson,
  Value<int> completenessScore,
  Value<bool> isVerified,
  Value<DateTime?> lastActiveAt,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$CachedProfilesTableUpdateCompanionBuilder = CachedProfilesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String?> bio,
  Value<DateTime> birthdate,
  Value<String> gender,
  Value<String?> city,
  Value<String> photosJson,
  Value<String> interestsJson,
  Value<int> completenessScore,
  Value<bool> isVerified,
  Value<DateTime?> lastActiveAt,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$CachedProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProfilesTable> {
  $$CachedProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bio => $composableBuilder(
      column: $table.bio, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get birthdate => $composableBuilder(
      column: $table.birthdate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photosJson => $composableBuilder(
      column: $table.photosJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get interestsJson => $composableBuilder(
      column: $table.interestsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completenessScore => $composableBuilder(
      column: $table.completenessScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProfilesTable> {
  $$CachedProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bio => $composableBuilder(
      column: $table.bio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get birthdate => $composableBuilder(
      column: $table.birthdate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photosJson => $composableBuilder(
      column: $table.photosJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get interestsJson => $composableBuilder(
      column: $table.interestsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completenessScore => $composableBuilder(
      column: $table.completenessScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProfilesTable> {
  $$CachedProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get bio =>
      $composableBuilder(column: $table.bio, builder: (column) => column);

  GeneratedColumn<DateTime> get birthdate =>
      $composableBuilder(column: $table.birthdate, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get photosJson => $composableBuilder(
      column: $table.photosJson, builder: (column) => column);

  GeneratedColumn<String> get interestsJson => $composableBuilder(
      column: $table.interestsJson, builder: (column) => column);

  GeneratedColumn<int> get completenessScore => $composableBuilder(
      column: $table.completenessScore, builder: (column) => column);

  GeneratedColumn<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActiveAt => $composableBuilder(
      column: $table.lastActiveAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedProfilesTable,
    CachedProfile,
    $$CachedProfilesTableFilterComposer,
    $$CachedProfilesTableOrderingComposer,
    $$CachedProfilesTableAnnotationComposer,
    $$CachedProfilesTableCreateCompanionBuilder,
    $$CachedProfilesTableUpdateCompanionBuilder,
    (
      CachedProfile,
      BaseReferences<_$AppDatabase, $CachedProfilesTable, CachedProfile>
    ),
    CachedProfile,
    PrefetchHooks Function()> {
  $$CachedProfilesTableTableManager(
      _$AppDatabase db, $CachedProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> bio = const Value.absent(),
            Value<DateTime> birthdate = const Value.absent(),
            Value<String> gender = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String> photosJson = const Value.absent(),
            Value<String> interestsJson = const Value.absent(),
            Value<int> completenessScore = const Value.absent(),
            Value<bool> isVerified = const Value.absent(),
            Value<DateTime?> lastActiveAt = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProfilesCompanion(
            id: id,
            name: name,
            bio: bio,
            birthdate: birthdate,
            gender: gender,
            city: city,
            photosJson: photosJson,
            interestsJson: interestsJson,
            completenessScore: completenessScore,
            isVerified: isVerified,
            lastActiveAt: lastActiveAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> bio = const Value.absent(),
            required DateTime birthdate,
            required String gender,
            Value<String?> city = const Value.absent(),
            required String photosJson,
            required String interestsJson,
            Value<int> completenessScore = const Value.absent(),
            Value<bool> isVerified = const Value.absent(),
            Value<DateTime?> lastActiveAt = const Value.absent(),
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProfilesCompanion.insert(
            id: id,
            name: name,
            bio: bio,
            birthdate: birthdate,
            gender: gender,
            city: city,
            photosJson: photosJson,
            interestsJson: interestsJson,
            completenessScore: completenessScore,
            isVerified: isVerified,
            lastActiveAt: lastActiveAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedProfilesTable,
    CachedProfile,
    $$CachedProfilesTableFilterComposer,
    $$CachedProfilesTableOrderingComposer,
    $$CachedProfilesTableAnnotationComposer,
    $$CachedProfilesTableCreateCompanionBuilder,
    $$CachedProfilesTableUpdateCompanionBuilder,
    (
      CachedProfile,
      BaseReferences<_$AppDatabase, $CachedProfilesTable, CachedProfile>
    ),
    CachedProfile,
    PrefetchHooks Function()>;
typedef $$CachedMatchesTableCreateCompanionBuilder = CachedMatchesCompanion
    Function({
  required String id,
  required String matchedUserId,
  required String matchedUserName,
  Value<String?> matchedUserPhotoUrl,
  Value<String?> matchedUserBlurhash,
  Value<String?> lastMessageText,
  Value<DateTime?> lastMessageAt,
  Value<int> unreadCount,
  required DateTime createdAt,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$CachedMatchesTableUpdateCompanionBuilder = CachedMatchesCompanion
    Function({
  Value<String> id,
  Value<String> matchedUserId,
  Value<String> matchedUserName,
  Value<String?> matchedUserPhotoUrl,
  Value<String?> matchedUserBlurhash,
  Value<String?> lastMessageText,
  Value<DateTime?> lastMessageAt,
  Value<int> unreadCount,
  Value<DateTime> createdAt,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$CachedMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMatchesTable> {
  $$CachedMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchedUserId => $composableBuilder(
      column: $table.matchedUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchedUserName => $composableBuilder(
      column: $table.matchedUserName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchedUserPhotoUrl => $composableBuilder(
      column: $table.matchedUserPhotoUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchedUserBlurhash => $composableBuilder(
      column: $table.matchedUserBlurhash,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessageText => $composableBuilder(
      column: $table.lastMessageText,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMatchesTable> {
  $$CachedMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchedUserId => $composableBuilder(
      column: $table.matchedUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchedUserName => $composableBuilder(
      column: $table.matchedUserName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchedUserPhotoUrl => $composableBuilder(
      column: $table.matchedUserPhotoUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchedUserBlurhash => $composableBuilder(
      column: $table.matchedUserBlurhash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessageText => $composableBuilder(
      column: $table.lastMessageText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMatchesTable> {
  $$CachedMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchedUserId => $composableBuilder(
      column: $table.matchedUserId, builder: (column) => column);

  GeneratedColumn<String> get matchedUserName => $composableBuilder(
      column: $table.matchedUserName, builder: (column) => column);

  GeneratedColumn<String> get matchedUserPhotoUrl => $composableBuilder(
      column: $table.matchedUserPhotoUrl, builder: (column) => column);

  GeneratedColumn<String> get matchedUserBlurhash => $composableBuilder(
      column: $table.matchedUserBlurhash, builder: (column) => column);

  GeneratedColumn<String> get lastMessageText => $composableBuilder(
      column: $table.lastMessageText, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedMatchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedMatchesTable,
    CachedMatch,
    $$CachedMatchesTableFilterComposer,
    $$CachedMatchesTableOrderingComposer,
    $$CachedMatchesTableAnnotationComposer,
    $$CachedMatchesTableCreateCompanionBuilder,
    $$CachedMatchesTableUpdateCompanionBuilder,
    (
      CachedMatch,
      BaseReferences<_$AppDatabase, $CachedMatchesTable, CachedMatch>
    ),
    CachedMatch,
    PrefetchHooks Function()> {
  $$CachedMatchesTableTableManager(_$AppDatabase db, $CachedMatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> matchedUserId = const Value.absent(),
            Value<String> matchedUserName = const Value.absent(),
            Value<String?> matchedUserPhotoUrl = const Value.absent(),
            Value<String?> matchedUserBlurhash = const Value.absent(),
            Value<String?> lastMessageText = const Value.absent(),
            Value<DateTime?> lastMessageAt = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMatchesCompanion(
            id: id,
            matchedUserId: matchedUserId,
            matchedUserName: matchedUserName,
            matchedUserPhotoUrl: matchedUserPhotoUrl,
            matchedUserBlurhash: matchedUserBlurhash,
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            createdAt: createdAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String matchedUserId,
            required String matchedUserName,
            Value<String?> matchedUserPhotoUrl = const Value.absent(),
            Value<String?> matchedUserBlurhash = const Value.absent(),
            Value<String?> lastMessageText = const Value.absent(),
            Value<DateTime?> lastMessageAt = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            required DateTime createdAt,
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMatchesCompanion.insert(
            id: id,
            matchedUserId: matchedUserId,
            matchedUserName: matchedUserName,
            matchedUserPhotoUrl: matchedUserPhotoUrl,
            matchedUserBlurhash: matchedUserBlurhash,
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            createdAt: createdAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedMatchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedMatchesTable,
    CachedMatch,
    $$CachedMatchesTableFilterComposer,
    $$CachedMatchesTableOrderingComposer,
    $$CachedMatchesTableAnnotationComposer,
    $$CachedMatchesTableCreateCompanionBuilder,
    $$CachedMatchesTableUpdateCompanionBuilder,
    (
      CachedMatch,
      BaseReferences<_$AppDatabase, $CachedMatchesTable, CachedMatch>
    ),
    CachedMatch,
    PrefetchHooks Function()>;
typedef $$CachedMessagesTableCreateCompanionBuilder = CachedMessagesCompanion
    Function({
  required String id,
  required String matchId,
  required String senderId,
  required String type,
  required String content,
  Value<String?> mediaUrl,
  Value<int?> mediaDuration,
  required String status,
  required DateTime createdAt,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$CachedMessagesTableUpdateCompanionBuilder = CachedMessagesCompanion
    Function({
  Value<String> id,
  Value<String> matchId,
  Value<String> senderId,
  Value<String> type,
  Value<String> content,
  Value<String?> mediaUrl,
  Value<int?> mediaDuration,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$CachedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaUrl => $composableBuilder(
      column: $table.mediaUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mediaDuration => $composableBuilder(
      column: $table.mediaDuration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
      column: $table.mediaUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mediaDuration => $composableBuilder(
      column: $table.mediaDuration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<int> get mediaDuration => $composableBuilder(
      column: $table.mediaDuration, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableAnnotationComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder,
    (
      CachedMessage,
      BaseReferences<_$AppDatabase, $CachedMessagesTable, CachedMessage>
    ),
    CachedMessage,
    PrefetchHooks Function()> {
  $$CachedMessagesTableTableManager(
      _$AppDatabase db, $CachedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> matchId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> mediaUrl = const Value.absent(),
            Value<int?> mediaDuration = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion(
            id: id,
            matchId: matchId,
            senderId: senderId,
            type: type,
            content: content,
            mediaUrl: mediaUrl,
            mediaDuration: mediaDuration,
            status: status,
            createdAt: createdAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String matchId,
            required String senderId,
            required String type,
            required String content,
            Value<String?> mediaUrl = const Value.absent(),
            Value<int?> mediaDuration = const Value.absent(),
            required String status,
            required DateTime createdAt,
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion.insert(
            id: id,
            matchId: matchId,
            senderId: senderId,
            type: type,
            content: content,
            mediaUrl: mediaUrl,
            mediaDuration: mediaDuration,
            status: status,
            createdAt: createdAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableAnnotationComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder,
    (
      CachedMessage,
      BaseReferences<_$AppDatabase, $CachedMessagesTable, CachedMessage>
    ),
    CachedMessage,
    PrefetchHooks Function()>;
typedef $$SwipeOutboxTableCreateCompanionBuilder = SwipeOutboxCompanion
    Function({
  required String id,
  required String targetUserId,
  required String direction,
  required DateTime createdAt,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$SwipeOutboxTableUpdateCompanionBuilder = SwipeOutboxCompanion
    Function({
  Value<String> id,
  Value<String> targetUserId,
  Value<String> direction,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$SwipeOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SwipeOutboxTable> {
  $$SwipeOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetUserId => $composableBuilder(
      column: $table.targetUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$SwipeOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SwipeOutboxTable> {
  $$SwipeOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetUserId => $composableBuilder(
      column: $table.targetUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$SwipeOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SwipeOutboxTable> {
  $$SwipeOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetUserId => $composableBuilder(
      column: $table.targetUserId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SwipeOutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SwipeOutboxTable,
    SwipeOutboxEntry,
    $$SwipeOutboxTableFilterComposer,
    $$SwipeOutboxTableOrderingComposer,
    $$SwipeOutboxTableAnnotationComposer,
    $$SwipeOutboxTableCreateCompanionBuilder,
    $$SwipeOutboxTableUpdateCompanionBuilder,
    (
      SwipeOutboxEntry,
      BaseReferences<_$AppDatabase, $SwipeOutboxTable, SwipeOutboxEntry>
    ),
    SwipeOutboxEntry,
    PrefetchHooks Function()> {
  $$SwipeOutboxTableTableManager(_$AppDatabase db, $SwipeOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SwipeOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SwipeOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SwipeOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> targetUserId = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SwipeOutboxCompanion(
            id: id,
            targetUserId: targetUserId,
            direction: direction,
            createdAt: createdAt,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String targetUserId,
            required String direction,
            required DateTime createdAt,
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SwipeOutboxCompanion.insert(
            id: id,
            targetUserId: targetUserId,
            direction: direction,
            createdAt: createdAt,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SwipeOutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SwipeOutboxTable,
    SwipeOutboxEntry,
    $$SwipeOutboxTableFilterComposer,
    $$SwipeOutboxTableOrderingComposer,
    $$SwipeOutboxTableAnnotationComposer,
    $$SwipeOutboxTableCreateCompanionBuilder,
    $$SwipeOutboxTableUpdateCompanionBuilder,
    (
      SwipeOutboxEntry,
      BaseReferences<_$AppDatabase, $SwipeOutboxTable, SwipeOutboxEntry>
    ),
    SwipeOutboxEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedProfilesTableTableManager get cachedProfiles =>
      $$CachedProfilesTableTableManager(_db, _db.cachedProfiles);
  $$CachedMatchesTableTableManager get cachedMatches =>
      $$CachedMatchesTableTableManager(_db, _db.cachedMatches);
  $$CachedMessagesTableTableManager get cachedMessages =>
      $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
  $$SwipeOutboxTableTableManager get swipeOutbox =>
      $$SwipeOutboxTableTableManager(_db, _db.swipeOutbox);
}
