import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme.dart';

/// Side navigation drawer shared by all home screens.
class AppDrawer extends StatelessWidget {
  final UserRole role;

  const AppDrawer({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.person, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  role.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'OCEN — Trợ Lý Lịch Trình', // Schedule Assistant
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading:
                const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
            title: const Text('Lịch trình'), // Schedule
            onTap: () => Navigator.pop(context),
          ),

          if (role.canManageSchedules)
            ListTile(
              leading: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
              title: const Text('Thêm lịch mới'), // Add new schedule
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/add-schedule');
              },
            ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.red),
            title: const Text(
              'Đổi vai trò', // Switch role
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            ),
          ),

          const Spacer(),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'OCEN v1.0.0',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
