/**
 * P2 Template rendering – variable substitution, safe for worker
 */

const MUSTACHE_STYLE = /\{\{(\w+)\}\}/g;

interface TemplateShape {
  subject: string;
  html: string;
  text?: string | null;
}

/**
 * Render template with variables. Replaces {{varName}} with values.
 * Does not throw; returns error message in result on failure.
 */
export function renderTemplate(
  template: TemplateShape,
  variables: Record<string, string>
): { ok: true; subject: string; html: string; text?: string } | { ok: false; error: string } {
  try {
    const sub = (s: string): string =>
      s.replace(MUSTACHE_STYLE, (_, key) => variables[key] ?? '');

    const subject = sub(template.subject);
    const html = sub(template.html);
    const text = template.text ? sub(template.text) : undefined;
    return { ok: true, subject, html, text };
  } catch (e) {
    return {
      ok: false,
      error: (e as Error).message ?? 'Template render failed',
    };
  }
}

/** Minimal template shape for default (no Firestore). */
export interface DefaultTemplateShape {
  version: number;
  subject: string;
  html: string;
  text?: string | null;
  variables: string[];
}

/** Default in-code templates when no Firestore template exists (eventType -> subject + html). */
export function getDefaultTemplate(eventType: string): DefaultTemplateShape {
  const titleVar = '{{title}}';
  const defaults: Record<string, { subject: string; html: string }> = {
    'matter.created': { subject: 'New matter: ' + titleVar, html: '<p>A new matter "' + titleVar + '" was created.</p>' },
    'matter.updated': { subject: 'Matter updated: ' + titleVar, html: '<p>Matter "' + titleVar + '" was updated.</p>' },
    'task.created': { subject: 'New task: ' + titleVar, html: '<p>Task "' + titleVar + '" was created.</p>' },
    'task.assigned': { subject: 'Task assigned: ' + titleVar, html: '<p>You were assigned to task "' + titleVar + '".</p>' },
    'task.completed': { subject: 'Task completed: ' + titleVar, html: '<p>Task "' + titleVar + '" was marked complete.</p>' },
    'document.uploaded': { subject: 'New document: ' + titleVar, html: '<p>Document "' + titleVar + '" was uploaded.</p>' },
    'invoice.created': { subject: 'New invoice', html: '<p>A new invoice was created.</p>' },
    'payment.received': { subject: 'Payment received', html: '<p>A payment was recorded.</p>' },
    'user.joined': { subject: 'New team member', html: '<p>A user joined your firm.</p>' },
  };
  const d = defaults[eventType] ?? { subject: 'Update', html: '<p>You have an update.</p>' };
  return {
    version: 1,
    subject: d.subject,
    html: d.html,
    text: null,
    variables: ['title'],
  };
}
