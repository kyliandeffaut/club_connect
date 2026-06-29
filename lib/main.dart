import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:math';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ClubConnectApp());
}

class ClubConnectApp extends StatelessWidget {
  const ClubConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClubConnect',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101012),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ══════════════════════════════════════════
// UTILITAIRES
// ══════════════════════════════════════════
String generateClubCode() {
  const words = ['WOLF', 'BULL', 'HAWK', 'LION', 'BEAR', 'LYNX', 'FOX', 'PUMA'];
  final rng = Random();
  return '${words[rng.nextInt(words.length)]}-${rng.nextInt(9000) + 1000}';
}

String formatDate(String iso) {
  try {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return iso;
  }
}

String formatTime(String iso) {
  try {
    final d = DateTime.parse(iso);
    return '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

// ══════════════════════════════════════════
// AUTH GATE
// ══════════════════════════════════════════
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnapshot.hasData) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role'] as String?;
            if (role == null || role == 'pending') return const ClubSelectionScreen();
            return const MainShell();
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// LOGIN SCREEN
// ══════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'pending',
          'clubId': null,
          'avatarColor': Random().nextInt(0xFFFFFF) + 0xFF000000,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Erreur'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.shield_rounded, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text('ClubConnect', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_isLogin ? 'Connecte-toi à ton club' : 'Crée ton compte', style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 40),
              if (!_isLogin)
                _field(_nameController, 'Nom complet', Icons.person_outline),
              _field(_emailController, 'Email', Icons.email_outlined),
              _field(_passwordController, 'Mot de passe', Icons.lock_outline, obscure: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(_isLogin ? 'SE CONNECTER' : "S'INSCRIRE",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Pas de compte ? S'inscrire" : 'Déjà un compte ? Se connecter',
                    style: const TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// CLUB SELECTION SCREEN
// ══════════════════════════════════════════
class ClubSelectionScreen extends StatefulWidget {
  const ClubSelectionScreen({super.key});
  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> {
  final _codeController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _sportController = TextEditingController();
  final _cityController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createClub() async {
    if (_clubNameController.text.trim().isEmpty) {
      _showError('Donne un nom à ton club.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;
      String clubCode;
      bool codeExists = true;
      do {
        clubCode = generateClubCode();
        final existing = await db.collection('clubs').where('clubCode', isEqualTo: clubCode).limit(1).get();
        codeExists = existing.docs.isNotEmpty;
      } while (codeExists);

      final clubRef = await db.collection('clubs').add({
        'name': _clubNameController.text.trim(),
        'sport': _sportController.text.trim(),
        'city': _cityController.text.trim(),
        'description': _descController.text.trim(),
        'clubCode': clubCode,
        'adminId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'channels': ['Général', 'Compétiteurs', 'Loisirs'],
      });

      await db.collection('users').doc(user.uid).update({
        'role': 'manager',
        'clubId': clubRef.id,
      });
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinClub() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) { _showError("Entre un code d'invitation."); return; }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;
      final result = await db.collection('clubs').where('clubCode', isEqualTo: code).limit(1).get();
      if (result.docs.isEmpty) {
        _showError('Code invalide. Vérifie auprès de ton coach.');
        setState(() => _isLoading = false);
        return;
      }
      await db.collection('users').doc(user.uid).update({
        'role': 'player',
        'clubId': result.docs.first.id,
      });
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Bienvenue 👋', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Colors.blueAccent,
            tabs: [Tab(text: 'CRÉER UN CLUB'), Tab(text: 'REJOINDRE')],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_buildCreate(), _buildJoin()]),
      ),
    );
  }

  Widget _buildCreate() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu es coach ou admin ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Crée ton club et partage le code à tes joueurs.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 32),
        _field(_clubNameController, 'Nom du club *', Icons.shield_outlined),
        _field(_sportController, 'Sport (ex: Badminton)', Icons.sports_tennis),
        _field(_cityController, 'Ville', Icons.location_city),
        _field(_descController, 'Description du club', Icons.info_outline, maxLines: 3),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _createClub,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text('CRÉER MON CLUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildJoin() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu es joueur ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Entre le code que ton coach t'a communiqué.", style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: "Code (ex: WOLF-4829)",
            prefixIcon: const Icon(Icons.key_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.15),
              side: const BorderSide(color: Colors.greenAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _joinClub,
            icon: const Icon(Icons.login, color: Colors.greenAccent),
            label: const Text('REJOINDRE LE CLUB', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: maxLines == 1 ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// MAIN SHELL (Navigation principale)
// ══════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Map<String, dynamic>? _userData;
  String? _clubId;
  String? _role;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        _userData = snap.data!.data() as Map<String, dynamic>;
        _clubId = _userData!['clubId'] as String?;
        _role = _userData!['role'] as String? ?? 'player';

        final isManager = _role == 'manager';
        final screens = [
          HomeTab(clubId: _clubId!, userData: _userData!, isManager: isManager),
          EventsTab(clubId: _clubId!, userData: _userData!, isManager: isManager),
          MessagingTab(clubId: _clubId!),
          MembersTab(clubId: _clubId!, isManager: isManager),
          SettingsTab(clubId: _clubId!, userData: _userData!, isManager: isManager),
        ];

        return Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: const Color(0xFF18181B),
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Événements'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
              BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Membres'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Paramètres'),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 1 — ACCUEIL
// ══════════════════════════════════════════
class HomeTab extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;
  final bool isManager;
  const HomeTab({super.key, required this.clubId, required this.userData, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bonjour, ${(userData['name'] as String? ?? 'Joueur').split(' ').first} 👋',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(isManager ? '⚡ Manager' : '🏃 Joueur', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
            CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: Text((userData['name'] as String? ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 24),

          // Info club
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              final club = snap.data!.data() as Map<String, dynamic>;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(club['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  if ((club['sport'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('${club['sport']} · ${club['city'] ?? ''}', style: const TextStyle(color: Colors.white54)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.key, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('Code : ${club['clubCode'] ?? ''}',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ]),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 24),

          // Prochain événement
          const Text('Prochain événement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .where('clubId', isEqualTo: clubId)
                .orderBy('startDate')
                .limit(1)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Aucun événement à venir.', style: TextStyle(color: Colors.white54)),
                );
              }
              final data = snap.data!.docs.first.data() as Map<String, dynamic>;
              final eventId = snap.data!.docs.first.id;
              final attendees = data['attendees'] as List? ?? [];
              final amIPresent = attendees.contains(uid);
              return _EventMiniCard(data: data, eventId: eventId, attendees: attendees, amIPresent: amIPresent, uid: uid);
            },
          ),
          const SizedBox(height: 24),

          // Stats rapides
          const Text('Aperçu du club', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('clubId', isEqualTo: clubId).snapshots(),
            builder: (context, snap) {
              final memberCount = snap.data?.docs.length ?? 0;
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('events').where('clubId', isEqualTo: clubId).snapshots(),
                builder: (context, evSnap) {
                  final eventCount = evSnap.data?.docs.length ?? 0;
                  return Row(children: [
                    _StatCard(icon: Icons.group, label: 'Membres', value: '$memberCount', color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    _StatCard(icon: Icons.calendar_month, label: 'Événements', value: '$eventCount', color: Colors.pinkAccent),
                  ]);
                },
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _EventMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId, uid;
  final List attendees;
  final bool amIPresent;
  const _EventMiniCard({required this.data, required this.eventId, required this.attendees, required this.amIPresent, required this.uid});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'Autre';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (type == 'Match' ? Colors.pinkAccent : Colors.blueAccent).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(type == 'Match' ? Icons.emoji_events : Icons.fitness_center,
              color: type == 'Match' ? Colors.pinkAccent : Colors.blueAccent),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${formatDate(data['startDate'] ?? '')} · ${formatTime(data['startDate'] ?? '')}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(data['location'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ])),
        GestureDetector(
          onTap: () {
            final ref = FirebaseFirestore.instance.collection('events').doc(eventId);
            if (amIPresent) {
              ref.update({'attendees': FieldValue.arrayRemove([uid])});
            } else {
              ref.update({'attendees': FieldValue.arrayUnion([uid])});
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: amIPresent ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: amIPresent ? Colors.greenAccent : Colors.white24),
            ),
            child: Text(amIPresent ? '✓ Présent' : 'Répondre',
                style: TextStyle(fontSize: 12, color: amIPresent ? Colors.greenAccent : Colors.white54,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 2 — ÉVÉNEMENTS
// ══════════════════════════════════════════
class EventsTab extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;
  final bool isManager;
  const EventsTab({super.key, required this.clubId, required this.userData, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Événements', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: isManager
            ? [IconButton(icon: const Icon(Icons.add_circle, color: Colors.pinkAccent, size: 28),
                onPressed: () => showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  backgroundColor: const Color(0xFF1C1C1E),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (_) => CreateEventSheet(clubId: clubId),
                ))]
            : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_today, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text('Aucun événement prévu.', style: TextStyle(color: Colors.white54)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final doc = snap.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final attendees = data['attendees'] as List? ?? [];
              final amIPresent = attendees.contains(uid);
              return _EventCard(data: data, eventId: doc.id, attendees: attendees, amIPresent: amIPresent,
                  uid: uid, isManager: isManager);
            },
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId, uid;
  final List attendees;
  final bool amIPresent, isManager;
  const _EventCard({required this.data, required this.eventId, required this.attendees,
      required this.amIPresent, required this.uid, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'Autre';
    final isMatch = type == 'Match';
    final color = isMatch ? Colors.pinkAccent : Colors.blueAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        // Header coloré
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(isMatch ? Icons.emoji_events : Icons.fitness_center, color: color, size: 18),
              const SizedBox(width: 8),
              Text(type.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            Row(children: [
              const Icon(Icons.people, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text('${attendees.length}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              if (isManager) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1C1C1E),
                      title: const Text("Supprimer l'événement ?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ));
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
                    }
                  },
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                ),
              ],
            ]),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today, '${formatDate(data['startDate'] ?? '')} · ${formatTime(data['startDate'] ?? '')} → ${formatTime(data['endDate'] ?? '')}'),
            _infoRow(Icons.location_on, data['location'] ?? 'À définir'),
            if ((data['description'] as String? ?? '').isNotEmpty)
              _infoRow(Icons.info_outline, data['description']),
            if ((data['recurrence'] as String? ?? 'Aucune') != 'Aucune')
              _infoRow(Icons.repeat, data['recurrence']),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: amIPresent ? Colors.white10 : Colors.greenAccent.withOpacity(0.15),
                  side: BorderSide(color: amIPresent ? Colors.white24 : Colors.greenAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final ref = FirebaseFirestore.instance.collection('events').doc(eventId);
                  if (amIPresent) {
                    ref.update({'attendees': FieldValue.arrayRemove([uid])});
                  } else {
                    ref.update({'attendees': FieldValue.arrayUnion([uid])});
                  }
                },
                child: Text(amIPresent ? '✗  JE SERAI ABSENT' : '✓  JE SERAI PRÉSENT',
                    style: TextStyle(color: amIPresent ? Colors.white38 : Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13))),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// SHEET — CRÉER UN ÉVÉNEMENT
// ══════════════════════════════════════════
class CreateEventSheet extends StatefulWidget {
  final String clubId;
  const CreateEventSheet({super.key, required this.clubId});
  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'Entraînement';
  String _recurrence = 'Aucune';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 2));
  bool _loading = false;

  Future<void> _pickStart() async {
    final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startDate));
    if (time == null) return;
    setState(() => _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(context: context, initialDate: _endDate, firstDate: _startDate, lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endDate));
    if (time == null) return;
    setState(() => _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('events').add({
      'title': _titleController.text.trim(),
      'type': _type,
      'location': _locationController.text.trim(),
      'description': _descController.text.trim(),
      'startDate': _startDate.toIso8601String(),
      'endDate': _endDate.toIso8601String(),
      'recurrence': _recurrence,
      'attendees': [],
      'clubId': widget.clubId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Nouvel événement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Titre *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white.withOpacity(0.05)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _typeChip('Entraînement', Icons.fitness_center, Colors.blueAccent)),
            const SizedBox(width: 10),
            Expanded(child: _typeChip('Match', Icons.emoji_events, Colors.pinkAccent)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateTile('Début', _startDate, _pickStart)),
            const SizedBox(width: 10),
            Expanded(child: _dateTile('Fin', _endDate, _pickEnd)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(labelText: 'Lieu', prefixIcon: const Icon(Icons.location_on), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white.withOpacity(0.05)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white.withOpacity(0.05)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _recurrence,
            decoration: InputDecoration(labelText: 'Récurrence', prefixIcon: const Icon(Icons.repeat), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white.withOpacity(0.05)),
            items: ['Aucune', 'Hebdomadaire', 'Bimensuelle', 'Mensuelle']
                .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _recurrence = v!),
            dropdownColor: const Color(0xFF1C1C1E),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('CRÉER L\'ÉVÉNEMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _typeChip(String label, IconData icon, Color color) {
    final selected = _type == label;
    return GestureDetector(
      onTap: () => setState(() => _type = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? color : Colors.white38, size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: selected ? color : Colors.white38, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _dateTile(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
          Text(formatDate(dt.toIso8601String()), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(formatTime(dt.toIso8601String()), style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 3 — MESSAGERIE
// ══════════════════════════════════════════
class MessagingTab extends StatefulWidget {
  final String clubId;
  const MessagingTab({super.key, required this.clubId});
  @override
  State<MessagingTab> createState() => _MessagingTabState();
}

class _MessagingTabState extends State<MessagingTab> {
  String _selectedChannel = 'Général';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final club = snap.data!.data() as Map<String, dynamic>;
          final channels = (club['channels'] as List?)?.cast<String>() ?? ['Général'];

          return Column(children: [
            // Sélecteur de canaux
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: channels.length,
                itemBuilder: (context, i) {
                  final ch = channels[i];
                  final selected = ch == _selectedChannel;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedChannel = ch),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('# $ch', style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: ChatView(clubId: widget.clubId, channel: _selectedChannel)),
          ]);
        },
      ),
    );
  }
}

class ChatView extends StatefulWidget {
  final String clubId, channel;
  const ChatView({super.key, required this.clubId, required this.channel});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser!;
    final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = (userData.data() as Map<String, dynamic>)['name'] ?? 'Joueur';
    _msgController.clear();
    await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('messages').add({
      'text': text,
      'senderId': user.uid,
      'senderName': name,
      'channel': widget.channel,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Column(children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubs').doc(widget.clubId)
              .collection('messages')
              .where('channel', isEqualTo: widget.channel)
              .orderBy('sentAt')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            });
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final msg = docs[i].data() as Map<String, dynamic>;
                final isMe = msg['senderId'] == uid;
                return _MessageBubble(msg: msg, isMe: isMe);
              },
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(color: const Color(0xFF18181B), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Message #${widget.channel}...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blueAccent.withOpacity(0.3),
              child: Text((msg['senderName'] as String? ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (!isMe)
                Padding(padding: const EdgeInsets.only(bottom: 2),
                    child: Text(msg['senderName'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blueAccent : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(msg['text'] ?? '', style: const TextStyle(fontSize: 14)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 4 — MEMBRES
// ══════════════════════════════════════════
class MembersTab extends StatelessWidget {
  final String clubId;
  final bool isManager;
  const MembersTab({super.key, required this.clubId, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Membres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('clubId', isEqualTo: clubId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          final managers = docs.where((d) => (d.data() as Map)['role'] == 'manager').toList();
          final players = docs.where((d) => (d.data() as Map)['role'] == 'player').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('Staff', managers.length),
              ...managers.map((d) => _MemberTile(data: d.data() as Map<String, dynamic>, isManager: isManager, docId: d.id)),
              const SizedBox(height: 16),
              _sectionHeader('Joueurs', players.length),
              ...players.map((d) => _MemberTile(data: d.data() as Map<String, dynamic>, isManager: isManager, docId: d.id)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isManager;
  final String docId;
  const _MemberTile({required this.data, required this.isManager, required this.docId});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Joueur';
    final role = data['role'] as String? ?? 'player';
    final isCurrentUser = docId == FirebaseAuth.instance.currentUser!.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrentUser ? Colors.blueAccent.withOpacity(0.4) : Colors.white10),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: (role == 'manager' ? Colors.pinkAccent : Colors.blueAccent).withOpacity(0.2),
          child: Text(name[0].toUpperCase(),
              style: TextStyle(color: role == 'manager' ? Colors.pinkAccent : Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Moi', style: TextStyle(color: Colors.blueAccent, fontSize: 10))),
            ],
          ]),
          Text(data['email'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (role == 'manager' ? Colors.pinkAccent : Colors.blueAccent).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(role == 'manager' ? 'Manager' : 'Joueur',
              style: TextStyle(color: role == 'manager' ? Colors.pinkAccent : Colors.blueAccent,
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// ONGLET 5 — PARAMÈTRES
// ══════════════════════════════════════════
class SettingsTab extends StatelessWidget {
  final String clubId;
  final Map<String, dynamic> userData;
  final bool isManager;
  const SettingsTab({super.key, required this.clubId, required this.userData, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final club = snap.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profil utilisateur
              _SettingsSection(title: 'Mon profil', children: [
                _InfoTile(label: 'Nom', value: userData['name'] ?? ''),
                _InfoTile(label: 'Email', value: userData['email'] ?? ''),
                _InfoTile(label: 'Rôle', value: isManager ? 'Manager' : 'Joueur'),
              ]),
              const SizedBox(height: 16),

              // Infos club
              _SettingsSection(title: 'Mon club', children: [
                _InfoTile(label: 'Nom', value: club['name'] ?? ''),
                _InfoTile(label: 'Sport', value: club['sport'] ?? ''),
                _InfoTile(label: 'Ville', value: club['city'] ?? ''),
                // Code d'invitation mis en avant
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Code d'invitation", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(club['clubCode'] ?? '', style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
                    ]),
                    const Icon(Icons.copy, color: Colors.amber),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),

              // Gestion club (manager only)
              if (isManager) ...[
                _SettingsSection(title: 'Gestion du club', children: [
                  _ActionTile(
                    icon: Icons.edit,
                    label: 'Modifier les infos du club',
                    onTap: () => showModalBottomSheet(
                      context: context, isScrollControlled: true,
                      backgroundColor: const Color(0xFF1C1C1E),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => EditClubSheet(clubId: clubId, clubData: club),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
              ],

              // Déconnexion
              _SettingsSection(title: 'Compte', children: [
                _ActionTile(
                  icon: Icons.logout,
                  label: 'Se déconnecter',
                  color: Colors.redAccent,
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
      Container(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
        child: Column(children: children),
      ),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 18),
        ]),
      ),
    );
  }
}

// Sheet — Modifier le club
class EditClubSheet extends StatefulWidget {
  final String clubId;
  final Map<String, dynamic> clubData;
  const EditClubSheet({super.key, required this.clubId, required this.clubData});
  @override
  State<EditClubSheet> createState() => _EditClubSheetState();
}

class _EditClubSheetState extends State<EditClubSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _sportController;
  late final TextEditingController _cityController;
  late final TextEditingController _descController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clubData['name'] ?? '');
    _sportController = TextEditingController(text: widget.clubData['sport'] ?? '');
    _cityController = TextEditingController(text: widget.clubData['city'] ?? '');
    _descController = TextEditingController(text: widget.clubData['description'] ?? '');
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).update({
      'name': _nameController.text.trim(),
      'sport': _sportController.text.trim(),
      'city': _cityController.text.trim(),
      'description': _descController.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Modifier le club', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(_nameController, 'Nom du club'),
          _field(_sportController, 'Sport'),
          _field(_cityController, 'Ville'),
          _field(_descController, 'Description', maxLines: 3),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('ENREGISTRER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white.withOpacity(0.05)),
      ),
    );
  }
}