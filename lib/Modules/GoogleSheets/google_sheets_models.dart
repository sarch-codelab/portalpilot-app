class GoogleSheetsConfig {
  final String? spreadsheetId;
  final String? spreadsheetUrl;
  final String? sheetName;
  final bool autoSyncEnabled;
  final String? lastSyncAt;
  final int lastSyncRows;
  final String? errorMessage;

  const GoogleSheetsConfig({
    this.spreadsheetId,
    this.spreadsheetUrl,
    this.sheetName,
    this.autoSyncEnabled = false,
    this.lastSyncAt,
    this.lastSyncRows = 0,
    this.errorMessage,
  });

  factory GoogleSheetsConfig.fromJson(Map<String, dynamic> json) {
    return GoogleSheetsConfig(
      spreadsheetId: json['spreadsheetId'] as String?,
      spreadsheetUrl: json['spreadsheetUrl'] as String?,
      sheetName: json['sheetName'] as String?,
      autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? false,
      lastSyncAt: json['lastSyncAt'] as String?,
      lastSyncRows: json['lastSyncRows'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spreadsheetId': spreadsheetId,
      'spreadsheetUrl': spreadsheetUrl,
      'sheetName': sheetName,
      'autoSyncEnabled': autoSyncEnabled,
      'lastSyncAt': lastSyncAt,
      'lastSyncRows': lastSyncRows,
      'errorMessage': errorMessage,
    };
  }

  GoogleSheetsConfig copyWith({
    String? spreadsheetId,
    String? spreadsheetUrl,
    String? sheetName,
    bool? autoSyncEnabled,
    String? lastSyncAt,
    int? lastSyncRows,
    String? errorMessage,
  }) {
    return GoogleSheetsConfig(
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      spreadsheetUrl: spreadsheetUrl ?? this.spreadsheetUrl,
      sheetName: sheetName ?? this.sheetName,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncRows: lastSyncRows ?? this.lastSyncRows,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isConnected => spreadsheetId != null && spreadsheetId!.isNotEmpty;

  String get displayName => spreadsheetUrl != null
      ? 'Conectado a Google Sheets'
      : 'No conectado';
}

class SyncResult {
  final bool success;
  final int rowsSynced;
  final String sheetName;
  final String? errorMessage;
  final DateTime syncedAt;

  const SyncResult({
    required this.success,
    required this.rowsSynced,
    required this.sheetName,
    this.errorMessage,
    required this.syncedAt,
  });

  factory SyncResult.success({
    required int rowsSynced,
    required String sheetName,
  }) => SyncResultSuccess(rowsSynced: rowsSynced, sheetName: sheetName);

  factory SyncResult.failure({
    required String errorMessage,
    required String sheetName,
  }) => SyncResultFailure(errorMessage: errorMessage, sheetName: sheetName);
}

class SyncResultSuccess extends SyncResult {
  SyncResultSuccess({
    required super.rowsSynced,
    required super.sheetName,
  }) : super(
    success: true,
    errorMessage: null,
    syncedAt: DateTime.now(),
  );
}

class SyncResultFailure extends SyncResult {
  SyncResultFailure({
    required super.errorMessage,
    required super.sheetName,
  }) : super(
    success: false,
    rowsSynced: 0,
    syncedAt: DateTime.now(),
  );
}