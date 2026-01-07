class Validator {
  static validatePhone(phone) {
    const phoneStr = phone.toString().replace(/\D/g, '');
    return phoneStr.length >= 10 && phoneStr.length <= 15;
  }

  static validateFullName(name) {
    if (!name || typeof name !== 'string') return false;
    const parts = name.trim().split(' ').filter(p => p.length > 0);
    return parts.length >= 2 && parts.every(p => /^[а-яА-ЯёЁa-zA-Z-]+$/.test(p));
  }

  static validateClientStatus(status) {
    return ['new', 'old'].includes(status);
  }

  static validateIds(companyId, clientId) {
    return (
      Number.isInteger(+companyId) && +companyId > 0 &&
      Number.isInteger(+clientId) && +clientId > 0
    );
  }

  static validateLinkExpiry(dateString, hoursValid = 24) {
    try {
      const linkDate = new Date(dateString);
      if (isNaN(linkDate)) return false;
      const now = new Date();
      const diffHours = (now - linkDate) / (1000 * 60 * 60);
      return diffHours <= hoursValid;
    } catch {
      return false;
    }
  }
}

module.exports = Validator;