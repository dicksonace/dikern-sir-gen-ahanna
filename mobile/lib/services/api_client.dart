import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  String? _token;

  String? get token => _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<dynamic> _handle(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Future.value(body);
    }
    String message = 'Request failed (${res.statusCode})';
    if (body is Map) {
      if (body['message'] != null) message = body['message'].toString();
      if (body['errors'] is Map) {
        final errors = body['errors'] as Map;
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) message = first.first.toString();
      }
    }
    throw ApiException(message, statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> login(String email, String password, {required String division}) async {
    final res = await http.post(
      _uri('/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password, 'division': division}),
    );
    final data = await _handle(res) as Map<String, dynamic>;
    _token = data['token'] as String?;
    return data;
  }

  Future<void> logout() async {
    try {
      await http.post(_uri('/logout'), headers: _headers);
    } catch (_) {}
    _token = null;
  }

  Future<AppUser> me() async {
    final res = await http.get(_uri('/me'), headers: _headers);
    return AppUser.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({
    required String name,
    String? phone,
    String? bio,
    String? qualifications,
    String? experience,
  }) async {
    final res = await http.put(
      _uri('/profile'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'bio': bio,
        'qualifications': qualifications,
        'experience': experience,
      }),
    );
    return AppUser.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/change-password'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      }),
    );
    await _handle(res);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final res = await http.post(
      _uri('/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
    final data = await _handle(res) as Map<String, dynamic>;
    _token = data['token'] as String?;
    return data;
  }

  Future<void> verifyEmail({
    required String email,
    required String division,
    required String code,
  }) async {
    final res = await http.post(
      _uri('/verify-email'),
      headers: _headers,
      body: jsonEncode({'email': email, 'division': division, 'code': code}),
    );
    await _handle(res);
  }

  Future<void> resendVerification({required String email, required String division}) async {
    final res = await http.post(
      _uri('/resend-verification'),
      headers: _headers,
      body: jsonEncode({'email': email, 'division': division}),
    );
    await _handle(res);
  }

  Future<AppUser> uploadIdentity({required String kind, required String path, required String filename}) async {
    final request = http.MultipartRequest('POST', _uri('/kyc'));
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['kind'] = kind;
    request.files.add(await http.MultipartFile.fromPath(
      'document',
      path,
      filename: filename,
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    await _handle(res);
    return me();
  }

  Future<String?> forgotPassword(String email, {required String division}) async {
    final res = await http.post(
      _uri('/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email, 'division': division}),
    );
    final data = await _handle(res) as Map<String, dynamic>;
    return data['reset_code'] as String?;
  }

  Future<void> resetPassword({
    required String email,
    required String division,
    required String code,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/reset-password'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'division': division,
        'code': code,
        'password': password,
        'password_confirmation': password,
      }),
    );
    await _handle(res);
  }

  Future<bool> health() async {
    try {
      final res = await http.get(_uri('/health'), headers: _headers).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<LearningTrack>> tracks({String? division}) async {
    final res = await http.get(_uri('/tracks', division == null ? null : {'division': division}), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(LearningTrack.fromJson).toList();
  }

  Future<List<Subject>> subjects({String? division, String? track}) async {
    final query = <String, String>{
      'division': ?division,
      'track': ?track,
    };
    final res = await http.get(_uri('/subjects', query.isEmpty ? null : query), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(Subject.fromJson).toList();
  }

  Future<List<PackageModel>> packages({String? division}) async {
    final res = await http.get(_uri('/packages', division == null ? null : {'division': division}), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(PackageModel.fromJson).toList();
  }

  Future<List<TutorProfile>> tutors({String? subject, String? division}) async {
    final query = <String, String>{
      if (subject != null) 'subject': subject,
      if (division != null) 'division': division,
    };
    final res = await http.get(
      _uri('/tutors', query.isEmpty ? null : query),
      headers: _headers,
    );
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(TutorProfile.fromJson).toList();
  }

  Future<TutorProfile> tutorShow(int id) async {
    final res = await http.get(_uri('/tutors/$id'), headers: _headers);
    return TutorProfile.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> subscribe({
    required int tutorId,
    required int packageId,
    String? slipNote,
  }) async {
    final res = await http.post(
      _uri('/subscribe'),
      headers: _headers,
      body: jsonEncode({
        'tutor_id': tutorId,
        'package_id': packageId,
        'slip_note': slipNote ?? 'slip-uploaded-prototype.jpg',
      }),
    );
    return await _handle(res) as Map<String, dynamic>;
  }

  Future<List<LessonModel>> lessons() async {
    final res = await http.get(_uri('/lessons'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(LessonModel.fromJson).toList();
  }

  Future<Map<String, dynamic>> startLesson(int id) async {
    final res = await http.post(_uri('/lessons/$id/start'), headers: _headers);
    return await _handle(res) as Map<String, dynamic>;
  }

  Future<List<QuestionModel>> questions() async {
    final res = await http.get(_uri('/questions'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(QuestionModel.fromJson).toList();
  }

  Future<QuestionModel> askQuestion({
    required int tutorId,
    required String body,
    int? subjectId,
  }) async {
    final res = await http.post(
      _uri('/questions'),
      headers: _headers,
      body: jsonEncode({
        'tutor_id': tutorId,
        'body': body,
        if (subjectId != null) 'subject_id': subjectId,
      }),
    );
    return QuestionModel.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<void> replyQuestion(int id, {required String type, required String content}) async {
    final res = await http.post(
      _uri('/questions/$id/reply'),
      headers: _headers,
      body: jsonEncode({'type': type, 'content': content}),
    );
    await _handle(res);
  }

  Future<void> givePoint({required int tutorId, int? lessonId, int? questionId}) async {
    final res = await http.post(
      _uri('/points'),
      headers: _headers,
      body: jsonEncode({
        'tutor_id': tutorId,
        if (lessonId != null) 'lesson_id': lessonId,
        if (questionId != null) 'question_id': questionId,
      }),
    );
    await _handle(res);
  }

  Future<List<CommissionModel>> tutorEarnings() async {
    final res = await http.get(_uri('/tutor/earnings'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(CommissionModel.fromJson).toList();
  }

  Future<AdminStats> adminStats() async {
    final res = await http.get(_uri('/admin/stats'), headers: _headers);
    return AdminStats.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<List<TutorProfile>> pendingTutors() async {
    final res = await http.get(_uri('/admin/pending-tutors'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(TutorProfile.fromJson).toList();
  }

  Future<void> approveTutor(int id) async {
    final res = await http.post(_uri('/admin/tutors/$id/approve'), headers: _headers);
    await _handle(res);
  }

  Future<List<PaymentModel>> pendingPayments() async {
    final res = await http.get(_uri('/admin/pending-payments'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(PaymentModel.fromJson).toList();
  }

  Future<void> verifyPayment(int id) async {
    final res = await http.post(_uri('/admin/payments/$id/verify'), headers: _headers);
    await _handle(res);
  }
}
