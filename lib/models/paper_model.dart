class Paper {
  final String id;
  final String title;
  final int year;
  final String exam;
  final String stage;
  final String subject;
  final String paperType;
  final String filePath;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const Paper({
    required this.id,
    required this.title,
    required this.year,
    required this.exam,
    required this.stage,
    required this.subject,
    required this.paperType,
    required this.filePath,
    this.isPublished = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Paper.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    int parseYear(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? DateTime.now().year;
    }

    return Paper(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Paper',
      year: parseYear(json['year']),
      exam: json['exam']?.toString() ?? 'Civil Services Examination',
      stage: json['stage']?.toString() ?? 'Prelims',
      subject: json['subject']?.toString() ?? 'General Studies',
      paperType: json['paper_type']?.toString() ?? 'Question Paper',
      filePath: json['file_path']?.toString() ?? '',
      isPublished: json['is_published'] as bool? ?? false,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'title': title,
      'year': year,
      'exam': exam,
      'stage': stage,
      'subject': subject,
      'paper_type': paperType,
      'file_path': filePath,
      'is_published': isPublished,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    if (createdBy != null && createdBy!.isNotEmpty) {
      map['created_by'] = createdBy;
    }

    return map;
  }

  Paper copyWith({
    String? id,
    String? title,
    int? year,
    String? exam,
    String? stage,
    String? subject,
    String? paperType,
    String? filePath,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      exam: exam ?? this.exam,
      stage: stage ?? this.stage,
      subject: subject ?? this.subject,
      paperType: paperType ?? this.paperType,
      filePath: filePath ?? this.filePath,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  String get fileName {
    if (filePath.isEmpty) return 'document.pdf';
    final parts = filePath.split('/');
    return parts.isNotEmpty ? parts.last : filePath;
  }
}
