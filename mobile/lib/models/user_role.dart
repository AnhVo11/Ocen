/// Roles that can interact with the OCEN bot.
enum UserRole {
  executive, // Giám Đốc — read-only, receives reminders
  secretary, // Thư Ký   — can add / manage schedules
  driver; // Tài Xế    — can add / manage schedules

  /// Vietnamese display name shown in the UI.
  String get displayName {
    switch (this) {
      case UserRole.executive:
        return 'Giám Đốc';
      case UserRole.secretary:
        return 'Thư Ký';
      case UserRole.driver:
        return 'Tài Xế';
    }
  }

  /// English name shown as a subtitle on the role-select screen.
  String get englishName {
    switch (this) {
      case UserRole.executive:
        return 'Executive';
      case UserRole.secretary:
        return 'Secretary';
      case UserRole.driver:
        return 'Driver';
    }
  }

  /// Whether this role can create or edit schedules.
  bool get canManageSchedules => this != UserRole.executive;
}
