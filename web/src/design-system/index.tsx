import { useId, type ButtonHTMLAttributes, type HTMLAttributes, type InputHTMLAttributes, type ReactNode } from 'react'
import './tokens.css'
import './components.css'

export type DsButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger'
export type DsButtonSize = 'sm' | 'md' | 'lg'
export type DsBadgeTone =
  | 'real'
  | 'suspicious'
  | 'ad'
  | 'info'
  | 'success'
  | 'warning'
  | 'error'

function cx(...values: Array<string | false | null | undefined>) {
  return values.filter(Boolean).join(' ')
}

export type DsButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: DsButtonVariant
  size?: DsButtonSize
  loading?: boolean
  leftIcon?: ReactNode
  rightIcon?: ReactNode
}

export function DsButton({
  variant = 'primary',
  size = 'md',
  loading = false,
  disabled,
  leftIcon,
  rightIcon,
  children,
  className,
  type = 'button',
  ...props
}: DsButtonProps) {
  return (
    <button
      {...props}
      type={type}
      className={cx('ds-button', className)}
      data-variant={variant}
      data-size={size}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
    >
      {loading ? <span className="ds-button-spinner" aria-hidden="true" /> : leftIcon}
      <span>{children}</span>
      {rightIcon}
    </button>
  )
}

export type DsIconButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  label: string
  icon: ReactNode
}

export function DsIconButton({
  label,
  icon,
  className,
  type = 'button',
  ...props
}: DsIconButtonProps) {
  return (
    <button
      {...props}
      type={type}
      className={cx('ds-icon-button', className)}
      aria-label={label}
      title={label}
    >
      {icon}
    </button>
  )
}

export type DsTextFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label?: string
  error?: string
  success?: string
  helperText?: string
  leadingIcon?: ReactNode
}

export function DsTextField({
  id,
  label,
  error,
  success,
  helperText,
  leadingIcon,
  className,
  ...props
}: DsTextFieldProps) {
  const generatedId = useId()
  const inputId = id ?? generatedId
  const message = error ?? success ?? helperText
  const messageTone = error ? 'error' : success ? 'success' : 'default'

  return (
    <label className={cx('ds-text-field', className)} htmlFor={inputId}>
      {label && <span className="ds-text-field-label">{label}</span>}
      <span
        className="ds-text-field-control"
        data-invalid={Boolean(error)}
        data-success={Boolean(success)}
      >
        {leadingIcon && <span className="ds-text-field-leading">{leadingIcon}</span>}
        <input
          {...props}
          id={inputId}
          className="ds-text-field-input"
          aria-invalid={Boolean(error) || undefined}
        />
      </span>
      {message && (
        <p className="ds-text-field-message" data-tone={messageTone}>
          {message}
        </p>
      )}
    </label>
  )
}

export type DsCardProps = HTMLAttributes<HTMLElement> & {
  as?: 'article' | 'section' | 'div'
  padding?: 'sm' | 'md' | 'lg'
}

export function DsCard({
  as: Element = 'div',
  padding = 'md',
  className,
  ...props
}: DsCardProps) {
  return <Element {...props} className={cx('ds-card', className)} data-padding={padding} />
}

export type DsBadgeProps = HTMLAttributes<HTMLSpanElement> & {
  tone?: DsBadgeTone
}

export function DsBadge({ tone = 'info', className, ...props }: DsBadgeProps) {
  return <span {...props} className={cx('ds-badge', className)} data-tone={tone} />
}

export type DsToastProps = HTMLAttributes<HTMLDivElement> & {
  tone?: DsBadgeTone
}

export function DsToast({ tone = 'info', className, ...props }: DsToastProps) {
  return (
    <div
      {...props}
      className={cx('ds-toast', className)}
      data-tone={tone}
      role={tone === 'error' || tone === 'ad' ? 'alert' : 'status'}
    />
  )
}

export type DsDialogProps = HTMLAttributes<HTMLDivElement> & {
  open: boolean
  title: string
  description?: string
  footer?: ReactNode
  onClose?: () => void
}

export function DsDialog({
  open,
  title,
  description,
  footer,
  onClose,
  children,
  className,
  ...props
}: DsDialogProps) {
  const titleId = useId()

  if (!open) return null

  return (
    <div className="ds-dialog-backdrop" role="presentation">
      <div
        {...props}
        className={cx('ds-card ds-dialog', className)}
        data-padding="lg"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
      >
        <header className="ds-dialog-header">
          <div>
            <h2 className="ds-dialog-title" id={titleId}>
              {title}
            </h2>
            {description && <p className="ds-dialog-description">{description}</p>}
          </div>
          {onClose && (
            <button type="button" className="ds-dialog-close" aria-label="닫기" onClick={onClose}>
              ×
            </button>
          )}
        </header>
        {children}
        {footer}
      </div>
    </div>
  )
}
