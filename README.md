# ReVanced Manager Bundle

Version automatiquement reconstruite de [ReVanced Manager](https://github.com/ReVanced/revanced-manager)
qui sait patcher les applications **installées depuis le Play Store en APK splittés
(bundles)**, comme ChatGPT ou Instagram.

Ce dépôt ne contient pas de copie de Manager : seulement un patch et un workflow.
À chaque nouvelle release officielle, le workflow récupère le code de cette version,
applique le patch, construit l'APK, le signe et publie une release avec le même tag.

## Ce qui change par rapport au Manager officiel

| | Manager officiel | Manager Bundle |
| --- | --- | --- |
| App installée en bundle comme source | refusée | fusionnée automatiquement en un APK unique |
| Mode **Monter** (root) avec une app du Play Store | réinstalle l'APK source, échoue sur un APK fusionné (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) | monte directement par-dessus l'app installée, sans réinstallation |
| Signature de l'app patchée en mode **Monter** | – | celle d'origine (Play Store) : connexion Google et vérifications de signature préservées |
| Identifiant | `app.revanced.manager.flutter` | `app.revanced.manager.bundle` (les deux peuvent coexister) |
| Mise à jour intégrée | vers la version officielle | désactivée (signature différente) ; mettre à jour depuis les releases de ce dépôt |

Concrètement, pour une app comme ChatGPT avec un appareil rooté :

1. installe ou mets à jour l'app depuis le Play Store ;
2. dans Manager Bundle, choisis l'app, garde la source **Application installée** ;
3. sélectionne les patches, lance le patch puis choisis **Monter**.

Manager fusionne `base.apk` et ses splits, patche le résultat et le monte sur l'app
installée. Pense à désactiver la mise à jour automatique de l'app dans le Play Store.

Sans root, la même source fonctionne : l'APK patché s'installe alors normalement
(désinstalle d'abord la version du Play Store, la signature étant différente).

## Fonctionnement

```text
config.env                     dépôt officiel suivi, tag de base, identifiant de l'app
patches/0001-split-apk-support.patch
                               modification de Manager (fusion des splits)
scripts/prepare.sh             applique le patch sur un clone officiel
.github/workflows/build.yml    surveillance des releases, build, signature, publication
```

- Toutes les 6 heures, le workflow regarde la dernière release officielle (pré-releases
  `dev` comprises). Si elle n'existe pas encore ici, il la construit et la publie.
- Le patch est d'abord appliqué tel quel. S'il ne s'applique plus parce que le code
  voisin a changé, `prepare.sh` tente une fusion 3-way à partir de `BASE_TAG`.
- Si le build échoue, une issue est ouverte avec le lien vers le run.

La fusion des splits utilise [ARSCLib](https://github.com/REAndroid/ARSCLib), la
bibliothèque d'APKEditor : ressources, dex et bibliothèques natives sont regroupés,
puis les attributs propres aux bundles (`requiredSplitTypes`, `isSplitRequired`,
métadonnées `com.android.vending.splits*`) et l'ancienne signature sont retirés.

## Configuration (une seule fois)

Dans **Settings → Secrets and variables → Actions**, ajoute :

| Secret | Contenu |
| --- | --- |
| `KEYSTORE` | keystore de signature encodé en base64 |
| `KEYSTORE_PASSWORD` | mot de passe du keystore |
| `KEYSTORE_ENTRY_ALIAS` | alias de la clé |
| `KEYSTORE_ENTRY_PASSWORD` | mot de passe de la clé |

Les bibliothèques ReVanced (GitHub Packages) se téléchargent avec le token fourni
automatiquement au workflow. Si GitHub le refuse un jour, ajoute un secret
`GH_PACKAGES_TOKEN` (token classic avec `read:packages`).

Créer le keystore (à garder précieusement : sans lui, impossible de publier une mise à
jour installable par-dessus la précédente) :

```sh
keytool -genkeypair -keystore keystore.jks -alias revanced -keyalg RSA -keysize 4096 -validity 36500
base64 -w 0 keystore.jks   # valeur du secret KEYSTORE
```

Ensuite, lance le workflow une première fois depuis l'onglet **Actions**
(**Build ReVanced Manager Bundle → Run workflow**). L'option `dry_run` construit l'APK
sans publier de release (signé avec une clé de debug si `KEYSTORE` est absent). Un push
qui modifie `patches/`, `scripts/`, `config.env` ou le workflow lance aussi un build de
test.

GitHub désactive les workflows planifiés d'un dépôt sans activité depuis 60 jours : il
suffit alors de le réactiver depuis l'onglet **Actions**.

## Mettre à jour le patch

Quand une issue signale qu'une nouvelle version ne s'applique plus :

```sh
git clone --depth 1 --branch <nouveau-tag> https://github.com/ReVanced/revanced-manager upstream
cd upstream
git fetch --depth 1 origin "refs/tags/<BASE_TAG>:refs/tags/<BASE_TAG>"
git apply --3way ../patches/0001-split-apk-support.patch   # résoudre les conflits
git add -N . && git diff > ../patches/0001-split-apk-support.patch
```

Puis remplace `BASE_TAG` par `<nouveau-tag>` dans `config.env`.

## Licence

ReVanced Manager est distribué sous GPLv3 ; les APK publiés ici aussi. Le code source
correspondant est celui du tag officiel, plus le patch de ce dépôt.
