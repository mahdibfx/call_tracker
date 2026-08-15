import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'package:call_tracker/data/call_monitor.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/native_call_service.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/call_summary/call_summary_view.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// A real phone call is owned by Android's own Phone app once placed — a
/// regular (non-default-dialer) app has no API to mute/hang up/speaker a
/// live call. This screen places the call, then waits and watches for it
/// to end, via phone_state while foregrounded and via the call log once
/// the agent returns to the app (or reopens it, even after a process kill).
class CallView extends StatefulWidget {
  const CallView({super.key, required this.student, required this.reason});

  final Student student;
  final CallReason reason;

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> with WidgetsBindingObserver {
  StreamSubscription<PhoneState>? _sub;
  PhoneStateStatus _status = PhoneStateStatus.NOTHING;
  bool _launching = true;
  bool _wasBackgrounded = false;
  bool _resolved = false;
  bool _reconciling = false;
  bool _sawCallStart = false;
  DateTime? _callStartedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final status = await Permission.phone.request();
    if (!status.isGranted) {
      setState(() {
        _launching = false;
        _error = 'Phone permission is required to place calls from the app.';
      });
      return;
    }

    final startedAt = DateTime.now();
    await CallMonitor.savePending(
      PendingCall(
        studentId: widget.student.id,
        studentName: widget.student.name,
        parentName: widget.student.parentName,
        number: widget.student.phone,
        startedAtEpochMs: startedAt.millisecondsSinceEpoch,
        reason: widget.reason,
      ),
    );

    final placed = await NativeCallService.placeCall(widget.student.phone);
    if (!placed) {
      await CallMonitor.clearPending();
      if (!mounted) return;
      setState(() {
        _launching = false;
        _error = "Couldn't launch the phone dialer.";
      });
      return;
    }

    if (!mounted) return;
    setState(() => _launching = false);
    _sub = PhoneState.stream.listen((state) {
      if (!mounted) return;
      setState(() => _status = state.status);
      if (state.status == PhoneStateStatus.CALL_STARTED) {
        // The call is genuinely active — only NOW can a later CALL_ENDED be trusted.
        _sawCallStart = true;
        _callStartedAt ??= DateTime.now();
      } else if (state.status == PhoneStateStatus.CALL_ENDED && _sawCallStart) {
        _reconcile();
      }
      // Note: the stream's very first event on subscription is a snapshot of
      // whatever the telephony state already was — right after placeCall()
      // that's still almost always IDLE (the call hasn't gone off-hook yet),
      // which this package reports as CALL_ENDED. Ignoring CALL_ENDED until
      // we've seen CALL_STARTED avoids reconciling before the call happened.
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _reconcile();
    }
  }

  Future<void> _reconcile() async {
    if (_resolved) return;
    final pending = await CallMonitor.readPending();
    if (pending == null) return;
    _resolved = true;
    // reconcile() waits out the live call itself — the CallLog row it reads
    // does not exist until the call disconnects.
    if (mounted) setState(() => _reconciling = true);
    final verification = await CallMonitor.reconcile(
      pending,
      callStartedAt: _callStartedAt,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallSummaryView(
          student: widget.student,
          reason: widget.reason,
          durationSeconds: verification.talkDurationSeconds,
          verification: verification,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  String get _statusText {
    if (_launching) return 'Opening phone dialer...';
    if (_error != null) return _error!;
    // Says nothing about the call log check happening behind it — the agent
    // being checked must not know there is a check.
    if (_reconciling) return 'Wrapping up — stay here until the call ends';
    return switch (_status) {
      PhoneStateStatus.CALL_STARTED =>
        'Call in progress — switch to the Phone app',
      PhoneStateStatus.CALL_ENDED => 'Call ended, finishing up...',
      _ => 'Waiting for the call to start...',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppTopBar(
        title: 'Calling',
        onBack: () => Navigator.of(context).pop(),
        trailing: const SizedBox.shrink(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(
              AppStyles.borderRadiusLargeValue,
            ),
            border: Border.all(color: AppColors.primaryColorLight),
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 44,
                  color: AppColors.primaryColor,
                ),
              ),
              verticalSpaceMedium,
              CustomText.title(text: widget.student.name, fontSize: 20),
              const SizedBox(height: 4),
              CustomText.subtitle(text: 'Parent: ${widget.student.parentName}'),
              verticalSpaceMedium,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _error != null
                      ? AppColors.redColorLight
                      : AppColors.primaryColorLight,
                  borderRadius: BorderRadius.circular(
                    AppStyles.borderRadiusPillValue,
                  ),
                ),
                child: CustomText.bodyBold(
                  text: _statusText,
                  textColor: _error != null
                      ? AppColors.redColor
                      : AppColors.primaryColor,
                  fontSize: 13,
                  textAlign: TextAlign.center,
                ),
              ),
              verticalSpaceLarge,
              Align(
                alignment: Alignment.centerLeft,
                child: CustomText.caption(text: 'REASON FOR CALL'),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(
                    AppStyles.borderRadiusMediumValue,
                  ),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: AppColors.textColor,
                    ),
                    horizontalSpaceSmall,
                    CustomText.bodyBold(
                      text: widget.reason.chipLabel,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
              verticalSpaceLarge,
              if (!_launching) ...[
                CustomText.caption(
                  text: _error != null
                      ? 'Go back and try again.'
                      : "The call runs in your device's Phone app. Come back here when it's done — we'll pick it up automatically, or tap below.",
                  textAlign: TextAlign.center,
                ),
                verticalSpaceMedium,
                if (_error == null)
                  CustomButton(
                    text: "I finished the call",
                    onPressed: _reconcile,
                    backgroundColor: AppColors.textColor,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
