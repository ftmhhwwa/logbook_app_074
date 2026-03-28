import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

@HiveType(typeId: 0)
class LogModel {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String date;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final String authorId;

  @HiveField(5)
  final String teamId;

  @HiveField(6)
  final String category;

  @HiveField(7, defaultValue: false)
  final bool isSynced;

  @HiveField(8, defaultValue: false)
  final bool isPublic;

  LogModel({
    this.id,
    required this.title,
    required this.date,
    required this.description,
    this.category = 'Pribadi',
    required this.teamId,
    required this.authorId,
    this.isSynced = false,
    this.isPublic = false,
  });

  // Untuk Tugas HOTS: Konversi Map (JSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: (map['_id'] as ObjectId?)?.oid,
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Pribadi',
      teamId: map['teamId'] ?? 'no_team',
      authorId: map['authorId'] ?? 'unknown_user',
      isSynced: true,
      isPublic: map['isPublic'] ?? false,
    );
  }

  LogModel copyWith({
    String? id,
    String? title,
    String? date,
    String? description,
    String? authorId,
    String? teamId,
    String? category,
    bool? isSynced,
    bool? isPublic,
  }) {
    return LogModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      teamId: teamId ?? this.teamId,
      category: category ?? this.category,
      isSynced: isSynced ?? this.isSynced,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {
      '_id': id != null ? ObjectId.fromHexString(id!) : ObjectId(),
      'title': title,
      'date': date,
      'description': description,
      'category': category,
      'teamId': teamId,
      'authorId': authorId,
      'isPublic': isPublic,
    };
  }
}
