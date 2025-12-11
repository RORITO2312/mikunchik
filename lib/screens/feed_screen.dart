// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  FeedScreenState createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final CollectionReference _recetasCollection =
      FirebaseFirestore.instance.collection('recetas');

  void _likeReceta(DocumentSnapshot doc) async {
    final votos = (doc['votos'] ?? 0) + 1;
    await _recetasCollection.doc(doc.id).update({'votos': votos});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF2A71A),
        title: const Text("Para ti"),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _recetasCollection.orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay publicaciones aún.'));
          }

          final recetas = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: recetas.length,
            itemBuilder: (context, index) {
              final doc = recetas[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildFeedCard(
                userName: data['usuario'] ?? 'Anónimo',
                dishName: data['nombre'] ?? 'Receta',
                category: data['numeroPlatos'] ?? '',
                description:
                    "${data['procedimiento'] ?? ''}\nPresupuesto: S/.${data['presupuesto'] ?? '0.0'}",
                imageUrl: data['imagenUrl'] ??
                    'https://cdn-icons-png.flaticon.com/512/1046/1046784.png',
                likes: (data['votos'] ?? 0).toString(),
                comments: (data['puntuacion'] ?? 0).toString(),
                onLikePressed: () => _likeReceta(doc),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFeedCard({
    required String userName,
    required String dishName,
    required String category,
    required String description,
    required String imageUrl,
    required String likes,
    required String comments,
    required VoidCallback onLikePressed,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundImage: NetworkImage(
                      'https://cdn-icons-png.flaticon.com/512/147/147144.png'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(dishName, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                Text(category, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          // Image
          Image.network(
            imageUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.fastfood, size: 50, color: Colors.white),
            ),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(description, style: TextStyle(color: Colors.grey[800])),
          ),
          // Actions
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: onLikePressed,
                      child: const Icon(Icons.favorite_border),
                    ),
                    const SizedBox(width: 4),
                    Text(likes),
                    const SizedBox(width: 16),
                    const Icon(Icons.star_border),
                    const SizedBox(width: 4),
                    Text(comments),
                    const SizedBox(width: 16),
                    const Icon(Icons.share_outlined),
                  ],
                ),
                const Icon(Icons.bookmark_border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}