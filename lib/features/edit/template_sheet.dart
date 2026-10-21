import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/templates.dart';

/// Returned when the user picks "Custom" rather than a service.
const customTemplate = Template('', 'Other', 0xFF4F46E5, '');

/// Popular services to start from, plus a custom entry.
Future<Template?> showTemplateSheet(BuildContext context) => showModalBottomSheet<Template>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .7,
    maxChildSize: .92,
    builder: (context, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text('Add a subscription', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Icon(Icons.edit_outlined),
            ),
            title: const Text('Custom', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Anything you pay for regularly'),
            onTap: () => Navigator.pop(context, customTemplate),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Popular', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .95,
          children: [
            for (final t in templates)
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.pop(context, t),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(t.color),
                          foregroundColor: Colors.white,
                          child: Text(t.name[0], style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  ),
);
