import 'dart:convert';
import 'package:flutter/foundation.dart';
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

class _MemoryEntry {
  final Object value;
  final DateTime at;

  _MemoryEntry(this.value, this.at);
}

class ApiClient extends ChangeNotifier {
  String? _token;
  final http.Client _http = http.Client();
  final Map<String, _MemoryEntry> _cache = {};
  final Map<String, Future<Object>> _inflight = {};
  int revision = 0;

  String? get token => _token;

  void setToken(String? token) {
    if (_token != token) clearCache();
    _token = token;
  }

  void bump() {
    revision++;
    notifyListeners();
  }

  void forget(String key) {
    _cache.removeWhere((cached, _) => cached == key || cached.startsWith('$key:'));
  }

  void clearCache() {
    _cache.clear();
    _inflight.clear();
  }

  T? peek<T>(String key) {
    final hit = _cache[key];
    if (hit == null) return null;
    return hit.value as T;
  }

  void warm({required String? division, required bool law}) {
    lessons();
    questions();
    packages(division: division);
    if (law) {
      subjects(division: 'law');
      tutors(division: 'law');
    } else {
      tracks(division: 'tutor');
      tutors(division: division ?? 'tutor');
    }
  }

  Future<T> remember<T>(String key, Duration ttl, Future<T> Function() load, {bool force = false}) async {
    if (!force) {
      final hit = _cache[key];
      if (hit != null && DateTime.now().difference(hit.at) < ttl) {
        return hit.value as T;
      }
      final pending = _inflight[key];
      if (pending != null) return await pending as T;
    }

    final future = load();
    final boxed = future.then((value) => value as Object);
    _inflight[key] = boxed;
    try {
      final value = await future;
      _cache[key] = _MemoryEntry(value as Object, DateTime.now());
      return value;
    } finally {
      if (identical(_inflight[key], boxed)) _inflight.remove(key);
    }
  }

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
    final res = await _http.post(
      _uri('/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password, 'division': division}),
    );
    final data = await _handle(res) as Map<String, dynamic>;
    _token = data['token'] as String?;
    clearCache();
    return data;
  }

  Future<void> logout() async {
    try {
      await _http.post(_uri('/logout'), headers: _headers);
    } catch (_) {}
    _token = null;
    clearCache();
  }

  Future<AppUser> me({bool force = false}) {
    return remember('me', const Duration(minutes: 5), () async {
      final res = await _http.get(_uri('/me'), headers: _headers);
      return AppUser.fromJson(await _handle(res) as Map<String, dynamic>);
    }, force: force);
  }

  Future<AppUser> updateProfile({
    required String name,
    String? phone,
    String? bio,
    String? qualifications,
    String? experience,
  }) async {
    final res = await _http.put(
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
    forget('me');
    return AppUser.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    final res = await _http.post(
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
    final res = await _http.post(
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
    final res = await _http.post(
      _uri('/verify-email'),
      headers: _headers,
      body: jsonEncode({'email': email, 'division': division, 'code': code}),
    );
    await _handle(res);
  }

  Future<void> resendVerification({required String email, required String division}) async {
    final res = await _http.post(
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
    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);
    await _handle(res);
    return me(force: true);
  }

  Future<String?> forgotPassword(String email, {required String division}) async {
    final res = await _http.post(
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
    final res = await _http.post(
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
      final res = await _http.get(_uri('/health'), headers: _headers).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<LearningTrack>> tracks({String? division, bool force = false}) {
    return remember('tracks:${division ?? ''}', const Duration(minutes: 10), () async {
      final res = await _http.get(_uri('/tracks', division == null ? null : {'division': division}), headers: _headers);
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(LearningTrack.fromJson).toList();
    }, force: force);
  }

  Future<List<Subject>> subjects({String? division, String? track, bool force = false}) {
    return remember('subjects:${division ?? ''}:${track ?? ''}', const Duration(minutes: 10), () async {
      final query = <String, String>{
        'division': ?division,
        'track': ?track,
      };
      final res = await _http.get(_uri('/subjects', query.isEmpty ? null : query), headers: _headers);
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(Subject.fromJson).toList();
    }, force: force);
  }

  Future<List<PackageModel>> packages({String? division, bool force = false}) {
    return remember('packages:${division ?? ''}', const Duration(minutes: 10), () async {
      final res = await _http.get(_uri('/packages', division == null ? null : {'division': division}), headers: _headers);
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(PackageModel.fromJson).toList();
    }, force: force);
  }

  Future<List<TutorProfile>> tutors({String? subject, String? division, bool force = false}) {
    return remember('tutors:${division ?? ''}:${subject ?? ''}', const Duration(minutes: 2), () async {
      final query = <String, String>{
        if (subject != null) 'subject': subject,
        if (division != null) 'division': division,
      };
      final res = await _http.get(
        _uri('/tutors', query.isEmpty ? null : query),
        headers: _headers,
      );
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(TutorProfile.fromJson).toList();
    }, force: force);
  }

  Future<TutorProfile> tutorShow(int id, {bool force = false}) {
    return remember('tutor:$id', const Duration(minutes: 2), () async {
      final res = await _http.get(_uri('/tutors/$id'), headers: _headers);
      return TutorProfile.fromJson(await _handle(res) as Map<String, dynamic>);
    }, force: force);
  }

  Future<Map<String, dynamic>> subscribe({
    required int tutorId,
    required int packageId,
    required String slipPath,
    required String slipName,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/subscribe'));
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['tutor_id'] = '$tutorId';
    request.fields['package_id'] = '$packageId';
    request.files.add(await http.MultipartFile.fromPath('slip', slipPath, filename: slipName));
    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);
    forget('subscriptions');
    return await _handle(res) as Map<String, dynamic>;
  }

  Future<Set<int>> activeTutorUserIds({bool force = false}) {
    return remember('subscriptions', const Duration(minutes: 1), () async {
      final res = await _http.get(_uri('/my-subscriptions'), headers: _headers);
    final list = await _handle(res) as List;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final ids = <int>{};
    for (final row in list.whereType<Map<String, dynamic>>()) {
      if (row['status'] != 'active') continue;
      final ends = row['ends_at']?.toString();
      if (ends != null && ends.isNotEmpty) {
        final date = DateTime.tryParse(ends);
        if (date != null && date.isBefore(startOfToday)) continue;
      }
      final id = row['tutor_id'];
      if (id is int) ids.add(id);
    }
    return ids;
    }, force: force);
  }

  Future<List<LessonModel>> lessons({bool force = false}) {
    return remember('lessons', const Duration(seconds: 45), () async {
      final res = await _http.get(_uri('/lessons'), headers: _headers);
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(LessonModel.fromJson).toList();
    }, force: force);
  }

  Future<Map<String, dynamic>> startLesson(int id) async {
    final res = await _http.post(_uri('/lessons/$id/start'), headers: _headers);
    forget('lessons');
    return await _handle(res) as Map<String, dynamic>;
  }

  Future<List<QuestionModel>> questions({bool force = false}) {
    return remember('questions', const Duration(seconds: 45), () async {
      final res = await _http.get(_uri('/questions'), headers: _headers);
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(QuestionModel.fromJson).toList();
    }, force: force);
  }

  Future<QuestionModel> question(int id, {bool force = false}) {
    return remember('question:$id', const Duration(seconds: 20), () async {
      final res = await _http.get(_uri('/questions/$id'), headers: _headers);
      return QuestionModel.fromJson(await _handle(res) as Map<String, dynamic>);
    }, force: force);
  }

  Future<QuestionModel> closeQuestion(int id) async {
    final res = await _http.post(_uri('/questions/$id/close'), headers: _headers);
    forget('questions');
    forget('question:$id');
    return QuestionModel.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<QuestionModel> askQuestion({
    required int tutorId,
    required String body,
    int? subjectId,
    String? filePath,
    String? filename,
  }) async {
    if (filePath == null) {
      final res = await _http.post(
        _uri('/questions'),
        headers: _headers,
        body: jsonEncode({
          'tutor_id': tutorId,
          'body': body,
          if (subjectId != null) 'subject_id': subjectId,
        }),
      );
      forget('questions');
      return QuestionModel.fromJson(await _handle(res) as Map<String, dynamic>);
    }

    final request = http.MultipartRequest('POST', _uri('/questions'));
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['tutor_id'] = '$tutorId';
    request.fields['body'] = body;
    if (subjectId != null) request.fields['subject_id'] = '$subjectId';
    request.files.add(await http.MultipartFile.fromPath('attachment', filePath, filename: filename));
    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);
    forget('questions');
    return QuestionModel.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<void> replyQuestion(
    int id, {
    required String type,
    required String content,
    String? filePath,
    String? filename,
  }) async {
    if (filePath == null) {
      final res = await _http.post(
        _uri('/questions/$id/reply'),
        headers: _headers,
        body: jsonEncode({'type': type, 'content': content}),
      );
      await _handle(res);
      forget('questions');
      forget('question:$id');
      return;
    }

    final request = http.MultipartRequest('POST', _uri('/questions/$id/reply'));
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['type'] = type;
    request.fields['content'] = content;
    request.files.add(await http.MultipartFile.fromPath('attachment', filePath, filename: filename));
    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);
    await _handle(res);
    forget('questions');
    forget('question:$id');
  }

  Future<void> givePoint({required int tutorId, int? lessonId, int? questionId}) async {
    final res = await _http.post(
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

  Future<List<CommissionModel>> tutorEarnings({bool force = false}) {
    return remember('earnings', const Duration(minutes: 1), () async {
      final res = await _http.get(_uri('/tutor/earnings'), headers: _headers);
      final list = await _handle(res) as List;
      return list.whereType<Map<String, dynamic>>().map(CommissionModel.fromJson).toList();
    }, force: force);
  }

  Future<AdminStats> adminStats() async {
    final res = await _http.get(_uri('/admin/stats'), headers: _headers);
    return AdminStats.fromJson(await _handle(res) as Map<String, dynamic>);
  }

  Future<List<TutorProfile>> pendingTutors() async {
    final res = await _http.get(_uri('/admin/pending-tutors'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(TutorProfile.fromJson).toList();
  }

  Future<void> approveTutor(int id) async {
    final res = await _http.post(_uri('/admin/tutors/$id/approve'), headers: _headers);
    await _handle(res);
  }

  Future<List<PaymentModel>> pendingPayments() async {
    final res = await _http.get(_uri('/admin/pending-payments'), headers: _headers);
    final list = await _handle(res) as List;
    return list.whereType<Map<String, dynamic>>().map(PaymentModel.fromJson).toList();
  }

  Future<void> verifyPayment(int id) async {
    final res = await _http.post(_uri('/admin/payments/$id/verify'), headers: _headers);
    await _handle(res);
  }
}
