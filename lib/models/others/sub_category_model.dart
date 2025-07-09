class SubcategoryModel {
  final String subcategoryId;
  final String subcategoryName;
  final String categoryId;
  final String status;
  final int sortOrder;

  SubcategoryModel({
    required this.subcategoryId,
    required this.subcategoryName,
    required this.categoryId,
    required this.status,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'subcategoryId': subcategoryId,
      'subcategoryName': subcategoryName,
      'categoryId': categoryId,
      'status': status,
      'sortOrder': sortOrder,
    };
  }

  factory SubcategoryModel.fromMap(Map<String, dynamic> map) {
    return SubcategoryModel(
      subcategoryId: map['subcategoryId'] ?? '',
      subcategoryName: map['subcategoryName'] ?? '',
      categoryId: map['categoryId'] ?? '',
      status: map['status'] ?? '',
      sortOrder:
          map['sortOrder'] ?? 0, // Fixed: provide default value instead of null
    );
  }
}
