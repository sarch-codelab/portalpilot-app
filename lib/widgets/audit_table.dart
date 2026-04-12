import 'package:flutter/material.dart';

class AuditEntry {
  final String timestamp;
  final String userIdentity;
  final String actionEvent;
  final String blockHash;
  final String status;

  const AuditEntry({
    // ← Agregar "const" aquí
    required this.timestamp,
    required this.userIdentity,
    required this.actionEvent,
    required this.blockHash,
    required this.status,
  });

  Color get statusColor =>
      status == 'Valid' ? const Color(0xFF10B981) : const Color(0xFFEF4444);
}

class AuditTable extends StatelessWidget {
  final List<AuditEntry> entries;

  const AuditTable({super.key, required this.entries});

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
                const Icon(Icons.table_chart,
                    size: 18, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                const Text(
                  'IMMUTABLE LEDGER',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text('Export Report',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF10B981))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: DataTable(
              columnSpacing: 24,
              headingRowColor:
                  WidgetStateProperty.all(Colors.white.withOpacity(0.03)),
              headingTextStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
                letterSpacing: 0.5,
              ),
              dataTextStyle:
                  const TextStyle(fontSize: 12, color: Colors.white70),
              columns: const [
                DataColumn(label: Text('TIMESTAMP')),
                DataColumn(label: Text('USER IDENTITY')),
                DataColumn(label: Text('ACTION EVENT')),
                DataColumn(label: Text('BLOCK HASH')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: entries.map((entry) {
                return DataRow(cells: [
                  DataCell(Text(entry.timestamp)),
                  DataCell(Text(entry.userIdentity)),
                  DataCell(Text(entry.actionEvent)),
                  DataCell(Text(entry.blockHash,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: entry.statusColor),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
