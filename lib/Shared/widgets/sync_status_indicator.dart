import 'dart:async';
import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';

class SyncStatusIndicator extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const SyncStatusIndicator({
    super.key,
    this.showDetails = false,
    this.onTap,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  StreamSubscription<SyncStatus>? _subscription;
  SyncStatus _currentStatus = SyncStatus(pendingCount: 0, message: 'Iniciando...');
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = _localDb.isOnline;
    _subscription = _localDb.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _isOnline = _localDb.isOnline;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isOnline
        ? (_currentStatus.isError ? Colors.red : Colors.green)
        : Colors.orange;

    final icon = _isOnline
        ? (_currentStatus.isError ? Icons.sync_problem : Icons.cloud_done)
        : Icons.cloud_off;

    if (!widget.showDetails) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                _isOnline
                    ? (_currentStatus.pendingCount > 0 ? 'Sync: ${_currentStatus.pendingCount}' : 'Online')
                    : 'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOnline ? 'En línea' : 'Sin conexión',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                if (_currentStatus.pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_currentStatus.pendingCount} pendientes',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currentStatus.message,
              style: TextStyle(
                fontSize: 12,
                color: _currentStatus.isError ? Colors.red : Colors.grey[700],
              ),
            ),
            if (_currentStatus.pendingCount > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _localDb.forceSyncNow(),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sincronizar ahora'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SyncStatusDialog extends StatelessWidget {
  const SyncStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localDb = LocalDatabaseService.instance;

    return StreamBuilder<List<SyncItem>>(
      stream: _pendingItemsStream(localDb),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final isOnline = localDb.isOnline;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: isOnline ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text('Estado de Sincronización'),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Conectado - Sincronización automática activa' : 'Sin conexión - Cambios guardados localmente',
                        style: TextStyle(
                          color: isOnline ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay elementos pendientes de sincronizar',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: _getOperationColor(item.operacion).withValues(alpha: 0.2),
                                child: Icon(
                                  _getOperationIcon(item.operacion),
                                  size: 16,
                                  color: _getOperationColor(item.operacion),
                                ),
                              ),
                              title: Text(
                                '${item.tabla} - ${item.operacion.name}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                'Intentos: ${item.intentos}/${item.maxIntentos}${item.ultimoError != null ? '\nError: ${item.ultimoError}' : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: item.procesando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            if (isOnline && items.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  localDb.forceSyncNow();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.sync),
                label: const Text('Forzar Sync'),
              ),
          ],
        );
      },
    );
  }

  Stream<List<SyncItem>> _pendingItemsStream(LocalDatabaseService localDb) async* {
    yield await localDb.getPendingSyncItems();
    await for (final _ in localDb.syncStatusStream) {
      yield await localDb.getPendingSyncItems();
    }
  }

  Color _getOperationColor(SyncOperation op) {
    switch (op) {
      case SyncOperation.insert:
        return Colors.green;
      case SyncOperation.update:
        return Colors.blue;
      case SyncOperation.delete:
        return Colors.red;
    }
  }

  IconData _getOperationIcon(SyncOperation op) {
    switch (op) {
      case SyncOperation.insert:
        return Icons.add;
      case SyncOperation.update:
        return Icons.edit;
      case SyncOperation.delete:
        return Icons.delete;
    }
  }
}