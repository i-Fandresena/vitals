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
    <div className="rounded-xl border border-outline-variant bg-white p-5">
      {children}
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
