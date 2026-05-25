import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme.dart';

/// First screen — user picks their role to enter the correct home screen.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              const Spacer(),

              // Logo + title
              const Icon(
                Icons.calendar_month_rounded,
                size: 80,
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              const Text(
                'OCEN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Trợ Lý Lịch Trình', // Schedule Assistant
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 16,
                ),
              ),

              const Spacer(),

              Text(
                'Chọn vai trò của bạn', // Select your role
                style: TextStyle(
                  color: Colors.white.withAlpha(178),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Role cards
              _RoleCard(
                role: UserRole.executive,
                icon: Icons.business_center_rounded,
                onTap: () => Navigator.pushNamed(context, '/executive'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: UserRole.secretary,
                icon: Icons.edit_calendar_rounded,
                onTap: () => Navigator.pushNamed(context, '/staff'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                role: UserRole.driver,
                icon: Icons.drive_eta_rounded,
                onTap: () => Navigator.pushNamed(context, '/staff'),
              ),

              const Spacer(),
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
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(26),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.accent.withAlpha(77),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border:
                Border.all(color: Colors.white.withAlpha(51)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.accent, size: 28),
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
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      role.englishName,
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
