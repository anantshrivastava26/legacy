class User {
  final String id;
  final String email;
  final String displayName;

  User({required this.id, required this.email, required this.displayName});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['email'],
        displayName: json['displayName'],
      );
}

class FamilySummary {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String myRole;
  final int personCount;
  final int memberCount;
  final String? inviteCode;

  FamilySummary({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.myRole,
    required this.personCount,
    required this.memberCount,
    this.inviteCode,
  });

  factory FamilySummary.fromJson(Map<String, dynamic> json) => FamilySummary(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        photoUrl: json['photoUrl'],
        myRole: json['myRole'] ?? 'CONTRIBUTOR',
        personCount: json['personCount'] ?? 0,
        memberCount: json['memberCount'] ?? 0,
        inviteCode: json['inviteCode'],
      );

  bool get canEdit => myRole != 'VIEWER';
  bool get isAdmin => myRole == 'ADMIN' || myRole == 'OWNER';
}

class Person {
  final String id;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? nickname;
  final String gender;
  final DateTime? dateOfBirth;
  final DateTime? dateOfDeath;
  final bool isLiving;
  final String? profilePhotoUrl;
  final String? birthPlace;
  final String? currentLocation;
  final String? occupation;
  final String? education;
  final String? biography;
  final String? phone;
  final String? email;
  final String? religion;
  final String? bloodGroup;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.nickname,
    required this.gender,
    this.dateOfBirth,
    this.dateOfDeath,
    required this.isLiving,
    this.profilePhotoUrl,
    this.birthPlace,
    this.currentLocation,
    this.occupation,
    this.education,
    this.biography,
    this.phone,
    this.email,
    this.religion,
    this.bloodGroup,
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'],
        firstName: json['firstName'],
        lastName: json['lastName'],
        middleName: json['middleName'],
        nickname: json['nickname'],
        gender: json['gender'] ?? 'UNKNOWN',
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'])
            : null,
        dateOfDeath: json['dateOfDeath'] != null
            ? DateTime.tryParse(json['dateOfDeath'])
            : null,
        isLiving: json['isLiving'] ?? true,
        profilePhotoUrl: json['profilePhotoUrl'],
        birthPlace: json['birthPlace'],
        currentLocation: json['currentLocation'],
        occupation: json['occupation'],
        education: json['education'],
        biography: json['biography'],
        phone: json['phone'],
        email: json['email'],
        religion: json['religion'],
        bloodGroup: json['bloodGroup'],
      );

  String get fullName => '$firstName $lastName';

  String get lifeSpan {
    final born = dateOfBirth?.year.toString() ?? '?';
    if (isLiving) return 'Born $born';
    final died = dateOfDeath?.year.toString() ?? '?';
    return '$born – $died';
  }
}

class RelatedPerson {
  final String relationshipId;
  final String type;
  final Person person;

  RelatedPerson(
      {required this.relationshipId, required this.type, required this.person});

  factory RelatedPerson.fromJson(Map<String, dynamic> json) => RelatedPerson(
        relationshipId: json['relationshipId'],
        type: json['type'],
        person: Person.fromJson(json['person']),
      );
}

class PersonDetail {
  final Person person;
  final List<RelatedPerson> parents;
  final List<RelatedPerson> children;
  final List<RelatedPerson> spouses;
  final List<Person> siblings;

  PersonDetail({
    required this.person,
    required this.parents,
    required this.children,
    required this.spouses,
    required this.siblings,
  });

  factory PersonDetail.fromJson(Map<String, dynamic> json) => PersonDetail(
        person: Person.fromJson(json['person']),
        parents: (json['parents'] as List)
            .map((e) => RelatedPerson.fromJson(e))
            .toList(),
        children: (json['children'] as List)
            .map((e) => RelatedPerson.fromJson(e))
            .toList(),
        spouses: (json['spouses'] as List)
            .map((e) => RelatedPerson.fromJson(e))
            .toList(),
        siblings: (json['siblings'] as List)
            .map((e) => Person.fromJson({
                  ...e,
                  'gender': 'UNKNOWN',
                  'isLiving': true,
                }))
            .toList(),
      );
}

class TreeNode {
  final String id;
  final String firstName;
  final String lastName;
  final String? nickname;
  final String gender;
  final bool isLiving;
  final int generation;
  final DateTime? dateOfBirth;

  TreeNode({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickname,
    required this.gender,
    required this.isLiving,
    required this.generation,
    this.dateOfBirth,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) => TreeNode(
        id: json['id'],
        firstName: json['firstName'],
        lastName: json['lastName'],
        nickname: json['nickname'],
        gender: json['gender'] ?? 'UNKNOWN',
        isLiving: json['isLiving'] ?? true,
        generation: json['generation'] ?? 0,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'])
            : null,
      );

  String get fullName => '$firstName $lastName';
}

class TreeEdge {
  final String id;
  final String type;
  final String fromPersonId;
  final String toPersonId;

  TreeEdge({
    required this.id,
    required this.type,
    required this.fromPersonId,
    required this.toPersonId,
  });

  factory TreeEdge.fromJson(Map<String, dynamic> json) => TreeEdge(
        id: json['id'],
        type: json['type'],
        fromPersonId: json['fromPersonId'],
        toPersonId: json['toPersonId'],
      );
}

class ActivityItem {
  final String id;
  final String action;
  final String summary;
  final String? by;
  final DateTime at;

  ActivityItem({
    required this.id,
    required this.action,
    required this.summary,
    this.by,
    required this.at,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id'],
        action: json['action'],
        summary: json['summary'],
        by: json['by'],
        at: DateTime.parse(json['at']),
      );
}

class FamilyMemberItem {
  final String userId;
  final String displayName;
  final String email;
  final String role;

  FamilyMemberItem({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
  });

  factory FamilyMemberItem.fromJson(Map<String, dynamic> json) =>
      FamilyMemberItem(
        userId: json['userId'],
        displayName: json['displayName'],
        email: json['email'],
        role: json['role'],
      );
}
