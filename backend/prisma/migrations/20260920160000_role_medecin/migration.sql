-- Ajoute le profil MEDECIN.
--
-- Présent dans les CSB II, absent des CSB I. Cliniquement le profil le plus
-- large ; distingué de la sage-femme pour la traçabilité et le reporting, pas
-- pour les droits — savoir qu'un acte a été posé par un médecin ou par une
-- sage-femme a un sens clinique, et se perd si les deux partagent un rôle.
--
-- Ajout d'une valeur d'énumération : opération non destructive, aucune ligne
-- existante n'est touchée.
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'MEDECIN' AFTER 'SAGE_FEMME';
