# Cahier des charges — Projet Planify

**Version :** 1.0  
**Date :** 23 novembre 2026  
**Type :** Application mobile multiplateforme et application web de démonstration  
**Équipe :** Ahmed, Eya, Moetaz (Motez), Moncef et Oumayma  

---

## 1. Présentation du projet

### 1.1 Contexte

Planify est une application de productivité personnelle et collaborative destinée à aider l'utilisateur à :

- organiser ses tâches et sous-tâches ;
- planifier ses activités dans un calendrier quotidien, hebdomadaire ou mensuel ;
- définir des objectifs et gérer des projets ;
- suivre des séances de concentration ;
- programmer des rappels ;
- recevoir des propositions intelligentes pour améliorer la gestion du temps ;
- suivre sa progression et collaborer avec d'autres utilisateurs.

L'application a pour objectif de transformer une intention générale en un plan réalisable, puis de mesurer le travail réellement effectué.

### 1.2 Objectif général

Fournir une application centralisée permettant à l'utilisateur de :

1. capturer ses tâches ;
2. définir leurs contraintes, estimations et dépendances ;
3. créer une journée réaliste autour des disponibilités et événements fixes ;
4. travailler sur une tâche dans une séance de concentration ;
5. recevoir des rappels ;
6. consulter les écarts entre travail prévu et travail réel ;
7. améliorer ses habitudes grâce à des recommandations explicables.

### 1.3 Produit et périmètre

Le produit comprend :

- une application Flutter Android, iOS et web ;
- une API Node.js ;
- une couche de données pour comptes, projets, tâches, calendrier, rappels et séances ;
- des fonctionnalités d'intelligence artificielle fondées sur des fournisseurs compatibles OpenAI, notamment OpenRouter ;
- des notifications locales Android/iOS ;
- une interface d'approbation pour toute action proposée par l'IA.

### 1.4 État du projet

Le présent cahier couvre le périmètre fonctionnel attendu du projet intégré. Certaines fonctionnalités peuvent fonctionner localement, par exemple les règles de planification et les outils de concentration. Les fonctions nécessitant des services externes, comme les notifications push, le calendrier Google ou l'envoi d'emails, doivent être configurées ou intégrées séparément.

Les fonctionnalités cloud doivent respecter :

- le consentement utilisateur ;
- l'authentification ;
- les autorisations du propriétaire des données ;
- la validation des propositions ;
- l'approbation explicite avant modification.

---

## 2. Acteurs du système

| Acteur | Rôle |
|---|---|
| Utilisateur | Crée ses tâches, planifie ses journées et utilise les fonctionnalités de concentration |
| Administrateur | Gère les paramètres techniques et opérationnels du serveur |
| Propriétaire de projet | Crée et administre un projet |
| Collaborateur | Participe aux tâches et projets autorisés |
| Lecteur | Consulte uniquement les données auxquelles il a accès |
| Assistant IA | Produit des propositions structurées sans les appliquer automatiquement |
| API backend | Authentifie les utilisateurs et sécurise les opérations |
| Fournisseur IA | Fournit les réponses du modèle à partir d'un contexte autorisé |
| Plateforme mobile | Fournit les permissions, le stockage et les notifications locales |

---

## 3. Besoins fonctionnels

## 3.1 Gestion des comptes

### Inscription et authentification

- L'utilisateur peut créer un compte avec nom, adresse électronique, mot de passe et fuseau horaire.
- L'utilisateur peut se connecter avec son adresse électronique et son mot de passe.
- La connexion Google peut être proposée selon la configuration web.
- Une session possède une durée limitée et peut être révoquée.
- Les informations sensibles ne doivent jamais être stockées dans le code Flutter.

### Profil et préférences

- L'utilisateur peut modifier son nom, son fuseau horaire, sa langue et son thème.
- Les préférences peuvent être système, clair ou sombre.
- Le serveur vérifie les modifications concurrentes des paramètres.
- L'utilisateur peut consulter ses sessions actives et les révoquer.

### Confidentialité et consentement IA

- L'utilisation du cloud IA doit être explicitement consentie.
- L'utilisateur doit pouvoir consulter les données envoyées au contexte IA.
- L'utilisateur peut désactiver l'utilisation du cloud IA.

## 3.2 Gestion des tâches

- Ajouter une tâche.
- Modifier une tâche.
- Supprimer une tâche.
- Attribuer un titre, une description, une priorité, une catégorie et une durée estimée.
- Définir une date limite.
- Définir des relations de dépendance.
- Décomposer une tâche en sous-tâches.
- Marquer une tâche comme terminée ou réouverte.
- Gérer les tâches récurrentes.
- Filtrer les tâches par statut, priorité, catégorie ou échéance.
- Afficher les tâches prêtes, bloquées ou terminées.
- Empêcher les dépendances circulaires.

Une tâche doit être liée à une identité stable afin de supporter les séances de concentration, les événements de calendrier et les rapports.

## 3.3 Objectifs, projets et collaboration

- Créer un objectif et plusieurs jalons.
- Associer des tâches à un objectif.
- Calculer une progression à partir de l'état des tâches.
- Créer un projet.
- Ajouter des collaborateurs.
- Attribuer les rôles propriétaire, administrateur, collaborateur ou lecteur.
- Envoyer et gérer les invitations.
- Autoriser les opérations selon les droits du membre.
- Consulter les commentaires et l'activité du projet.

## 3.4 Calendrier et planification

- Afficher les vues mensuelle, hebdomadaire et quotidienne.
- Ajouter des événements fixes.
- Ajouter des pauses.
- Définir des heures de travail.
- Détecter les chevauchements.
- Planifier les tâches prêtes autour des contraintes existantes.
- Prendre en compte les échéances, priorités, dépendances et durées estimées.
- Produire une proposition avant toute modification du calendrier.
- Permettre à l'utilisateur d'approuver, modifier ou rejeter la proposition.
- Réviser le plan lors d'un dépassement ou d'une interruption.
- Conserver la révision initiale jusqu'à l'approbation du changement.

### Règles de planification

- Les blocs fixes ne peuvent pas être déplacés automatiquement.
- Les blocs ne peuvent pas se chevaucher.
- Une tâche bloquée ne peut pas être planifiée.
- Les résultats identiques doivent produire le même planning.
- Une proposition obsolète doit être régénérée après modification concurrente.

## 3.5 Module Focus

### Modes

- **Compte à rebours** : durée cible choisie par l'utilisateur.
- **Pomodoro** : blocs de 25 minutes avec une pause facultative de cinq minutes.
- **Chronomètre** : durée libre sans échéance imposée.

### Séance

- Débuter une séance sur une tâche ou librement.
- Afficher le temps restant ou écoulé.
- Mettre en pause et reprendre.
- Prendre une pause.
- Ajouter du temps à une séance.
- Ajouter une note.
- Enregistrer une interruption.
- Enregistrer un blocage.
- Terminer normalement ou mettre fin en avance.
- Annuler une séance.
- Vérifier que le bloc calendrier sélectionné existe toujours avant le démarrage.
- Restaurer une séance après redémarrage ou retour dans l'application.

### Durées

- Les pauses ne sont pas comptées comme du temps de concentration.
- Les périodes de pause ne font pas augmenter le temps cumulé.
- Le temps écoulé doit être calculé à partir d'horodatages persistés.
- Une durée cible doit être distinguée du temps réellement concentré.
- Une fin anticipée doit être différenciée d'une fin normale.

### Historique

- Consulter toutes les séances.
- Filtrer par aujourd'hui ou sur les sept derniers jours.
- Afficher la durée cible, la durée réelle, les pauses, les notes et les événements.
- Ne pas marquer automatiquement une tâche comme terminée à la fin d'une séance.

## 3.6 Module Rappels

- Créer un rappel avec titre, date, heure et recurrence.
- Modifier un rappel.
- Supprimer un rappel.
- Activer ou désactiver un rappel.
- Programmer une répétition unique, quotidienne ou hebdomadaire.
- Programmer une échéance relative à une tâche.
- Répéter l'action toutes les périodes définies.
- Reporter un rappel de dix minutes.
- Conserver la recurrence après une mise en veille temporaire.
- Annuler les notifications supprimées ou désactivées.
- Afficher les rappels à venir et expirés.

### Notifications locales

- Demander la permission Android ou iOS.
- Planifier une notification locale.
- Utiliser un canal Android dédié.
- Ouvrir la page correspondante lors du clic sur une notification.
- Reconcilier les notifications après modification, suppression ou restauration.
- Informer l'utilisateur si la plateforme ne prend pas en charge les notifications natives.

Dans une démo web, les notifications natives ne doivent pas être considérées comme garanties. Sur Android, le mode de programmation peut être inexact et l'OS peut retarder l'alerte.

## 3.7 Fonction avancée : adaptation de la durée de concentration

La fonctionnalité doit analyser les dix dernières séances terminées :

- calculer la durée réelle moyenne ;
- analyser la fréquence des interruptions ;
- réduire la durée suggérée si les interruptions sont fréquentes ;
- arrondir la durée à cinq minutes ;
- rester entre cinq et soixante minutes ;
- proposer vingt-cinq minutes lorsque aucun historique n'est disponible.

Cette fonctionnalité est déterministe. Elle ne doit pas être qualifiée d'IA si elle ne fait appel à aucun modèle de langage.

## 3.8 Fonction avancée : protection des rappels

Le module doit analyser une nouvelle heure ou un rappel existant afin de :

- éviter les heures silencieuses entre 22 h et 8 h ;
- maintenir au moins dix minutes d'écart avec les autres rappels actifs ;
- conserver la recurrence ;
- afficher la proposition avant application ;
- détecter une modification concurrente du rappel ;
- limiter la recherche à un nombre maximal d'essais.

Cette fonctionnalité est déterministe et doit être expliquée avec les horaires proposés et rejetés.

## 3.9 Agent IA Focus Coach

### Entrée

- demande naturelle de l'utilisateur ;
- statistiques agrégées des séances récentes ;
- durée et fréquence d'interruption ;
- heure locale et décalage du fuseau horaire.

### Sortie

Le modèle retourne une proposition structurée contenant :

- un titre ;
- une raison explicative ;
- une durée comprise entre cinq et cent vingt minutes ;
- une liste d'étapes entre une et huit ;

La proposition doit être validée côté Flutter et côté backend.

### Vérification

- aucun lancement automatique ;
- l'utilisateur peut approuver ou rejeter ;
- les étapes approuvées sont enregistrées comme notes de séance ;
- l'approbation démarre une seule séance active.

## 3.10 Agent IA Rappels

### Entrée

- demande naturelle ;
- rappels existants ;
- recurrence existante ;
- heure locale et décalage du fuseau horaire.

### Sortie

Le modèle retourne :

- titre du rappel ;
- raison ;
- date et heure ISO 8601 avec timezone ;
- recurrence : unique, quotidienne ou hebdomadaire.

### Vérification

- aucune date passée ;
- titre et raison valides ;
- recurrence autorisée ;
- validation Flutter après retour du modèle ;
- vérification de conflits avant approbation ;
- création du rappel uniquement après approbation.

## 3.11 Assistant IA général

- Lire les données autorisées du workspace.
- Répondre à une question par une réponse contextualisée.
- Préparer des propositions éditables.
- Ne jamais appliquer une action sans approbation.
- Conserver l'historique des propositions et l'audit des actions.

La fonctionnalité cloud doit être désactivée si :

- le consentement n'est pas accordé ;
- aucune clé n'est configurée ;
- le fournisseur échoue ;
- la sortie ne respecte pas le schéma attendu.

## 3.12 Synchronisation

- Synchroniser les tâches personnelles, la planification, les séances, les rappels et les check-ins.
- Exécuter une synchronisation après modification.
- Permettre les changements hors connexion.
- Conserver les changements locaux en attente de réseau.
- Synchroniser indépendamment chaque collection.
- Détecter les modifications concurrentes.
- Conserver les deux versions lors d'un conflit.
- Permettre à l'utilisateur de choisir une version.
- Réutiliser un identifiant d'action pour éviter les modifications dupliquées.

---

## 4. Besoins techniques

## 4.1 Frontend

| Élément | Technologie |
|---|---|
| Framework | Flutter |
| Langage | Dart |
| Plateformes | Android, iOS, Web |
| Gestion d'état | `ChangeNotifier`, `ListenableBuilder`, `AnimatedBuilder` |
| Stockage local | `SharedPreferencesAsync` |
| Stockage sécurisé | `FlutterSecureStorage` |
| Notifications | `flutter_local_notifications` |
| Timezone | `flutter_timezone`, package `timezone` |
| HTTP | package Dart `http` |
| Tests | Flutter Test |

## 4.2 Backend

| Élément | Technologie |
|---|---|
| Langage | JavaScript moderne, modules ES |
| Runtime | Node.js 22 ou version compatible |
| API | API REST JSON |
| Base principale | Neon PostgreSQL en production |
| Base locale | SQLite pour les comptes et PGlite/PostgreSQL embarqué pour le workspace |
| Validation | Zod et validations applicatives |
| Authentification | Jetons bearer et stockage sécurisé |
| Documentation | README, fichiers Markdown et tests |

## 4.3 Intelligence artificielle

| Élément | Choix |
|---|---|
| Protocole | API OpenAI-compatible Chat Completions |
| Fournisseur | OpenRouter ou fournisseur compatible |
| Sélection du modèle | Variable d'environnement `AI_MODEL` |
| URL du fournisseur | Variable d'environnement `AI_BASE_URL` |
| Clé API | Variable d'environnement `AI_API_KEY` |
| Format de réponse | JSON structuré |
| Appel d'outils | Function/tool calling |
| Limite quotidienne | 1000 appels maximum par configuration |
| Modèles autorisés | Modèles gratuits dans la configuration OpenRouter |

Le modèle exact n'est pas fixé dans le code. Le service reçoit les paramètres à l'exécution.

## 4.4 Architecture proposée

```text
Application Flutter
        |
        | API REST authentifiée
        v
Backend Node.js / Planify API
        |
        +-- Authentification et sessions
        +-- Comptes et préférences
        +-- Projets, objectifs et tâches
        +-- Calendrier et planification
        +-- Synchronisation personnelle
        +-- Adaptateur IA sécurisé
        |
        v
OpenRouter / fournisseur OpenAI-compatible

Application Flutter
        |
        +-- SharedPreferences : données personnelles hors ligne
        +-- Secure Storage : token de session
        +-- Notifications locales : rappels Android/iOS
```

---

## 5. Exigences non fonctionnelles

## 5.1 Sécurité

- Ne jamais fournir une clé API au client Flutter.
- Hashage des mots de passe avec sel.
- Hashage des jetons de session côté stockage serveur.
- Vérification des autorisations pour chaque requête.
- Validation des entrées côté serveur.
- Protection contre les entrées excessivement longues.
- Gestion des erreurs 400, 401, 403, 409, 422, 429 et 500.
- Aucun identifiant de compte accepté à partir du client pour les ressources personnelles.
- Jetons OAuth et secrets conservés hors du dépôt.

## 5.2 Confidentialité

- Seul le contexte strictement nécessaire est envoyé à l'IA.
- Les notes privées ne doivent pas être incluses dans les demandes Focus Coach.
- Les titres et contenus privés doivent respecter le consentement cloud.
- Toute proposition IA doit indiquer sa raison.
- Aucun modèle ne peut prétendre avoir effectué une action sans confirmation.

## 5.3 Performance

- Chargement initial raisonnable sur les plateformes ciblées.
- Synchronisation hors ligne sans bloquer l'interface.
- Timeout du fournisseur IA inférieur à quinze secondes dans le prototype.
- Limitation du nombre de tool calls.
- Pagination des listes importantes.
- Pas de requête IA automatique répétée sans action utilisateur.

## 5.4 Fiabilité

- L'application doit restaurer une séance active après redémarrage.
- Les modifications locales doivent être conservées en cas d'échec réseau.
- Les identifiants d'opération doivent permettre une reprise sans duplication.
- Les rappels supprimés doivent annuler leur alerte locale.
- Une proposition dépassée doit être refusée ou régénérée.

## 5.5 Ergonomie

- Interface responsive.
- Navigation mobile avec accès rapide aux sections principales.
- États de chargement visibles.
- Messages d'erreur compréhensibles.
- Boutons clairs pour approuver, modifier ou rejeter.
- États vides explicites.
- Thèmes clair et sombre.
- Support des textes agrandis et du mode reduced motion.

## 5.6 Accessibilité

- Contrastes suffisants.
- Labels accessibles sur les boutons d'action.
- Ordre de lecture cohérent.
- Résultats vocaux ou textes accessibles lorsque nécessaire.
- Aucune information essentielle communiquée uniquement par couleur.

## 5.7 Compatibilité

- Android : support des API compatibles avec le plugin de notification.
- iOS : permissions système, fuseau horaire et notifications locales.
- Web : interface responsive et stockage navigateur, sans garantie de notifications natives.
- Backend : Node.js compatible avec les APIs utilisées.

## 5.8 Maintenabilité

- Séparation UI, état, stockage, API et modèles.
- Services centralisés pour les notifications et les appels API.
- Validation indépendante des entrées IA.
- Tests unitaires et tests d'intégration.
- Configuration externe dans les variables d'environnement.
- Aucun secret dans les fichiers de versionnement.

---

## 6. Modèle de données

## 6.1 Utilisateur

- Identifiant
- Nom
- Adresse électronique
- Hash et sel du mot de passe
- Fuseau horaire
- Langue
- Préférences
- Consentement IA
- Sessions actives

## 6.2 Tâche

- Identifiant
- Identifiant utilisateur ou projet
- Titre
- Description
- Statut
- Priorité
- Durée estimée
- Échéance
- Catégorie
- Dépendances
- Récurrence
- Horodatages de création et modification

## 6.3 Séance de concentration

- Identifiant
- Identifiant utilisateur
- Identifiant tâche optionnel
- Titre
- Mode
- Durée cible
- Temps accumulé
- Heure de création
- Heure de début
- Heure de fin
- Statut
- Notes
- Interventions
- Blocages
- Identifiant du bloc calendrier optionnel

## 6.4 Rappel

- Identifiant
- Identifiant utilisateur
- Titre
- Date et heure
- Récurrence
- État activé/désactivé
- Heure de mise en veille
- Identifiant de livraison
- Statut de livraison

## 6.5 Objectif

- Identifiant
- Titre
- Description
- Dates
- Statut
- Jalons
- Tâches associées

## 6.6 Projet

- Identifiant
- Titre
- Description
- Propriétaire
- Membres
- Rôles
- Invitations
- Tâches

## 6.7 Proposition IA

- Identifiant
- Utilisateur
- Conversation ou contexte
- Modèle utilisé
- Type de proposition
- Contenu proposé
- Raison
- Statut : en attente, approuvée, modifiée ou rejetée
- Révision
- Horodatage
- Audit des actions

---

## 7. Principales API

| Méthode | Route | Description |
|---|---|---|
| POST | `/auth/register` | Inscription |
| POST | `/auth/login` | Connexion |
| POST | `/auth/logout` | Déconnexion |
| GET | `/auth/me` | Informations de session |
| GET/PATCH | `/users/me/preferences` | Préférences utilisateur |
| GET/POST/PATCH/DELETE | `/tasks` | Gestion des tâches |
| GET/POST/PATCH/DELETE | `/goals` | Gestion des objectifs |
| GET/POST/PATCH/DELETE | `/projects` | Gestion des projets |
| GET/POST | `/assistant/conversations` | Conversations IA |
| POST | `/assistant/messages` | Message à l'assistant |
| POST | `/agents/focus` | Proposition du coach de concentration |
| GET | `/users/me/sync` | Récupération des collections personnelles |
| POST | `/users/me/sync/{collection}` | Synchronisation d'une collection |
| GET | `/health` | Vérification du backend |

Les routes exactes peuvent évoluer pendant l'intégration, mais les contrats doivent conserver authentification, validation, ownership et gestion des erreurs.

---

## 8. Interfaces principales

1. Écran de connexion et inscription.
2. Tableau de bord Aujourd'hui.
3. Liste des tâches.
4. Détail et édition d'une tâche.
5. Vue calendrier mensuelle.
6. Vue calendrier hebdomadaire.
7. Vue calendrier quotidienne.
8. Préparation d'une séance de concentration.
9. Écran actif de concentration.
10. Résumé de séance.
11. Liste des rappels.
12. Créateur ou éditeur de rappel.
13. Outils intelligents Focus/Rappels.
14. Assistant IA.
15. Historique des propositions.
16. Objectifs et jalons.
17. Projets et collaborateurs.
18. Préférences, confidentialité et sécurité.
19. Statistiques et rapports.

---

## 9. Cas d'utilisation prioritaires

### CU1 — Planifier une journée

1. L'utilisateur se connecte.
2. Il consulte ses tâches.
3. Il ajoute un événement fixe.
4. Il demande une proposition de planning.
5. Le moteur génère les blocs.
6. L'utilisateur approuve ou rejette.
7. Le calendrier est sauvegardé.

### CU2 — Démarrer une séance

1. L'utilisateur ouvre Focus.
2. Il choisit une tâche ou saisit un titre.
3. Il choisit Countdown, Pomodoro ou Stopwatch.
4. Il démarre la séance.
5. Il peut mettre en pause, reprendre ou prendre une pause.
6. Il termine la séance.
7. Les statistiques sont enregistrées.

### CU3 — Créer un rappel

1. L'utilisateur ouvre Rappels.
2. Il saisit le titre, la date, l'heure et la recurrence.
3. Il demande l'enregistrement.
4. L'application sauvegarde le rappel.
5. Elle programme une notification locale.

### CU4 — Utiliser l'agent IA de rappel

1. L'utilisateur ouvre AI Reminder Agent.
2. Il décrit sa demande en langage naturel.
3. Le backend collecte le contexte autorisé.
4. Le modèle propose une date et une recurrence.
5. Le système valide la proposition.
6. L'utilisateur approuve.
7. Le rappel est créé et la notification est planifiée.

### CU5 — Replanifier après interruption

1. Une séance dépasse sa durée ou rencontre un blocage.
2. L'événement est enregistré.
3. Le moteur propose une modification du jour restant.
4. L'utilisateur examine les blocs modifiés.
5. L'utilisateur approuve ou rejette.
6. Les rappels sont ajustés si nécessaire.

---

## 10. Contraintes, hypothèses et limites

### Contraintes

- Le code source est développé principalement en Dart, JavaScript et SQL.
- Le frontend doit utiliser Flutter.
- Les secrets ne doivent pas être distribués dans les applications clientes.
- Les actions IA doivent être contrôlées par approbation humaine.
- Les tests doivent couvrir les états essentiels et les erreurs.

### Hypothèses

- L'utilisateur possède une connexion pour l'inscription et les fonctions cloud.
- Android ou iOS autorise les notifications locales.
- Un fournisseur IA compatible est configuré.
- Une base durable est disponible pour le déploiement intégré.

### Limites actuelles

- Les notifications natives ne fonctionnent pas comme des notifications web garanties.
- Les notifications push serveur nécessitent une infrastructure supplémentaire.
- Google Calendar peut nécessiter une configuration OAuth externe.
- La récupération d'e-mail n'est pas garantie sans fournisseur mail.
- La disponibilité hors production dépend de l'hébergement HTTPS.
- Les appareils physiques nécessitent une configuration réseau adaptée.
- Les fonctionnalités sont en cours d'intégration entre les branches de l'équipe.

---

## 11. Livrables attendus

- Code source Flutter.
- Code source backend Node.js.
- Schémas de base de données.
- Documentation d'installation.
- Cahier des charges.
- Documentation d'architecture.
- Guide de démonstration.
- Jeux de tests unitaires et d'intégration.
- Documentation des API.
- Guide de configuration IA.
- Guide de configuration Android/iOS.
- Rapport de validation.
- Jeux d'icônes, logos et thèmes Planify.

---

## 12. Critères d'acceptation

Le projet est considéré comme accepté lorsque :

1. Un utilisateur peut s'inscrire, se connecter et restaurer sa session.
2. Les tâches peuvent être créées, modifiées, supprimées et filtrées.
3. Les objectifs et projets peuvent être reliés aux tâches autorisées.
4. Un calendrier peut être proposé et approuvé.
5. Une séance de concentration peut démarrer, être mise en pause, reprise, terminée ou annulée.
6. Une interruption ou un blocage est enregistré sans perte de la séance.
7. Les rappels peuvent être créés, modifiés, supprimés et reportés.
8. Les rappels récurrents respectent une règle cohérente.
9. Les deux fonctionnalités déterministes sont démontrables.
10. Les deux agents IA peuvent produire une proposition structurée avec un fournisseur configuré.
11. L'approbation applique l'action une seule fois.
12. Le rejet ne modifie pas les données.
13. Les données hors ligne sont restaurables après redémarrage.
14. Les conflits de synchronisation peuvent être inspectés.
15. Les erreurs réseau et IA sont explicables à l'utilisateur.
16. Les rôles et autorisations sont respectés.
17. Le parcours principal fonctionne sur Chrome, Android ou iOS selon les appareils disponibles.

---

## 13. Tests attendus

## Tests unitaires

- Calcul du temps de concentration.
- Exclusion des pauses et breaks.
- Rollback d'une horloge.
- Calcul de recurrence.
- Adaptation de la durée.
- Recherche d'un créneau de rappel.
- Validation des propositions IA.
- Gestion des identifiants dupliqués.

## Tests d'intégration

- Inscription et authentification.
- Synchronisation entre appareils.
- Conflit de synchronisation.
- Création de projet et autorisations.
- Proposition et approbation du planning.
- Création d'une séance liée à une tâche.
- Création d'un rappel par l'agent IA.

## Tests UI

- Petit écran mobile.
- Thème clair et sombre.
- Texte agrandi.
- Navigation clavier.
- États de chargement.
- États d'erreur.
- États hors connexion.

## Tests de plateforme

- Android : permissions, démarrage, pause, arrière-plan et notifications.
- iOS : permissions, notifications et timezone.
- Web : rendu responsive, stockage navigateur et appels API.

---

## 14. Planification indicative

| Phase | Contenu |
|---|---|
| Phase 1 | Socle Flutter, thème, navigation et authentification |
| Phase 2 | Tâches, objectifs et projets |
| Phase 3 | Calendrier et moteur de planification |
| Phase 4 | Séances de concentration et rappels |
| Phase 5 | Fonctions adaptatives et agents IA |
| Phase 6 | Synchronisation et gestion des conflits |
| Phase 7 | Sécurité, tests et corrections |
| Phase 8 | Déploiement de démonstration |
| Phase 9 | Rapport final et présentation |

---

## 15. Organisation de l'équipe

| Membre | Responsabilité principale |
|---|---|
| Eya | Comptes, sécurité, préférences, synchronisation, rapport et analytics |
| Motez | Tâches, sous-tâches, recurrence, dépendances et IA des tâches |
| Moncef | Calendrier, contraintes, moteur de planification et replanning |
| Ahmed | Objectifs, projets, collaboration, assistant général et gamification |
| Oumayma | Focus, rappels, notifications, suivi du temps réel et agents Focus/Rappels |

---

## 16. Définition du MVP

Le MVP comprend obligatoirement :

- authentification ;
- gestion des tâches ;
- calendrier quotidien ;
- création d'un plan approuvé ;
- séance de concentration ;
- rappels simples ;
- synchronisation locale ou serveur ;
- adaptateur IA configurable ;
- une démonstration complète de bout en bout.

Les fonctions suivantes peuvent être documentées comme évolutions :

- widgets mobile ;
- notifications push distantes ;
- calendrier Google complet ;
- capture vocale ou documentaire ;
- statistiques avancées ;
- abonnements ;
- collaboration en temps réel ;
- accès hors ligne complet depuis une installation web en production.

---

## 17. Déploiement

### Développement local

1. Installer Flutter et les dépendances.
2. Installer Node.js 22 ou une version compatible.
3. Installer les dépendances backend.
4. Configurer l'origine CORS.
5. Démarrer le backend sur le port 4100.
6. Démarrer l'application Flutter sur un port disponible, par exemple 5300.
7. Configurer les variables IA si les agents doivent être utilisés.

### Production

- utiliser HTTPS ;
- utiliser Neon ou une base PostgreSQL durable ;
- stocker les secrets dans un gestionnaire d'environnement sécurisé ;
- autoriser uniquement les origines nécessaires ;
- vérifier les notifications mobiles ;
- mettre en place sauvegardes, logs et monitoring ;
- exécuter les tests avant chaque déploiement.

---

## 18. Conclusion

Planify vise à centraliser l'organisation des tâches, la planification quotidienne, la concentration, les rappels et l'assistance intelligente dans une seule application. Le système doit rester explicable : l'utilisateur comprend pourquoi une recommandation est faite, peut revoir une proposition, puis décider de l'appliquer ou de la rejeter.

Le cahier des charges distingue les règles déterministes, les propositions générées par IA et les actions effectuées automatiquement. Cette séparation garantit un meilleur contrôle utilisateur, une meilleure sécurité et une démonstration académique vérifiable.
