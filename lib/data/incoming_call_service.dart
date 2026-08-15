import 'package:flutter/foundation.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/native_call_service.dart';
import 'package:call_tracker/data/test_mode.dart';

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

  /// Calls hand-injected by the Dashboard's test block, waiting for the next
  /// [drain] to pick them up alongside the real ones.
  static final List<IncomingCallEvent> _simulated = [];

  /// Bumped every time a call is simulated, so whoever presents the summary
  /// screen knows to drain. The native ping can't carry this — in a simulation
  /// nothing native happened.
  static final ValueNotifier<int> simulationSignal = ValueNotifier(0);

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

  /// Test mode only: queues a finished incoming call as if the native receiver
  /// had recorded it, so the whole drain → match → summary path can be checked
  /// on one phone with nothing to ring it from.
  ///
  /// [talkDurationSeconds] of 0 is a missed call — that is the branch that
  /// decides the summary screen's default outcome, so it is worth testing on
  /// its own.
  static void simulate({
    required String number,
    required int talkDurationSeconds,
  }) {
    if (!kIncomingCallTestMode) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _simulated.add(
      IncomingCallEvent(
        id: 'sim-$now',
        number: number,
        startedAtEpochMs: now - talkDurationSeconds * 1000,
        endedAtEpochMs: now,
        answered: talkDurationSeconds > 0,
        talkDurationSeconds: talkDurationSeconds,
        // Nothing was read from the call log — this call never happened.
        fromCallLog: false,
      ),
    );
    simulationSignal.value++;
  }

  /// The stand-in a caller nothing matched becomes while [kIncomingCallTestMode]
  /// is on. Deliberately unmistakable in the UI and in anything it submits, so a
  /// test row is never taken for a real one.
  static Student mockCaller(String number) => Student(
    id: 'test-mode',
    name: 'Test Caller (mock)',
    // The real number, so it can be checked against the phone that just rang.
    phone: number.isEmpty ? 'Unknown number' : number,
    level: 'A1',
    parentName: 'Mock Parent',
    studentId: '#TEST-0000',
  );

  /// Empties the native queue and resolves what it can. Order is preserved so
  /// the agent is asked about calls oldest-first.
  static Future<List<ResolvedIncomingCall>> drain() async {
    // Taken and cleared together, before the first await, so a call simulated
    // while the native queue is being read isn't dropped instead of queued.
    final simulated = [..._simulated];
    _simulated.clear();
    final events = [...simulated, ...await NativeCallService.drainIncomingCalls()];
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
    // A withheld number can't be matched against anything.
    if (key.isEmpty) return kIncomingCallTestMode ? mockCaller(number) : null;
    for (final student in _roster) {
      if (phoneKey(student.phone) == key) return student;
    }
    // Not on any roster we hold — could be a student enrolled since the last
    // sync, which only the backend knows about.
    final found = await ApiService.lookupStudentByPhone(number);
    if (found != null) return found;
    // Nothing matched. Normally that means one of the agent's private calls
    // and we say nothing; in test mode it means the lookup endpoint isn't
    // live yet, and dropping the call would leave nothing to test.
    return kIncomingCallTestMode ? mockCaller(number) : null;
  }
}
