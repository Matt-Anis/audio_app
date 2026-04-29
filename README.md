# Audio App (Spotify-like UI, basic Flutter concepts)

Cette application implemente:

- Authentification biometrie empreinte obligatoire au premier lancement.
- Redirection vers les parametres de securite si aucune empreinte n'est configuree.
- Authentification Firebase (inscription, connexion, reset password).
- Champs obligatoires inscription: nom, prenom, date de naissance (age >= 13 ans).
- Dashboard statistiques:
	- Message de bienvenue avec nom complet en gras.
	- Temps total d'ecoute (heures/minutes).
	- Histogramme minutes par jour (mois actuel).
	- Liste des morceaux les plus ecoutes.
	- Objectif mensuel (menu deroulant, defaut 20h) sauvegarde localement.
- Lecteur audio:
	- Playlist dynamique depuis API externe (mp3quran).
	- Lecture / pause / repetition.
	- Lecture en arriere-plan (notification Android).
- Favoris sauvegardes en ligne via Firebase Firestore.
- Suppression d'un favori protegee par empreinte digitale.

## 1) Prerequis

- Flutter installe et configure.
- Un appareil Android (ou emulateur Android avec biometrie activee).
- Un projet Firebase.

## 2) Setup Firebase (obligatoire)

1. Aller sur Firebase Console.
2. Creer un projet Firebase.
3. Activer Authentication:
	 - Sign-in method -> Email/Password -> Enable.
4. Creer Firestore Database:
	 - Mode test (pour demarrage rapide en TP), puis regler des regles plus strictes.
5. Ajouter une app Android dans Firebase:
	 - Android package name doit etre le meme que `applicationId` dans `android/app/build.gradle.kts`.
	 - Ici, par defaut: `com.example.audio_app`.
6. Telecharger `google-services.json` et le placer dans:
	 - `android/app/google-services.json`

Option iOS (si vous testez sur iPhone):

1. Ajouter app iOS dans Firebase.
2. Telecharger `GoogleService-Info.plist`.
3. Le placer dans `ios/Runner/` via Xcode.

## 3) Installer et lancer

```bash
flutter pub get
flutter run
```

## 4) Regles Firestore simples (dev)

Utiliser ces regles au debut (mode simple pour cours/TP):

```txt
rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /users/{userId} {
			allow read, write: if request.auth != null && request.auth.uid == userId;

			match /favorites/{trackId} {
				allow read, write: if request.auth != null && request.auth.uid == userId;
			}
		}
	}
}
```

## 5) Notes importantes

- La verification empreinte est imposee au premier lancement de l'app.
- Si l'empreinte n'existe pas, l'app ouvre les parametres de securite Android.
- L'objectif mensuel est en local (SharedPreferences), valeur par defaut 20h.
- Les favoris sont en ligne (Firestore) et synchronises avec le compte utilisateur.

## 6) Structure principale

- `lib/main.dart`: demarrage, theme, gate biometrie, gate auth.
- `lib/screens/auth/auth_page.dart`: login/inscription/reset.
- `lib/screens/home/home_page.dart`: navigation principale.
- `lib/screens/home/stats_tab.dart`: statistiques + objectif + histogramme.
- `lib/screens/home/player_tab.dart`: playlist API + player + favoris.
- `lib/screens/home/favorites_tab.dart`: favoris et suppression securisee biometrie.
- `lib/services/`: services Firebase, biometrie, stats locales, player, API.
