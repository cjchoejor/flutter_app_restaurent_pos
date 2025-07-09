class MenuModel {
  final String menuId;
  final String menuName;
  final String menuType;
  final String? subMenuType;
  final String price;
  final String description;
  final bool availability;
  final String? dishImage;
  final String uuid;
  final String? itemDestination;
  final String createdAt; // Add this field
  final String updatedAt; // Add this field

  MenuModel({
    required this.menuId,
    required this.menuName,
    required this.menuType,
    this.subMenuType,
    required this.price,
    required this.description,
    required this.availability,
    this.dishImage,
    required this.uuid,
    this.itemDestination,
    required this.createdAt, // Keep as required parameter
    required this.updatedAt, // Keep as required parameter
  });

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      menuId: map['menu_id'],
      menuName: map['menu_name'],
      menuType: map['menu_type'],
      subMenuType: map['sub_menu_type'],
      price: map['price'].toString(),
      description: map['description'],
      availability: map['availability'] == 1,
      dishImage: map['dish_image'],
      uuid: map['uuid'],
      itemDestination: map['item_destination'],
      createdAt:
          map['created_at'] ?? DateTime.now().toIso8601String(), // Add this
      updatedAt:
          map['updated_at'] ?? DateTime.now().toIso8601String(), // Add this
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menu_id': menuId,
      'menu_name': menuName,
      'menu_type': menuType,
      'sub_menu_type': subMenuType,
      'price': double.tryParse(price) ?? 0.0,
      'description': description,
      'availability': availability ? 1 : 0,
      'dish_image': dishImage,
      'uuid': uuid,
      'item_destination': itemDestination,
      'created_at': createdAt, // Add this
      'updated_at': updatedAt, // Add this
    };
  }

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      menuId: json['menu_id'],
      menuName: json['menu_name'],
      menuType: json['menu_type'],
      subMenuType: json['sub_menu_type'],
      price: json['price'].toString(),
      description: json['description'],
      availability: json['availability'] == true,
      dishImage: json['dish_image'],
      uuid: json['uuid'],
      itemDestination: json['item_destination'],
      createdAt:
          json['created_at'] ?? DateTime.now().toIso8601String(), // Add this
      updatedAt:
          json['updated_at'] ?? DateTime.now().toIso8601String(), // Add this
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_id': menuId,
      'menu_name': menuName,
      'menu_type': menuType,
      'sub_menu_type': subMenuType,
      'price': price,
      'description': description,
      'availability': availability,
      'dish_image': dishImage,
      'uuid': uuid,
      'item_destination': itemDestination,
      'created_at': createdAt, // Add this
      'updated_at': updatedAt, // Add this
    };
  }
}
