import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/native_call_service.dart';

/// An incoming call that has been matched to a student, and so is worth
/// asking the agent about.
class ResolvedIncomingCall {
  const ResolvedIncomingCall({required this.student, required this.event});

  final Student student;
  final IncomingCallEvent event;
}

/// Turns the raw incoming calls the native receiver queued into calls the
/// agent can be asked to log.
///
/// Matching happens in three steps, cheapest first: the roster this session
/// already has, then the roster the receiver cached on disk (so a cold start
/// resolves before the network answers), then the backend. Anything that
/// matches none of them is one of the agent's own private calls and is
/// dropped silently.
class IncomingCallService {
  IncomingCallService._();

  static List<Student> _roster = const [];

  /// Same last-nine-digits rule the native side uses, so a number written
  /// "+212612345678" on the network and "0612345678" on the backend are one
  /// person on both sides of the bridge.
  static String phoneKey(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length <= 9 ? digits : digits.substring(digits.length - 9);
  }

  /// Called whenever the students list is loaded. Keeps the in-memory roster
  /// and the native cache in step.
  static Future<void> syncRoster(List<Student> students) async {
    _roster = students;
    await NativeCallService.cacheStudents(students);
  }

  /// Seeds the roster from the native cache. Cheap, offline, and the only way
  /// a call that came in while the app was dead gets a name attached to it
  /// before the students request completes.
  static Future<void> primeRosterFromCache() async {
    if (_roster.isNotEmpty) return;
    _roster = await NativeCallService.cachedStudents();
  }

  /// Empties the native queue and resolves what it can. Order is preserved so
  /// the agent is asked about calls oldest-first.
  static Future<List<ResolvedIncomingCall>> drain() async {
    final events = await NativeCallService.drainIncomingCalls();
    if (events.isEmpty) return const [];
    await primeRosterFromCache();

    final resolved = <ResolvedIncomingCall>[];
    for (final event in events) {
      final student = await _resolve(event.number);
      if (student == null) continue;
      resolved.add(ResolvedIncomingCall(student: student, event: event));
    }
    return resolved;
  }

  static Future<Student?> _resolve(String number) async {
    final key = phoneKey(number);
    if (key.isEmpty) return null;
    for (final student in _roster) {
      if (phoneKey(student.phone) == key) return student;
    }
    // Not on any roster we hold — could be a student enrolled since the last
    // sync, which only the backend knows about.
    return ApiService.lookupStudentByPhone(number);
  }
}
