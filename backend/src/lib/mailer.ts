import nodemailer from 'nodemailer';
import { config } from '../config';

let transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter | null {
  if (!config.gmailUser || !config.gmailAppPassword) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: config.gmailUser,
        pass: config.gmailAppPassword,
      },
    });
  }
  return transporter;
}

export async function sendPasswordResetEmail(
  to: string,
  code: string
): Promise<void> {
  const t = getTransporter();
  if (!t) {
    // Not configured (e.g. local dev) — log so the flow is still testable.
    console.warn(
      `[mailer] GMAIL_USER/GMAIL_APP_PASSWORD not set. Reset code for ${to}: ${code}`
    );
    return;
  }

  await t.sendMail({
    from: `"Family Tree" <${config.gmailUser}>`,
    to,
    subject: 'Your password reset code',
    text: `Your Family Tree password reset code is ${code}. It expires in ${config.resetCodeTtlMinutes} minutes. If you didn't request this, you can ignore this email.`,
    html: `<p>Your Family Tree password reset code is:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:4px;">${code}</p>
<p>It expires in ${config.resetCodeTtlMinutes} minutes. If you didn't request this, you can ignore this email.</p>`,
  });
}
