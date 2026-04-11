import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProcessMonitor extends StatelessWidget {
  final List<ProcessTask> tasks;

  const ProcessMonitor({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text(
                  'PROCESS MONITOR',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: tasks
                  .map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  task.status,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: task.statusColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: task.progress,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    task.progressColor),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Text(
              'VIEW ALL ACTIVE INSTANCES',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0EA5E9),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessTask {
  final String name;
  final String subtitle;
  final double progress;
  final String status;

  ProcessTask({
    required this.name,
    required this.subtitle,
    required this.progress,
    required this.status,
  });

  Color get statusColor {
    if (status.contains('Completed') || status.contains('100%')) {
      return const Color(0xFF10B981);
    }
    return const Color(0xFFF59E0B);
  }

  Color get progressColor {
    if (progress >= 0.8) return const Color(0xFF10B981);
    if (progress >= 0.4) return const Color(0xFFF59E0B);
    return const Color(0xFF0EA5E9);
  }
}
