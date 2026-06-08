import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _categoryController = TextEditingController();
  
  // Curated premium color grid values
  final List<int> _colorPalette = [
    0xFF818CF8, // Indigo Accent
    0xFFF87171, // Red/Coral Accent
    0xFF34D399, // Emerald Accent
    0xFFF472B6, // Pink Accent
    0xFFFB7185, // Rose Accent
    0xFFFBBF24, // Amber Accent
    0xFFA78BFA, // Violet Accent
    0xFF22D3EE, // Cyan Accent
    0xFFFB923C, // Orange Accent
    0xFF9CA3AF, // Grey Accent
  ];

  late int _selectedColorVal;

  @override
  void initState() {
    super.initState();
    _selectedColorVal = _colorPalette.first;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  void _addCategory(TaskProvider provider) {
    final name = _categoryController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name cannot be empty!')),
      );
      return;
    }

    if (provider.categories.containsKey(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category already exists!')),
      );
      return;
    }

    provider.addCategory(name, _selectedColorVal);
    _categoryController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Category "$name" created!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'App Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Customize application preferences, categories, and system files.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // 1. Theme Configuration Card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Theme Preference',
            icon: Icons.palette_outlined,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark mode interface',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Use deep slate colors to save battery and reduce eye strain.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: provider.isDarkMode,
                  onChanged: (val) => provider.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1.5. Notification Alert Access Card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Notification Alert Access',
            icon: Icons.notifications_active_outlined,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Browser notifications',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Status: ${provider.notificationPermissionStatus.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: provider.notificationPermissionStatus == 'granted'
                              ? Colors.green
                              : (provider.notificationPermissionStatus == 'unsupported'
                                  ? Colors.grey
                                  : Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (provider.notificationPermissionStatus != 'granted' &&
                    provider.notificationPermissionStatus != 'unsupported')
                  ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await provider.requestNotificationPermission();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Permission status: ${provider.notificationPermissionStatus}',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Request Access'),
                  )
                else
                  Text(
                    provider.notificationPermissionStatus == 'granted'
                        ? 'Access Granted'
                        : 'Local Alerts Only',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1.8. Workspace Session settings card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Workspace Session',
            icon: Icons.account_circle_outlined,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logged in as',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                      Text(
                        provider.username ?? 'Guest User',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await provider.logout();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logged out of workspace session.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1.9. Client Profile Card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Client Information',
            icon: Icons.business_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Associated Client Name',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'This name represents the workspace client and is displayed on startup.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: provider.clientName ?? 'Default Client',
                        onFieldSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            provider.updateClientName(val.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Client name updated to "${val.trim()}"!'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Enter client name...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Category Configuration Card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Category Manager',
            icon: Icons.category_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // List existing categories
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.categories.length,
                  itemBuilder: (context, index) {
                    final catName = provider.categories.keys.elementAt(index);
                    final catColorVal = provider.categories.values.elementAt(index);
                    final catColor = Color(catColorVal);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkBg.withOpacity(0.3) : AppTheme.lightBg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                catName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                          // Prevent deleting 'Personal' as it's the mandatory fallback
                          if (catName != 'Personal')
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () {
                                _showDeleteCategoryConfirmation(context, provider, catName);
                              },
                              splashRadius: 20,
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'System Def',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                
                // Add new category interface
                Text(
                  'Create Custom Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          hintText: 'Enter category name...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _addCategory(provider),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Colors choices row
                const Text(
                  'Choose Color Theme Tag',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorPalette.map((colorVal) {
                    final isSelected = _selectedColorVal == colorVal;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColorVal = colorVal;
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: isDark ? Colors.white : Colors.black87,
                                  width: 2,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: _isLightColor(Color(colorVal)) ? Colors.black : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2.5. Supabase Setup & Security Card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Database & Security',
            icon: Icons.shield_outlined,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supabase SQL Setup',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Examine, copy, and run SQL commands to set up the backend database structure and Row-Level Security (RLS) policies.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showSupabaseSqlDialog(context),
                  icon: const Icon(Icons.code, size: 16),
                  label: const Text('View SQL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Danger Zone Card
          _buildSettingsSection(
            isDark: isDark,
            title: 'Danger Zone',
            icon: Icons.warning_amber_rounded,
            headerColor: Colors.redAccent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset application',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.redAccent),
                      ),
                      Text(
                        'Delete all saved tasks, custom categories, and reminders.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _showResetConfirmation(context, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // App Metadata Footer
          Center(
            child: Column(
              children: [
                Text(
                  'FocusFlow',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Text(
                  'v1.0.0 • Dart 3.11.5 • Flutter 3.41.9',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 6),
                Text(
                  'Running Cross-Platform Portability (Local Persistence)',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
    Color? headerColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassDecoration(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: headerColor ?? Colors.grey),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: headerColor ?? (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  bool _isLightColor(Color color) {
    // Basic luminance check
    return color.computeLuminance() > 0.6;
  }

  void _showDeleteCategoryConfirmation(BuildContext context, TaskProvider provider, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete the "$categoryName" category?\n\nAny tasks currently in this category will be re-assigned to your first available category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteCategory(categoryName);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Category "$categoryName" removed.')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Everything?'),
        content: const Text(
          'WARNING: This action is permanent! It will completely clear all tasks, custom categories, settings, and reminders from local database storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.resetApp();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App data reset successful!'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }

  void _showSupabaseSqlDialog(BuildContext context) {
    const String sqlText = '''-- FocusFlow Supabase Setup & Security Configuration Script
-- Copy and run this script in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. Enable UUID extension for auto-generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    due_date TIMESTAMP WITH TIME ZONE,
    priority TEXT DEFAULT 'medium',
    category TEXT DEFAULT 'Personal',
    tags TEXT[] DEFAULT '{}',
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    reminders TIMESTAMP WITH TIME ZONE[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create categories table
CREATE TABLE IF NOT EXISTS public.categories (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    color BIGINT NOT NULL,
    PRIMARY KEY (user_id, name)
);

-- 4. Enable Row Level Security (RLS) on both tables (Crucial for data security)
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- 5. Row Level Security Policies for 'tasks' Table
CREATE POLICY "Users can only view their own tasks" 
ON public.tasks FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert their own tasks" 
ON public.tasks FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only update their own tasks" 
ON public.tasks FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only delete their own tasks" 
ON public.tasks FOR DELETE 
USING (auth.uid() = user_id);

-- 6. Row Level Security Policies for 'categories' Table
CREATE POLICY "Users can only view their own categories" 
ON public.categories FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert their own categories" 
ON public.categories FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only update their own categories" 
ON public.categories FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can only delete their own categories" 
ON public.categories FOR DELETE 
USING (auth.uid() = user_id);

-- 7. Performance Optimization Indexes
CREATE INDEX IF NOT EXISTS tasks_user_id_idx ON public.tasks(user_id);
CREATE INDEX IF NOT EXISTS categories_user_id_idx ON public.categories(user_id);

-- 8. Schema Updates (Migration support for existing tables)
-- Adds the completed_at column to tasks table if it doesn't already exist
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.shield, color: Colors.tealAccent, size: 24),
                SizedBox(width: 8),
                Text('Supabase SQL Script', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy the SQL commands below, paste them into your Supabase project SQL Editor, and execute them to construct the required tables and secure them using Row Level Security (RLS).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: const SingleChildScrollView(
                    child: Text(
                      sqlText,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: sqlText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SQL Script copied to clipboard!'),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
