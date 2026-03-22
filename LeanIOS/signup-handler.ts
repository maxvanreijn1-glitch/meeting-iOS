/**
 * signup-handler.ts
 * meeting-iOS
 *
 * TypeScript signup form handler.
 * Validates input, submits the form, and communicates with the native
 * iOS layer via the AuthBridge interface.
 */

// ── Types ─────────────────────────────────────────────────────────────────────

interface SignupFormData {
  firstName: string;
  lastName: string;
  email: string;
  password: string;
  confirmPassword?: string;
}

interface ValidationResult {
  valid: boolean;
  errors: string[];
}

interface AuthBridgeInterface {
  notifySignupSuccess(userData?: object): void;
  dismissAuthSheet(): void;
}

declare const AuthBridge: AuthBridgeInterface | undefined;

// ── Constants ─────────────────────────────────────────────────────────────────

const MIN_PASSWORD_LENGTH = 8;
const EMAIL_REGEX = /^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$/i;

// ── Validation ────────────────────────────────────────────────────────────────

/**
 * Validate signup form data.
 * Returns a ValidationResult with a list of human-readable errors.
 */
export function validateSignupForm(data: SignupFormData): ValidationResult {
  const errors: string[] = [];

  const email = data.email.trim();
  if (!email) {
    errors.push('Email is required.');
  } else if (!EMAIL_REGEX.test(email)) {
    errors.push('Please enter a valid email address.');
  }

  if (!data.password) {
    errors.push('Password is required.');
  } else if (data.password.length < MIN_PASSWORD_LENGTH) {
    errors.push(`Password must be at least ${MIN_PASSWORD_LENGTH} characters.`);
  }

  if (data.confirmPassword !== undefined && data.confirmPassword !== data.password) {
    errors.push('Passwords do not match.');
  }

  const firstName = data.firstName.trim();
  if (firstName && firstName.length < 2) {
    errors.push('First name must be at least 2 characters.');
  }

  const lastName = data.lastName.trim();
  if (lastName && lastName.length < 2) {
    errors.push('Last name must be at least 2 characters.');
  }

  return { valid: errors.length === 0, errors };
}

// ── Form handler ──────────────────────────────────────────────────────────────

/**
 * Attach submit listener to a signup form element.
 * @param formSelector - CSS selector for the form element.
 * @param onSuccess    - Called after validation passes and form submit proceeds.
 * @param onError      - Called with validation errors when validation fails.
 */
export function attachSignupHandler(
  formSelector: string,
  onSuccess?: (data: SignupFormData) => void,
  onError?: (errors: string[]) => void
): void {
  const form = document.querySelector<HTMLFormElement>(formSelector);
  if (!form) {
    console.warn(`[signup-handler] Form not found: ${formSelector}`);
    return;
  }

  form.addEventListener('submit', (evt: SubmitEvent) => {
    evt.preventDefault();

    const data = extractFormData(form);
    const result = validateSignupForm(data);

    if (!result.valid) {
      displayErrors(form, result.errors);
      onError?.(result.errors);
      return;
    }

    clearErrors(form);

    // Notify native layer on success (best-effort).
    if (typeof AuthBridge !== 'undefined') {
      AuthBridge.notifySignupSuccess({ email: data.email });
    }

    onSuccess?.(data);

    // Allow the form to submit normally.
    form.submit();
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function extractFormData(form: HTMLFormElement): SignupFormData {
  const get = (name: string): string =>
    (form.elements.namedItem(name) as HTMLInputElement | null)?.value ?? '';

  return {
    firstName:       get('firstName') || get('first_name') || get('fname'),
    lastName:        get('lastName')  || get('last_name')  || get('lname'),
    email:           get('email'),
    password:        get('password'),
    confirmPassword: get('confirmPassword') || get('confirm_password') || get('password_confirm'),
  };
}

function displayErrors(form: HTMLFormElement, errors: string[]): void {
  clearErrors(form);

  const container = document.createElement('div');
  container.className = 'signup-errors';
  container.setAttribute('role', 'alert');
  container.setAttribute('aria-live', 'polite');

  const list = document.createElement('ul');
  errors.forEach((msg) => {
    const item = document.createElement('li');
    item.textContent = msg;
    list.appendChild(item);
  });
  container.appendChild(list);

  form.insertAdjacentElement('beforebegin', container);
}

function clearErrors(form: HTMLFormElement): void {
  form.parentElement?.querySelectorAll('.signup-errors').forEach((el) => el.remove());
}

// ── Auto-init ─────────────────────────────────────────────────────────────────

/**
 * Auto-initialise when loaded in a browser context.
 * Attaches to any form with data-signup-form attribute.
 */
function autoInit(): void {
  const forms = document.querySelectorAll<HTMLFormElement>('[data-signup-form]');
  forms.forEach((form) => {
    const selector = form.id ? `#${form.id}` : '[data-signup-form]';
    attachSignupHandler(selector);
  });
}

if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', autoInit);
  } else {
    autoInit();
  }
}
