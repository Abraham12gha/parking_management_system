class Company {
  final String name;
  final String shortForm;
  final String logo;
  final String description;
  final String phone;
  final String email;
  final String website;
  final String address;

  const Company({
    required this.name,
    required this.shortForm,
    required this.logo,
    required this.description,
    required this.phone,
    required this.email,
    required this.website,
    required this.address,
  });
}

const company = Company(
  name: 'Pakistan Valet Solutions',
  shortForm: 'PVS',
  logo: 'assets/images/PVS_LOGO.png',
  description: 'unknown',
  phone: 'unknown',
  email: 'unknown',
  website: 'unknown',
  address: 'Karachi, Pakistan',
);