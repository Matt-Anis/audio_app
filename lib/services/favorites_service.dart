import 'package:audio_app/models/audio_track.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _favoritesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  Stream<List<AudioTrack>> streamFavorites(String uid) {
    return _favoritesRef(uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AudioTrack.fromMap(data);
      }).toList();
    });
  }

  Future<void> addFavorite(String uid, AudioTrack track) async {
    await _favoritesRef(uid).doc(track.id).set(track.toMap());
  }

  Future<void> removeFavorite(String uid, String trackId) async {
    await _favoritesRef(uid).doc(trackId).delete();
  }

  Future<bool> isFavorite(String uid, String trackId) async {
    final doc = await _favoritesRef(uid).doc(trackId).get();
    return doc.exists;
  }
}
