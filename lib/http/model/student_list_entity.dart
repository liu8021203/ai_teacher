import 'package:json_annotation/json_annotation.dart';

part 'student_list_entity.g.dart';

@JsonSerializable()
class StudentListEntity {
  late int id;
  late String studentName;
  String? studentNickName;
  String? phone;
  String? studentAvatar;
  late int studentSex;
  late String studentBirthday;

  StudentListEntity({
    required this.id,
    required this.studentName,
    this.studentNickName,
    this.phone,
    this.studentAvatar,
    required this.studentSex,
    required this.studentBirthday,
  });

  factory StudentListEntity.fromJson(Map<String, dynamic> json) => _$StudentListEntityFromJson(json);

  Map<String, dynamic> toJson() => _$StudentListEntityToJson(this);
}
