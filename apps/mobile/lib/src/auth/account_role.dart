enum AccountRole {
  creator,
}

class ActiveAccountContext {
  ActiveAccountContext._();

  static AccountRole sessionRole = AccountRole.creator;

  static void setRole(AccountRole role) {
    sessionRole = role;
  }
}
