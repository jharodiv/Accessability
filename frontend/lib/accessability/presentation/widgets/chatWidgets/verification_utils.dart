class VerificationCodeUtils {
  static bool isVerificationCodeMessage(Map<String, dynamic> data) {
    return data['metadata'] != null &&
        data['metadata']['type'] == 'verification_code';
  }
}
