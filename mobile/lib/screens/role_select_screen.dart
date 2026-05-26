import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),

              // ── Brand ────────────────────────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'OCEN',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Trợ lý lịch trình thông minh',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(flex: 2),

              // ── Role label ────────────────────────────────────────────────
              const Text(
                'Chọn vai trò',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // ── Cards ────────────────────────────────────────────────────
              _RoleCard(
                role: UserRole.executive,
                icon: Icons.business_center_rounded,
                subtitle: 'Xem & quản lý lịch cá nhân',
                onTap: () => Navigator.pushNamed(context, '/executive'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: UserRole.secretary,
                icon: Icons.edit_calendar_rounded,
                subtitle: 'Thêm và chỉnh sửa lịch',
                onTap: () => Navigator.pushNamed(context, '/staff'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: UserRole.driver,
                icon: Icons.drive_eta_rounded,
                subtitle: 'Xem lịch di chuyển',
                onTap: () => Navigator.pushNamed(context, '/staff'),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.cardSecondary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
