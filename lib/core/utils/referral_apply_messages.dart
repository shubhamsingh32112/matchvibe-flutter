/// Fallback copy when the API omits a `message` field (older clients or edge cases).
///
/// Prefer server-provided strings: `GET /referral/preview` error body and
/// `POST /auth/login` → `data.referralApply.message` (backend `referral-messages.ts`).
class ReferralApplyMessages {
  ReferralApplyMessages._();

  static String forServerCode(String? code) {
    switch (code) {
      case 'INVALID_FORMAT':
      case 'NOT_FOUND':
        return 'Invalid referral code';
      case 'SELF':
        return 'You cannot use your own code';
      case 'ALREADY_REFERRED':
        return 'Referral already used';
      case 'AGENT_DISABLED':
        return 'This referral code is no longer valid';
      case 'CREATOR_CANNOT_REFER':
        return "This referral code can't be used";
      case 'WINDOW_EXPIRED':
        return 'Referral code can no longer be applied (time limit expired)';
      case 'PURCHASE_ALREADY':
        return 'Referral codes cannot be applied after your first coin purchase';
      case 'NOT_ELIGIBLE_ROLE':
        return 'Referral codes cannot be applied for this account type';
      case 'AGENCY_REFERRAL_ONLY':
        return 'This link is for joining an agency; use a valid agency referral code';
      case 'ALREADY_LINKED_TO_AGENCY':
        return 'You are already linked to an agency';
      default:
        return 'Unable to apply referral code';
    }
  }
}
