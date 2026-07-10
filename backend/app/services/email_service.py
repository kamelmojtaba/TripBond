"""
Email service for sending transactional emails via SMTP.

If SMTP credentials are not configured, the verification code is printed
to the console so development still works without an email provider.
"""

import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from ..config import get_settings

logger = logging.getLogger(__name__)


def send_verification_code_email(to_email: str, code: str, name: str = "") -> bool:
    """
    Send a 6-digit email verification code.

    Returns True on success (or when falling back to console print).
    Returns False only when SMTP is configured but the send actually fails.
    """
    config = get_settings()

    # Fallback: no SMTP configured — print so developers can still test
    if not config.smtp_host or not config.smtp_user or not config.smtp_password:
        print(f"\n{'='*50}")
        print(f"📧  VERIFICATION CODE  for {to_email}")
        print(f"    Code : {code}")
        print(f"{'='*50}\n")
        return True

    greeting = f"Hi {name}," if name else "Hi,"

    text_body = (
        f"{greeting}\n\n"
        f"Your TripBond email verification code is:\n\n"
        f"    {code}\n\n"
        f"This code expires in 10 minutes.\n\n"
        f"If you did not create a TripBond account, please ignore this email.\n\n"
        f"Best,\nThe TripBond Team"
    )

    html_body = f"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TripBond Email Verification</title>
</head>
<body style="margin:0;padding:0;background:#f5f7fa;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;border-radius:20px;box-shadow:0 4px 20px rgba(0,0,0,0.08);overflow:hidden;max-width:100%;">
          <!-- Header with Logo -->
          <tr>
            <td style="background:linear-gradient(135deg, #4675B8 0%, #5A8CD9 100%);padding:40px 30px;text-align:center;">
              <div style="display:inline-block;background:#ffffff;padding:15px 25px;border-radius:12px;box-shadow:0 2px 10px rgba(0,0,0,0.1);">
                <h1 style="margin:0;color:#4675B8;font-size:36px;font-weight:700;letter-spacing:2px;font-family:'Segoe UI',Arial,sans-serif;">
                  Trip<span style="color:#5A8CD9;">B</span><span style="position:relative;display:inline-block;">
                    <span style="color:#4675B8;">o</span>
                    <svg viewBox="0 0 24 24" style="position:absolute;top:-8px;right:-12px;width:20px;height:20px;fill:#5A8CD9;">
                      <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
                    </svg>
                  </span>nd
                </h1>
              </div>
              <p style="color:#ffffff;font-size:16px;margin:20px 0 0;font-weight:300;letter-spacing:0.5px;">Your Travel Companion</p>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding:50px 40px 30px;">
              <h2 style="color:#2c3e50;font-size:24px;margin:0 0 20px;font-weight:600;text-align:center;">
                Welcome to TripBond! 🌍
              </h2>
              <p style="color:#5a5a5a;font-size:16px;line-height:1.8;margin:0 0 30px;text-align:center;">
                {greeting}<br>
                We're excited to have you join our community of travelers!<br>
                Please verify your email address to start planning your next adventure.
              </p>
              
              <!-- Verification Code Box -->
              <div style="background:linear-gradient(135deg, #f0f5ff 0%, #e6f2ff 100%);border-radius:16px;padding:35px 30px;margin:0 0 30px;text-align:center;border:2px solid #d0e4ff;">
                <p style="margin:0 0 15px;color:#7a8a99;font-size:13px;letter-spacing:2px;text-transform:uppercase;font-weight:600;">
                  Your Verification Code
                </p>
                <div style="background:#ffffff;border-radius:12px;padding:20px;display:inline-block;box-shadow:0 2px 8px rgba(70,117,184,0.15);">
                  <div style="font-size:42px;font-weight:bold;letter-spacing:16px;color:#4675B8;font-family:'Courier New',monospace;padding:0 12px;">
                    {code}
                  </div>
                </div>
                <p style="color:#7a8a99;font-size:13px;margin:20px 0 0;line-height:1.6;">
                  ⏱️ This code expires in <strong style="color:#4675B8;">10 minutes</strong>
                </p>
              </div>
              
              <p style="color:#8a8a8a;font-size:14px;line-height:1.7;margin:0;text-align:center;padding:0 20px;">
                If you didn't create a TripBond account, you can safely ignore this email.
                No further action is required.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background:#f8f9fb;padding:30px 40px;text-align:center;border-top:1px solid #e5e8eb;">
              <p style="color:#b8bcc4;font-size:12px;margin:0 0 8px;line-height:1.6;">
                This is an automated message from TripBond. Please do not reply to this email.
              </p>
              <p style="color:#b8bcc4;font-size:11px;margin:0;">
                &copy; 2026 TripBond. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
""".strip()

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "TripBond – Your Email Verification Code"
        msg["From"] = config.smtp_from_email or config.smtp_user
        msg["To"] = to_email
        msg.attach(MIMEText(text_body, "plain"))
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(config.smtp_host, config.smtp_port, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.login(config.smtp_user, config.smtp_password)
            server.sendmail(config.smtp_from_email or config.smtp_user, to_email, msg.as_string())

        logger.info(f"Verification email sent to {to_email}")
        return True

    except Exception as exc:
        logger.exception(f"Failed to send verification email to {to_email}: {exc}")
        # Console fallback so the app flow isn't completely broken
        print(f"\n{'='*50}")
        print(f"📧  VERIFICATION CODE  for {to_email}  (email send failed)")
        print(f"    Code : {code}")
        print(f"{'='*50}\n")
        return False


def send_password_reset_code_email(to_email: str, code: str, name: str = "") -> bool:
    """
    Send a 6-digit password reset code.

    Returns True on success (or when falling back to console print).
    Returns False only when SMTP is configured but the send actually fails.
    """
    config = get_settings()

    if not config.smtp_host or not config.smtp_user or not config.smtp_password:
        print(f"\n{'='*50}")
        print(f"📧  PASSWORD RESET CODE for {to_email}")
        print(f"    Code : {code}")
        print(f"{'='*50}\n")
        return True

    greeting = f"Hi {name}," if name else "Hi,"

    text_body = (
        f"{greeting}\n\n"
        f"Your TripBond password reset code is:\n\n"
        f"    {code}\n\n"
        f"This code expires in 10 minutes.\n\n"
        f"If you did not request a password reset, please ignore this email.\n\n"
        f"Best,\nThe TripBond Team"
    )

    html_body = f"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TripBond Password Reset</title>
</head>
<body style="margin:0;padding:0;background:#f5f7fa;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;border-radius:20px;box-shadow:0 4px 20px rgba(0,0,0,0.08);overflow:hidden;max-width:100%;">
          <tr>
            <td style="background:linear-gradient(135deg, #4675B8 0%, #5A8CD9 100%);padding:40px 30px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:30px;font-weight:700;">TripBond</h1>
              <p style="color:#ffffff;font-size:15px;margin:12px 0 0;font-weight:300;">Password Reset Request</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 35px 30px;">
              <p style="color:#5a5a5a;font-size:16px;line-height:1.7;margin:0 0 24px;text-align:center;">
                {greeting}<br>
                Use this code to reset your password.
              </p>
              <div style="background:linear-gradient(135deg, #f0f5ff 0%, #e6f2ff 100%);border-radius:16px;padding:28px 22px;margin:0 0 24px;text-align:center;border:2px solid #d0e4ff;">
                <p style="margin:0 0 10px;color:#7a8a99;font-size:13px;letter-spacing:2px;text-transform:uppercase;font-weight:600;">
                  Reset Code
                </p>
                <div style="font-size:38px;font-weight:bold;letter-spacing:12px;color:#4675B8;font-family:'Courier New',monospace;">
                  {code}
                </div>
                <p style="color:#7a8a99;font-size:13px;margin:16px 0 0;line-height:1.6;">
                  ⏱️ Expires in <strong style="color:#4675B8;">10 minutes</strong>
                </p>
              </div>
              <p style="color:#8a8a8a;font-size:14px;line-height:1.7;margin:0;text-align:center;">
                If you didn't request this, you can safely ignore this email.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
""".strip()

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "TripBond – Password Reset Code"
        msg["From"] = config.smtp_from_email or config.smtp_user
        msg["To"] = to_email
        msg.attach(MIMEText(text_body, "plain"))
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(config.smtp_host, config.smtp_port, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.login(config.smtp_user, config.smtp_password)
            server.sendmail(config.smtp_from_email or config.smtp_user, to_email, msg.as_string())

        logger.info(f"Password reset email sent to {to_email}")
        return True

    except Exception as exc:
        logger.exception(f"Failed to send password reset email to {to_email}: {exc}")
        print(f"\n{'='*50}")
        print(f"📧  PASSWORD RESET CODE for {to_email}  (email send failed)")
        print(f"    Code : {code}")
        print(f"{'='*50}\n")
        return False
