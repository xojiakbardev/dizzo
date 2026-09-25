import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_badge.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String Function(AppLocalizations l) label;
  final IconData icon;
  final IconData selectedIcon;
}

String _home(AppLocalizations l) => l.navHome;
String _products(AppLocalizations l) => l.navProducts;
String _designs(AppLocalizations l) => l.navDesigns;
String _cart(AppLocalizations l) => l.navCart;
String _profile(AppLocalizations l) => l.navProfile;

const _tabs = [
  _Tab(_home, Icons.home_outlined, Icons.home_rounded),
  _Tab(_products, Icons.grid_view_outlined, Icons.grid_view_rounded),
  _Tab(_designs, Icons.brush_outlined, Icons.brush_rounded),
  _Tab(_cart, Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
  _Tab(_profile, Icons.person_outline_rounded, Icons.person_rounded),
];

/// Index of the Savat tab (for the badge).
const _cartTab = 3;

/// The tab scaffold: a bottom [NavigationBar] on phones, a
/// [NavigationRail] from the medium breakpoint (tablets, landscape).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) {
    if (index != shell.currentIndex) HapticFeedback.selectionClick();
    // Re-tapping the current tab returns to its first page.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);

    Widget icon(int i, {required bool selected}) {
      final data = Icon(selected ? _tabs[i].selectedIcon : _tabs[i].icon);
      if (i != _cartTab || count <= 0) return data;
      return Badge.count(count: count, child: data);
    }

    if (context.isCompact) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (var i = 0; i < _tabs.length; i++)
              NavigationDestination(
                icon: icon(i, selected: false),
                selectedIcon: icon(i, selected: true),
                label: _tabs[i].label(context.l10n),
                tooltip: '',
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.85,
              leading: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Image.asset('assets/brand/dizzo-mark.png', width: 36, height: 36),
              ),
              destinations: [
                for (var i = 0; i < _tabs.length; i++)
                  NavigationRailDestination(
                    icon: icon(i, selected: false),
                    selectedIcon: icon(i, selected: true),
                    label: Text(_tabs[i].label(context.l10n)),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.colors.line),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
