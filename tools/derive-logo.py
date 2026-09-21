"""Derive les fichiers de marque depuis new_logo.jpeg.

A relancer depuis la racine du depot apres toute retouche du logo :

    python tools/derive-logo.py
    cd mobile && dart run flutter_launcher_icons

Sans ce script, personne ne saurait reproduire le detourage ni les tailles,
et le prochain changement de logo repartirait de zero.

Sorties :
  mobile/assets/branding/icon_legacy.png      icone carree, Android 7
  mobile/assets/branding/icon_foreground.png  couche avant de l'icone adaptative
  mobile/assets/branding/embleme.png          embleme, ecran de connexion mobile
  admin/public/logo-mbolatsara.png            logo complet, page de connexion web
  admin/public/embleme-mbolatsara.png         embleme, barre laterale web
  admin/public/icone.png                      favicon
"""

import os

from PIL import Image

SOURCE = 'new_logo.jpeg'
FOND = (247, 247, 247)

# Mesures relevees sur l'image : l'embleme circulaire, puis le tout avec le mot.
EMBLEME = (240, 132, 1018, 946)
COMPLET = (63, 132, 1191, 1155)


def sans_fond(im, tolerance=26, marge=60):
    """Rend transparent ce qui est proche de la couleur de fond.

    Une rampe entre `tolerance` et `tolerance + marge` evite le liseré dentelé
    qu'un seuil net laisserait sur les bords anticrénelés.
    """
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            d = abs(r - FOND[0]) + abs(g - FOND[1]) + abs(b - FOND[2])
            if d <= tolerance:
                px[x, y] = (r, g, b, 0)
            elif d < tolerance + marge:
                px[x, y] = (r, g, b, int(255 * (d - tolerance) / marge))
    return im


def carre(im, cote, proportion, fond=None):
    """Centre `im` dans un carre, en occupant `proportion` du cote."""
    cible = int(cote * proportion)
    e = im.copy()
    e.thumbnail((cible, cible), Image.LANCZOS)
    toile = Image.new('RGBA', (cote, cote), fond or (0, 0, 0, 0))
    toile.paste(e, ((cote - e.width) // 2, (cote - e.height) // 2), e)
    return toile


source = Image.open(SOURCE).convert('RGB')
embleme = sans_fond(source.crop(EMBLEME))

# Fond blanc plein : `adaptive_icon_background` est deja blanc, et Android 7
# n'accepte pas de transparence sur l'icone historique.
carre(embleme, 1024, 0.88, (255, 255, 255, 255)).save(
    'mobile/assets/branding/icon_legacy.png'
)

# 66 % : c'est exactement la zone qu'Android garantit visible quel que soit le
# masque du lanceur (72 dp sur une toile de 108). En dessous l'embleme flotte
# au milieu d'un disque vide ; au-dessus, un masque agressif le rogne.
carre(embleme, 1024, 0.66).save('mobile/assets/branding/icon_foreground.png')

# Logo complet pour le web, transparent : il se pose aussi bien sur une carte
# blanche que sur le panneau colore de la page de connexion.
complet = sans_fond(source.crop(COMPLET))
complet.save('admin/public/logo-mbolatsara.png')

# Embleme seul, pour la barre laterale et le favicon, ou le mot serait illisible.
embleme.save('admin/public/embleme-mbolatsara.png')

def reduire(chemin, hauteur):
    """Ramene une image a la taille ou elle est reellement affichee.

    Les fichiers derives pesent plus d'un megaoctet en pleine taille, pour un
    logo affiche a 96 pixels. Sur les connexions de Madagascar, c'est plus que
    tout le reste de l'application reunie.
    """
    im = Image.open(chemin).convert('RGBA')
    r = hauteur / im.height
    im = im.resize((max(1, round(im.width * r)), hauteur), Image.LANCZOS)
    im.save(chemin, optimize=True)
    return im.size, os.path.getsize(chemin)


# L'embleme sert aussi dans l'application : 256 px couvre les 96 dp affiches.
mobile = 'mobile/assets/branding/embleme.png'
embleme.save(mobile)
reduire(mobile, 256)

# Favicon avant reduction de l'embleme, pour partir de la pleine resolution.
Image.open('admin/public/embleme-mbolatsara.png').save('admin/public/icone.png')

print('icon_legacy     ', Image.open('mobile/assets/branding/icon_legacy.png').size)
print('icon_foreground ', Image.open('mobile/assets/branding/icon_foreground.png').size)
print('embleme mobile  ', Image.open(mobile).size)
print('logo web        ', reduire('admin/public/logo-mbolatsara.png', 320))
print('embleme web     ', reduire('admin/public/embleme-mbolatsara.png', 160))
print('favicon         ', reduire('admin/public/icone.png', 64))
