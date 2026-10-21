/// A popular service for quick add. Prices differ by country, so the user
/// always types the amount; the template fills in everything else.
class Template {
  const Template(this.name, this.category, this.color, this.cancelUrl);
  final String name;
  final String category;
  final int color;
  final String cancelUrl;
}

const categories = [
  'Entertainment',
  'Music',
  'Cloud & storage',
  'Software',
  'AI tools',
  'Shopping',
  'Health & fitness',
  'News & reading',
  'Utilities',
  'Other',
];

const templates = [
  Template('Netflix', 'Entertainment', 0xFFE50914, 'https://www.netflix.com/cancelplan'),
  Template('Spotify', 'Music', 0xFF1DB954, 'https://www.spotify.com/account/subscription/'),
  Template('YouTube Premium', 'Entertainment', 0xFFFF0000, 'https://www.youtube.com/paid_memberships'),
  Template('Disney+', 'Entertainment', 0xFF113CCF, 'https://www.disneyplus.com/account/subscription'),
  Template('Amazon Prime', 'Shopping', 0xFF00A8E1, 'https://www.amazon.com/mc'),
  Template('Apple Music', 'Music', 0xFFFA243C, 'https://support.apple.com/en-us/118428'),
  Template('iCloud+', 'Cloud & storage', 0xFF3693F3, 'https://support.apple.com/en-us/108047'),
  Template('Google One', 'Cloud & storage', 0xFF4285F4, 'https://one.google.com/settings'),
  Template('ChatGPT Plus', 'AI tools', 0xFF10A37F, 'https://chatgpt.com/#settings/Subscription'),
  Template('Claude Pro', 'AI tools', 0xFFD97757, 'https://claude.ai/settings/billing'),
  Template('Microsoft 365', 'Software', 0xFFD83B01, 'https://account.microsoft.com/services'),
  Template('Adobe Creative Cloud', 'Software', 0xFFFF0000, 'https://account.adobe.com/plans'),
  Template('Canva Pro', 'Software', 0xFF00C4CC, 'https://www.canva.com/settings/billing-and-teams'),
  Template('Dropbox', 'Cloud & storage', 0xFF0061FF, 'https://www.dropbox.com/account/plan'),
  Template('Gym', 'Health & fitness', 0xFFF59E0B, ''),
  Template('Phone plan', 'Utilities', 0xFF6366F1, ''),
];
