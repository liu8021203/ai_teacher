import 'package:json_annotation/json_annotation.dart';

part 'student_data_list_entity.g.dart';

@JsonSerializable()
class StudentDataListEntity {
  late final int id;
  late final String? activity;
  late final String? description;
  late final String createDate;

  StudentDataListEntity({
    required this.id,
    this.activity,
    this.description,
    required this.createDate
  });

  factory StudentDataListEntity.fromJson(Map<String, dynamic> json) => _$StudentDataListEntityFromJson(json);

  Map<String, dynamic> toJson() => _$StudentDataListEntityToJson(this);
}
