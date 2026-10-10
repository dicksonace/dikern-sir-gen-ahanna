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
      id: json['id'] as int,
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
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      bio: json['bio'] as String?,
      qualifications: json['qualifications'] as String?,
      experience: json['experience'] as String?,
      satisfactionPoints: json['satisfaction_points'] as int? ?? 0,
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
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
    );
  }
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
      id: json['id'] as int,
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
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: double.tryParse('${json['price']}') ?? 0,
      weeklyHours: json['weekly_hours'] as int? ?? 2,
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
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Lesson',
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse('${json['scheduled_at']}') : null,
      durationMinutes: json['duration_minutes'] as int? ?? 120,
      trackedMinutes: json['tracked_minutes'] as int? ?? 0,
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

  const QuestionReply({required this.id, required this.type, this.content});

  factory QuestionReply.fromJson(Map<String, dynamic> json) {
    return QuestionReply(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String?,
    );
  }
}

class QuestionModel {
  final int id;
  final String body;
  final String status;
  final String? attachmentPath;
  final Subject? subject;
  final AppUser? student;
  final AppUser? tutor;
  final List<QuestionReply> replies;

  const QuestionModel({
    required this.id,
    required this.body,
    required this.status,
    this.attachmentPath,
    this.subject,
    this.student,
    this.tutor,
    this.replies = const [],
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      attachmentPath: json['attachment_path'] as String?,
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
      id: json['id'] as int,
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
      id: json['id'] as int,
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
      students: json['students'] as int? ?? 0,
      tutors: json['tutors'] as int? ?? 0,
      pendingTutors: json['pending_tutors'] as int? ?? 0,
      pendingPayments: json['pending_payments'] as int? ?? 0,
      activeSubscriptions: json['active_subscriptions'] as int? ?? 0,
      openQuestions: json['open_questions'] as int? ?? 0,
    );
  }
}
