/** Jeu d'icônes, tracé à la main.
 *
 * Aucune bibliothèque d'icônes n'est installée, pour la même raison que les
 * graphiques sont dessinés en SVG : la quinzaine de pictogrammes utilisés ici
 * ne justifie pas un paquet de plusieurs centaines de kilo-octets, sur des
 * connexions qui sont déjà le point faible du projet.
 *
 * Toutes partent d'une grille de 24, en trait de 1,75 : à cette épaisseur
 * elles restent lisibles sur un écran médiocre sans paraître lourdes.
 */

type Props = { className?: string };

function Trace({ className, children }: Props & { children: React.ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className ?? 'size-5'}
      aria-hidden
    >
      {children}
    </svg>
  );
}

export function IconIndicateurs(p: Props) {
  return (
    <Trace {...p}>
      <path d="M3 3v16a2 2 0 0 0 2 2h16" />
      <path d="M7 15l3.5-4 3 2.5L20 7" />
    </Trace>
  );
}

export function IconComptes(p: Props) {
  return (
    <Trace {...p}>
      <path d="M16 20v-1.5a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4V20" />
      <circle cx="9" cy="7" r="3.5" />
      <path d="M17 11h5M19.5 8.5v5" />
    </Trace>
  );
}

export function IconCentres(p: Props) {
  return (
    <Trace {...p}>
      <path d="M4 21V8l8-5 8 5v13" />
      <path d="M2 21h20" />
      <path d="M12 10v6M9 13h6" />
    </Trace>
  );
}

export function IconGeographie(p: Props) {
  return (
    <Trace {...p}>
      <path d="M9 4 3 6.5v13L9 17l6 3 6-2.5v-13L15 7 9 4v13" />
      <path d="M15 7v13" />
    </Trace>
  );
}

export function IconJournal(p: Props) {
  return (
    <Trace {...p}>
      <path d="M5 4h14v16H5z" />
      <path d="M8.5 9h7M8.5 13h7M8.5 17h4" />
    </Trace>
  );
}

export function IconConsultation(p: Props) {
  return (
    <Trace {...p}>
      <path d="M8 4h8v3H8zM6 7h12v13H6z" />
      <path d="M12 11v5M9.5 13.5h5" />
    </Trace>
  );
}

export function IconGrossesse(p: Props) {
  return (
    <Trace {...p}>
      <circle cx="12" cy="5" r="2.5" />
      <path d="M12 9c3 0 5 2.2 5 5s-2 6-5 6-4-1.5-4-3.5" />
      <path d="M8 11v6" />
    </Trace>
  );
}

export function IconVaccin(p: Props) {
  return (
    <Trace {...p}>
      <path d="m15 3 6 6M18.5 5.5 13 11l-1.5 5L8 19.5 4.5 16l3.5-3.5L13 11" />
      <path d="M4 20 2.5 21.5" />
    </Trace>
  );
}

export function IconPlanification(p: Props) {
  return (
    <Trace {...p}>
      <circle cx="12" cy="9" r="5" />
      <path d="M12 14v7M9 18h6" />
    </Trace>
  );
}

export function IconDossier(p: Props) {
  return (
    <Trace {...p}>
      <path d="M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
    </Trace>
  );
}

export function IconDeconnexion(p: Props) {
  return (
    <Trace {...p}>
      <path d="M14 20H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h8" />
      <path d="M17 8.5 20.5 12 17 15.5M20 12H10" />
    </Trace>
  );
}

export function IconFleche({ montante, ...p }: Props & { montante: boolean }) {
  return (
    <Trace {...p}>
      {montante ? (
        <path d="M12 19V5M6 11l6-6 6 6" />
      ) : (
        <path d="M12 5v14M6 13l6 6 6-6" />
      )}
    </Trace>
  );
}
