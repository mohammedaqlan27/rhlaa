// src/components/Button.tsx
import React from 'react';
import styles from '../styles/buttons.module.css';

export type ButtonVariant = 'primary' | 'secondary' | 'success' | 'danger' | 'ghost';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  block?: boolean;
  icon?: React.ReactNode;
  iconOnly?: boolean;
  loading?: boolean;
  className?: string;
  ariaLabel?: string;
}

export default function Button({
  children,
  variant = 'primary',
  size = 'md',
  block = false,
  icon = null,
  iconOnly = false,
  loading = false,
  disabled = false,
  type = 'button',
  className = '',
  ariaLabel,
  ...rest
}: ButtonProps) {
  const isDisabled = disabled || loading;
  const cls = [
    styles.btn,
    styles[`btn-${variant}`] || styles['btn-primary'],
    size === 'sm' ? styles['btn-sm'] : size === 'lg' ? styles['btn-lg'] : styles['btn-md'],
    block ? styles['btn-block'] : '',
    iconOnly ? styles['btn-icon-only'] : '',
    className
  ].filter(Boolean).join(' ');

  return (
    <button
      type={type}
      className={cls}
      onClick={isDisabled ? undefined : rest.onClick}
      disabled={isDisabled}
      aria-label={iconOnly ? ariaLabel : undefined}
      aria-busy={loading ? 'true' : undefined}
      {...rest}
    >
      {loading && (
        <span className={styles['btn-spinner']} aria-hidden="true">
          <svg width="16" height="16" viewBox="0 0 50 50" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="25" cy="25" r="20" stroke="currentColor" strokeWidth="5" strokeOpacity="0.15"/>
            <path d="M45 25a20 20 0 0 0-20-20" stroke="currentColor" strokeWidth="5" strokeLinecap="round"/>
          </svg>
        </span>
      )}

      {!loading && icon ? <span className={styles['btn-icon']} aria-hidden="true">{icon}</span> : null}

      {!iconOnly && <span className={styles['btn-label']}>{children}</span>}
    </button>
  );
}
