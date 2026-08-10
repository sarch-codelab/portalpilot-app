import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

mixin DraftPersistenceMixin<T extends StatefulWidget> on State<T> {
  String get draftPantalla;
  String get draftClave;
  Map<String, dynamic> get draftData;
  void restoreDraft(Map<String, dynamic> data);

  Timer? _draftTimer;
  static const Duration _draftInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _startAutoSave();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _saveDraft();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await LocalDatabaseService.instance.getDraft(draftPantalla, draftClave);
      if (draft != null && mounted) {
        restoreDraft(draft);
        debugPrint('📄 Borrador cargado para $draftPantalla/$draftClave');
      }
    } catch (e) {
      debugPrint('❌ Error cargando borrador: $e');
    }
  }

  void _startAutoSave() {
    _draftTimer = Timer.periodic(_draftInterval, (_) {
      if (mounted) _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    try {
      final data = draftData;
      if (data.isNotEmpty) {
        await LocalDatabaseService.instance.saveDraft(draftPantalla, draftClave, data);
        debugPrint('💾 Borrador guardado para $draftPantalla/$draftClave');
      }
    } catch (e) {
      debugPrint('❌ Error guardando borrador: $e');
    }
  }

  Future<void> clearDraft() async {
    await LocalDatabaseService.instance.clearDraft(draftPantalla, draftClave);
  }

  void forceSaveDraft() => _saveDraft();
}