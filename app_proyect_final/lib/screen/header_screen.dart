import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class HeaderScreen extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final Map<String, dynamic>? user;

  const HeaderScreen({
    super.key,
    this.title = 'CRM-Ecommerce',
    this.showBackButton = false,
    required this.user,
  });

  @override
  State<HeaderScreen> createState() => _HeaderScreenState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HeaderScreenState extends State<HeaderScreen> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool isHoveringProfile = false;

  void _toggleMenu() {
    if (_overlayEntry == null) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  void _showMenu() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: position.dy + kToolbarHeight + 8,
          left: position.dx + MediaQuery.of(context).size.width - 72 - 220,
          child: CompositedTransformFollower(
            link: _layerLink,
            offset: const Offset(-180, 40),
            showWhenUnlinked: false,
            child: _buildMenu(),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _hideMenu();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _navigate(String route) {
    _hideMenu();
    Navigator.pushNamed(context, route);
  }

  Widget _buildMenu() {
    final user = widget.user ?? {};

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (user['first_name']?.toString().trim().isNotEmpty ?? false)
                        ? '${user['first_name']} ${user['last_name'] ?? ''}'
                        : user['username'] ?? 'Usuario',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Text(
                    user['email'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ...[
              _menuItem(
                'Editar Perfil',
                FontAwesomeIcons.userCircle,
                '/user-profile',
              ),
              const Divider(),
              _menuItem(
                'Cerrar Sesión',
                FontAwesomeIcons.signOutAlt,
                null,
                isLogout: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    String label,
    IconData icon,
    String? route, {
    bool isLogout = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (route != null) {
            _navigate(route);
          } else {
            _logout();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isLogout ? Colors.red : Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isLogout ? Colors.red : Colors.grey[800],
                    fontWeight: isLogout ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? {};

    return SafeArea(
      child: Material(
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (widget.showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => isHoveringProfile = true),
                onExit: (_) => setState(() => isHoveringProfile = false),
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isHoveringProfile
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                      ),
                      child:
                          user['profile_picture'] != null
                              ? CircleAvatar(
                                radius: 18,
                                backgroundImage: NetworkImage(
                                  '${mediaUrl}${user['profile_picture']}',
                                ),
                              )
                              : const Icon(
                                FontAwesomeIcons.userCircle,
                                size: 28,
                                color: Colors.grey,
                              ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
