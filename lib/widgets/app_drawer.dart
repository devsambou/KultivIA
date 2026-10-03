// Menu latéral (drawer). Issue GitHub : C5
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../services/data/conversation_history.dart';
import '../services/system/app_state.dart';
import '../services/auth/firebase_service.dart';

/// Nombre de conversations listées dans le tiroir.
///
/// Au-delà, il faudrait un écran dédié ; six entrées suffisent à retrouver un
/// échange récent sans transformer le tiroir en annuaire.
const int _maxListedConversations = 6;

/// Menu latéral : donne accès à tous les écrans depuis la conversation, et
/// permet de rouvrir une discussion passée.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onNewChat, this.onOpenConversation});

  final VoidCallback onNewChat;

  /// `null` quand l'historique des discussions n'est pas câblé : la section est
  /// alors simplement absente, le reste du tiroir fonctionne pareil.
  final ValueChanged<Conversation>? onOpenConversation;

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  Widget _item(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => _go(context, route),
    );
  }

  /// Libellé temporel court : « Aujourd'hui 14 h », « Hier », « il y a 4 jours »…
  ///
  /// Une date dans le futur (décalage d'horloge entre le téléphone et le
  /// serveur) retombe sur la date chiffrée plutôt que d'afficher « il y a
  /// -1 jours ».
  static String _when(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;

    if (days == 0) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return "Aujourd'hui $h:$m";
    }
    if (days == 1) return 'Hier';
    if (days > 1 && days < 7) return 'Il y a $days jours';

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Les discussions récentes, à réouvrir en un geste.
  ///
  /// Renvoie une liste vide quand aucune n'existe ou que l'historique n'est pas
  /// câblé : le tiroir affiche alors exactement ce qu'il affichait avant.
  List<Widget> _conversationTiles(BuildContext context) {
    final open = onOpenConversation;
    if (open == null) return const [];

    final history = context.watch<ConversationHistory>();
    final recent = history.conversations.take(_maxListedConversations).toList();

    if (recent.isEmpty) return const [];

    final cs = Theme.of(context).colorScheme;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          'DISCUSSIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
      for (final conversation in recent)
        ListTile(
          dense: true,
          leading: const Icon(Icons.forum_outlined, size: 20),
          title: Text(
            // `displayTitle` et non `title` : une conversation enregistrée
            // avant son premier message n'a pas encore de titre, et le tiroir
            // afficherait une ligne vide à la place.
            conversation.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(_when(conversation.updatedAt), style: const TextStyle(fontSize: 12)),
          onTap: () {
            Navigator.pop(context);
            open(conversation);
          },
        ),
      const Divider(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    final user = context.read<FirebaseService>().currentUser;
    final authPhoto = user?.photoURL;
    final profilePhoto = profile?.photoUrl;
    final name = profile?.displayName.trim() ?? user?.displayName ?? 'Utilisateur';
    final locality = profile?.locality ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    final String? photo = (profilePhoto != null && profilePhoto.isNotEmpty)
        ? profilePhoto
        : (authPhoto != null && authPhoto.isNotEmpty ? authPhoto : null);

    return Drawer(
      child: Column(
        children: [
          // En haut : profil cliquable
          InkWell(
            onTap: () => _go(context, '/profile'),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, mq.padding.top + 16, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (locality.isNotEmpty)
                          Text(
                            locality,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),

          // Entrées du menu
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Nouvelle conversation'),
                  onTap: () {
                    Navigator.pop(context);
                    onNewChat();
                  },
                ),
                ..._conversationTiles(context),
                _item(context, Icons.history, 'Historique des diagnostics', '/history'),
                _item(context, Icons.health_and_safety_outlined,
                    'Santé exploitation', '/health-dashboard'),
                _item(context, Icons.cloud_outlined, 'Alertes météo', '/weather'),
                _item(context, Icons.store_outlined,
                    'Points de vente d\'intrants', '/vendors'),
                _item(context, Icons.people_outline, 'Communauté', '/community'),
                _item(context, Icons.storefront_outlined, 'Marketplace',
                    '/marketplace'),
                const Divider(),
                _item(context, Icons.settings, 'Paramètres', '/settings'),
              ],
            ),
          ),

          // En bas : logo seul
          Container(
            width: double.infinity,
            color: cs.primary,
            padding: EdgeInsets.fromLTRB(16, 16, 16, mq.padding.bottom + 16),
            child: Center(
              child: Image.asset(
                'assets/icon/icon.png',
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}