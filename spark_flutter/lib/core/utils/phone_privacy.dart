class PhonePrivacy {
  static String mask(String phone, {bool hide = false}) {
    if (!hide) return phone;
    
    // Assuming format is +XX XXXXXXXXXX or similar
    // User wants: "Only first 2 digits will be shown and others will be xxxxx"
    final trimmed = phone.trim();
    if (trimmed.length <= 2) return trimmed;
    
    // If it starts with +, let's keep + and the first 2 meaningful digits?
    // User said "Only first 2 digits", let's be literal.
    // e.g. +91 9876543210 -> +91 98xxxxxxx
    // Actually, usually users mean the first 2 digits of the actual number.
    // Let's keep the country code if present.
    
    final hasPlus = trimmed.startsWith('+');
    final start = hasPlus ? 3 : 0; // Skip + and 2 digits for country code? No, let's just do first 2 chars after + if + exists.
    
    if (trimmed.length <= start + 2) return trimmed;
    
    final prefix = trimmed.substring(0, start + 2);
    final masked = 'x' * (trimmed.length - (start + 2));
    return '$prefix$masked';
  }
}
