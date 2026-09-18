import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/document.dart';

/// Vertical timeline card, styled after a shipment-tracking UI:
/// a line running top to bottom, with a dot per step —
/// solid green for completed steps, a larger hollow-ring dot for the
/// current/active step, and a plain grey dot for steps still pending.
/// Each dot has a bold label and a date/status line beside it.
class RouteTimeline extends StatelessWidget {
  final TrackedDocument doc;
  final List<RouteStep> route;

  const RouteTimeline({super.key, required this.doc, required this.route});

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the list of steps: "Order Placed" (creation) + one per office in the route.
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Tracking Order Created',
        subtitle: _formatDate(doc.createdAt),
        state: _StepState.done,
      ),
    ];

    for (var i = 0; i < route.length; i++) {
      final r = route[i];
      final isDone = r.status == 'Completed';
      final isLast = i == route.length - 1;

      // The first not-yet-done step is treated as the "active" step,
      // matching the highlighted current stage in the reference design.
      final isActive = !isDone &&
          steps.every((s) => s.state != _StepState.active) &&
          route.take(i).every((prev) => prev.status == 'Completed');

      steps.add(
        _TimelineStep(
          label: isLast && isDone ? 'Received' : r.assignedTo,
          subtitle: isDone ? _formatDate(r.completedAt) : 'Pending',
          state: isDone
              ? _StepState.done
              : (isActive ? _StepState.active : _StepState.pending),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final isLast = i == steps.length - 1;
              final nextIsDone = !isLast && steps[i + 1].state == _StepState.done;
              return _TimelineRow(
                step: step,
                showLine: !isLast,
                lineDone: step.state == _StepState.done && nextIsDone,
              );
            }),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _TimelineStep {
  final String label;
  final String subtitle;
  final _StepState state;
  _TimelineStep({required this.label, required this.subtitle, required this.state});
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool showLine;
  final bool lineDone;

  const _TimelineRow({
    required this.step,
    required this.showLine,
    required this.lineDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = step.state == _StepState.done;
    final isActive = step.state == _StepState.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + connecting line column
          Column(
            children: [
              _StepDot(state: step.state),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: lineDone ? Colors.green.shade600 : Colors.grey.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Label + subtitle
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isActive ? 16 : 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      color: isDone || isActive ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final _StepState state;
  const _StepDot({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade600,
          ),
        );
      case _StepState.active:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.green.shade600, width: 3),
          ),
        );
      case _StepState.pending:
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade600,
          ),
        );
    }
  }
}
