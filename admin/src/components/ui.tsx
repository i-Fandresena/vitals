import type { ReactNode } from 'react';

/** Petite bibliothèque de composants, écrite à la main.
 *
 * shadcn/ui n'est pas utilisé ici : pour trois écrans de formulaires, sa mise
 * en place (registre, générateur, dépendances Radix) coûterait plus que les
 * quelques composants ci-dessous. Les jetons de couleur viennent de
 * l'application mobile, pour que les deux surfaces se ressemblent. */

export function Button({
  children,
  variant = 'primary',
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary' | 'danger';
}) {
  const styles = {
    primary: 'bg-primary text-white hover:bg-primary-hover',
    secondary:
      'bg-white text-on-surface border border-outline hover:bg-surface-container',
    danger: 'bg-white text-danger border border-danger hover:bg-danger-container',
  }[variant];

  return (
    <button
      {...props}
      className={`min-h-11 rounded-lg px-4 font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${styles} ${props.className ?? ''}`}
    >
      {children}
    </button>
  );
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="font-medium text-on-surface">{label}</span>
      {children}
      {hint && <span className="text-sm text-on-surface-variant">{hint}</span>}
    </label>
  );
}

const inputStyles =
  'min-h-11 w-full rounded-lg border border-outline bg-white px-3 text-on-surface ' +
  'focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/30 ' +
  'disabled:bg-surface-container disabled:text-on-surface-variant';

export function Input(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={`${inputStyles} ${props.className ?? ''}`} />;
}

export function Select(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return <select {...props} className={`${inputStyles} ${props.className ?? ''}`} />;
}

/** Message d'erreur persistant.
 *
 * Un bandeau plutôt qu'une notification éphémère : l'utilisateur doit pouvoir
 * le relire pendant qu'il corrige sa saisie. */
export function Alert({
  tone = 'danger',
  children,
}: {
  tone?: 'danger' | 'success' | 'info';
  children: ReactNode;
}) {
  const styles = {
    danger: 'bg-danger-container text-on-danger-container',
    success: 'bg-success-container text-on-surface',
    info: 'bg-primary-container text-on-primary-container',
  }[tone];

  return (
    <div role="alert" className={`whitespace-pre-line rounded-lg p-4 ${styles}`}>
      {children}
    </div>
  );
}

export function Card({ children }: { children: ReactNode }) {
  return (
    <div className="rounded-2xl border border-outline-variant bg-white p-5 shadow-[var(--shadow-carte)]">
      {children}
    </div>
  );
}

/** Carte à en-tête : un titre, une explication, et de quoi régler la vue.
 *
 * Le sous-titre n'est pas décoratif. Sur des indicateurs, ce qui est compté et
 * sur quelle date fait la différence entre un chiffre juste et un chiffre
 * trompeur — et personne n'ira le chercher dans la documentation. */
export function Panel({
  titre,
  sous,
  action,
  children,
}: {
  titre: string;
  sous?: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="rounded-2xl border border-outline-variant bg-surface-card p-5 shadow-[var(--shadow-carte)]">
      <div className="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold tracking-tight">{titre}</h3>
          {sous && <p className="text-sm text-on-surface-variant">{sous}</p>}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

/**
 * Chiffre unique, avec son icône et sa part de l'ensemble.
 *
 * [enAvant] réserve le fond plein à une seule tuile de la grille : l'œil doit
 * savoir où se poser en premier. Plusieurs cartes pleines et la hiérarchie
 * disparaît.
 */
export function StatCard({
  libelle,
  valeur,
  note,
  part,
  icone,
  enAvant = false,
}: {
  libelle: string;
  valeur: number;
  note?: string;
  /** Part du total de la période, en pourcentage. */
  part?: number;
  icone: ReactNode;
  enAvant?: boolean;
}) {
  return (
    <div
      className={`rounded-2xl border p-5 transition-shadow ${
        enAvant
          ? 'border-primary bg-primary text-white shadow-[var(--shadow-carte-active)]'
          : 'border-outline-variant bg-surface-card shadow-[var(--shadow-carte)]'
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <span
          className={`grid size-11 place-items-center rounded-xl ${
            enAvant ? 'bg-white/15 text-white' : 'bg-surface-container text-primary'
          }`}
        >
          {icone}
        </span>
        {part !== undefined && (
          <span
            className={`rounded-full px-2.5 py-1 text-sm font-semibold tabular-nums ${
              enAvant ? 'bg-white/15 text-white' : 'bg-surface-container text-on-surface'
            }`}
          >
            {part.toLocaleString('fr-FR', { maximumFractionDigits: 0 })} %
          </span>
        )}
      </div>

      <p className={`mt-4 text-sm font-medium ${enAvant ? 'text-white/80' : 'text-on-surface-variant'}`}>
        {libelle}
      </p>
      <p className="text-4xl font-bold tracking-tight tabular-nums">
        {valeur.toLocaleString('fr-FR')}
      </p>
      {note && (
        <p className={`mt-1 text-xs ${enAvant ? 'text-white/70' : 'text-on-surface-variant'}`}>
          {note}
        </p>
      )}
    </div>
  );
}

export function Badge({
  children,
  tone = 'neutral',
}: {
  children: ReactNode;
  tone?: 'neutral' | 'success' | 'warning';
}) {
  const styles = {
    neutral: 'bg-surface-container text-on-surface-variant',
    success: 'bg-success-container text-on-surface',
    warning: 'bg-warning-container text-on-surface',
  }[tone];

  return (
    <span className={`rounded-full px-2.5 py-1 text-sm font-medium ${styles}`}>
      {children}
    </span>
  );
}

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="rounded-xl border border-dashed border-outline-variant p-10 text-center">
      <p className="font-medium text-on-surface">{title}</p>
      {hint && <p className="mt-1 text-on-surface-variant">{hint}</p>}
    </div>
  );
}
