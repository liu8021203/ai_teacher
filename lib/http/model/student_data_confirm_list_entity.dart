import 'package:json_annotation/json_annotation.dart';

part 'student_data_confirm_list_entity.g.dart';

@JsonSerializable()
class StudentDataConfirmListEntity {
  late final int id;
  late int? studentId;
  late String? studentName;
  late String? activity;
  late String? description;
  late String createDate;

  StudentDataConfirmListEntity({
    required this.id,
    this.studentId,
    this.studentName,
    this.activity,
    this.description,
    required this.createDate,
  });

  factory StudentDataConfirmListEntity.fromJson(Map<String, dynamic> json) =>
      _$StudentDataConfirmListEntityFromJson(json);

  Map<String, dynamic> toJson() => _$StudentDataConfirmListEntityToJson(this);
}
