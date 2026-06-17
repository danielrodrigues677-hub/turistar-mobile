import 'firestore_schema.dart';
import 'main.dart';

/// Backoffice access matrix. [TuristarRole.agent] is displayed as Consultor.
class AdminPermissions {
  const AdminPermissions._();

  static String roleLabel(String role) {
    switch (role) {
      case TuristarRole.admin:
        return 'Admin';
      case TuristarRole.agent:
        return 'Consultor';
      case TuristarRole.operacional:
        return 'Operacional';
      case TuristarRole.customer:
        return 'Cliente';
      default:
        return role;
    }
  }

  static bool isStaff(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.agent || role == TuristarRole.operacional;

  static bool canOpenPanel(String? role) => isStaff(role);

  static bool canAccessDashboard(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.agent;

  static bool canAccessClients(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.agent;

  static bool canAccessRequests(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.agent;

  static bool canAccessPackages(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.agent;

  static bool canAccessFeaturedPackages(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.agent;

  static bool canAccessBanners(String? role) => role == TuristarRole.admin || role == TuristarRole.agent;

  static bool canAccessBookings(String? role) =>
      role == TuristarRole.admin || role == TuristarRole.operacional;

  static bool canManageRoles(String? role) => role == TuristarRole.admin;

  static bool canDeleteRecords(String? role) => role == TuristarRole.admin;

  static List<String> assignableRoles() => [
        TuristarRole.admin,
        TuristarRole.agent,
        TuristarRole.operacional,
        TuristarRole.customer,
      ];

  static void requireStaff() {
    if (!TuristarAuth.hasAnyRole([TuristarRole.admin, TuristarRole.agent, TuristarRole.operacional])) {
      throw const AuthException('permission-denied', 'Acesso restrito a equipe Turistar.');
    }
  }

  static void requireConsultorOrAdmin() {
    if (!TuristarAuth.hasAnyRole([TuristarRole.admin, TuristarRole.agent])) {
      throw const AuthException('permission-denied', 'Acesso restrito a consultores e administradores.');
    }
  }
}
