int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int _int(Object? value) => _intOrNull(value) ?? 0;

class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? division;
  final bool emailVerified;
  final String? identityStatus;
  final String? identityKind;
  final String? identityNote;
  final TutorProfile? tutorProfile;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.division,
    this.emailVerified = true,
    this.identityStatus,
    this.identityKind,
    this.identityNote,
    this.tutorProfile,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      phone: json['phone'] as String?,
      division: json['division'] as String?,
      emailVerified: json['email_verified_at'] != null,
      identityStatus: json['identity_document'] is Map ? json['identity_document']['status'] as String? : null,
      identityKind: json['identity_document'] is Map ? json['identity_document']['kind'] as String? : null,
      identityNote: json['identity_document'] is Map ? json['identity_document']['note'] as String? : null,
      tutorProfile: json['tutor_profile'] is Map<String, dynamic>
          ? TutorProfile.fromJson(json['tutor_profile'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TutorProfile {
  final int id;
  final int userId;
  final String? bio;
  final String? qualifications;
  final String? experience;
  final int satisfactionPoints;
  final String status;
  final List<String> availableSlots;
  final AppUser? user;
  final List<Subject> subjects;

  const TutorProfile({
    required this.id,
    required this.userId,
    this.bio,
    this.qualifications,
    this.experience,
    this.satisfactionPoints = 0,
    this.status = 'pending',
    this.availableSlots = const [],
    this.user,
    this.subjects = const [],
  });

  factory TutorProfile.fromJson(Map<String, dynamic> json) {
    final slots = json['available_slots'];
    return TutorProfile(
      id: _int(json['id']),
      userId: _intOrNull(json['user_id']) ?? 0,
      bio: json['bio'] as String?,
      qualifications: json['qualifications'] as String?,
      experience: json['experience'] as String?,
      satisfactionPoints: _intOrNull(json['satisfaction_points']) ?? 0,
      status: json['status'] as String? ?? 'pending',
      availableSlots: slots is List ? slots.map((e) => e.toString()).toList() : const [],
      user: json['user'] is Map<String, dynamic>
          ? AppUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      subjects: (json['subjects'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Subject.fromJson)
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) => other is TutorProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  String get displayName => user?.name ?? 'Tutor #$id';
  String get subjectLabel => subjects.map((s) => s.name).join(' · ');
}

extension AppUserCopy on AppUser {
  bool get isLaw => division == 'law';

  String get roleLabel {
    switch (role) {
      case 'student':
        return 'Student';
      case 'tutor':
        return 'Tutor';
      case 'lecturer':
        return 'Lecturer';
      case 'client':
        return 'Client';
      case 'lawyer':
        return 'Lawyer';
      case 'counsel':
        return 'Legal counsel';
      default:
        return role;
    }
  }
}

class Subject {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final String? color;

  const Subject({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.color,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class LearningTrack {
  final int id;
  final String name;
  final String slug;
  final String kind;
  final String? description;

  const LearningTrack({
    required this.id,
    required this.name,
    required this.slug,
    required this.kind,
    this.description,
  });

  bool get isProgramme => kind == 'programme';

  factory LearningTrack.fromJson(Map<String, dynamic> json) {
    return LearningTrack(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      kind: json['kind'] as String? ?? 'subjects',
      description: json['description'] as String?,
    );
  }
}

class PackageModel {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int weeklyHours;

  const PackageModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.weeklyHours,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: double.tryParse('${json['price']}') ?? 0,
      weeklyHours: _intOrNull(json['weekly_hours']) ?? 2,
    );
  }
}

class LessonModel {
  final int id;
  final String title;
  final String status;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final int trackedMinutes;
  final String? meetingRoom;
  final AppUser? student;
  final AppUser? tutor;

  const LessonModel({
    required this.id,
    required this.title,
    required this.status,
    this.scheduledAt,
    this.durationMinutes = 120,
    this.trackedMinutes = 0,
    this.meetingRoom,
    this.student,
    this.tutor,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? 'Lesson',
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse('${json['scheduled_at']}') : null,
      durationMinutes: _intOrNull(json['duration_minutes']) ?? 120,
      trackedMinutes: _intOrNull(json['tracked_minutes']) ?? 0,
      meetingRoom: json['meeting_room'] as String?,
      student: json['student'] is Map<String, dynamic>
          ? AppUser.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      tutor: json['tutor'] is Map<String, dynamic>
          ? AppUser.fromJson(json['tutor'] as Map<String, dynamic>)
          : null,
    );
  }
}

class QuestionReply {
  final int id;
  final String type;
  final String? content;
  final String? attachmentUrl;
  final String? attachmentKind;
  final DateTime? createdAt;
  final AppUser? tutor;

  const QuestionReply({
    required this.id,
    required this.type,
    this.content,
    this.attachmentUrl,
    this.attachmentKind,
    this.createdAt,
    this.tutor,
  });

  factory QuestionReply.fromJson(Map<String, dynamic> json) {
    return QuestionReply(
      id: _int(json['id']),
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentKind: json['attachment_kind'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse('${json['created_at']}') : null,
      tutor: json['tutor'] is Map<String, dynamic> ? AppUser.fromJson(json['tutor'] as Map<String, dynamic>) : null,
    );
  }
}

class QuestionModel {
  final int id;
  final String body;
  final String status;
  final int? studentId;
  final int? tutorId;
  final String? attachmentPath;
  final String? attachmentUrl;
  final String? attachmentKind;
  final DateTime? createdAt;
  final Subject? subject;
  final AppUser? student;
  final AppUser? tutor;
  final List<QuestionReply> replies;

  const QuestionModel({
    required this.id,
    required this.body,
    required this.status,
    this.studentId,
    this.tutorId,
    this.attachmentPath,
    this.attachmentUrl,
    this.attachmentKind,
    this.createdAt,
    this.subject,
    this.student,
    this.tutor,
    this.replies = const [],
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: _int(json['id']),
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      studentId: _intOrNull(json['student_id']),
      tutorId: _intOrNull(json['tutor_id']),
      attachmentPath: json['attachment_path'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentKind: json['attachment_kind'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse('${json['created_at']}') : null,
      subject: json['subject'] is Map<String, dynamic>
          ? Subject.fromJson(json['subject'] as Map<String, dynamic>)
          : null,
      student: json['student'] is Map<String, dynamic>
          ? AppUser.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      tutor: json['tutor'] is Map<String, dynamic>
          ? AppUser.fromJson(json['tutor'] as Map<String, dynamic>)
          : null,
      replies: (json['replies'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(QuestionReply.fromJson)
              .toList() ??
          const [],
    );
  }
}

class PaymentModel {
  final int id;
  final double amount;
  final String status;
  final String method;
  final String? slipPath;
  final AppUser? student;
  final Map<String, dynamic>? subscription;

  const PaymentModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.method,
    this.slipPath,
    this.student,
    this.subscription,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: _int(json['id']),
      amount: double.tryParse('${json['amount']}') ?? 0,
      status: json['status'] as String? ?? 'pending',
      method: json['method'] as String? ?? 'bank_transfer',
      slipPath: json['slip_path'] as String?,
      student: json['student'] is Map<String, dynamic>
          ? AppUser.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      subscription: json['subscription'] is Map<String, dynamic>
          ? json['subscription'] as Map<String, dynamic>
          : null,
    );
  }
}

class CommissionModel {
  final int id;
  final double amount;
  final double packageAmount;
  final double rate;
  final String month;
  final String status;

  const CommissionModel({
    required this.id,
    required this.amount,
    required this.packageAmount,
    required this.rate,
    required this.month,
    required this.status,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: _int(json['id']),
      amount: double.tryParse('${json['amount']}') ?? 0,
      packageAmount: double.tryParse('${json['package_amount']}') ?? 0,
      rate: double.tryParse('${json['rate']}') ?? 0,
      month: json['month'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class AdminStats {
  final int students;
  final int tutors;
  final int pendingTutors;
  final int pendingPayments;
  final int activeSubscriptions;
  final int openQuestions;

  const AdminStats({
    required this.students,
    required this.tutors,
    required this.pendingTutors,
    required this.pendingPayments,
    required this.activeSubscriptions,
    required this.openQuestions,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      students: _intOrNull(json['students']) ?? 0,
      tutors: _intOrNull(json['tutors']) ?? 0,
      pendingTutors: _intOrNull(json['pending_tutors']) ?? 0,
      pendingPayments: _intOrNull(json['pending_payments']) ?? 0,
      activeSubscriptions: _intOrNull(json['active_subscriptions']) ?? 0,
      openQuestions: _intOrNull(json['open_questions']) ?? 0,
    );
  }
}
